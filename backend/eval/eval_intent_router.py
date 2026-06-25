"""
Intent Router Evaluation — Accuracy, Precision, Recall, F1 per class

Tests IntentRouter against ground truth dataset.
Requires: Redis running, embedder available.

Usage:
    cd backend
    python -m eval.eval_intent_router
"""

import asyncio
import json
import logging
import sys
import time
from pathlib import Path
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from dotenv import load_dotenv
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

from app.core.config import settings
from app.core.redis_client import redis_client
from app.kg.embeddings import NodeEmbedder
from app.agent.intent_router import IntentRouter

logging.basicConfig(level=logging.WARNING, format="%(message)s")
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

DATASET_PATH = Path(__file__).resolve().parent / "datasets" / "intent_ground_truth.json"


def load_dataset() -> list[dict]:
    with open(DATASET_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data["test_cases"]


async def main():
    logger.info("=" * 60)
    logger.info("INTENT ROUTER EVALUATION")
    logger.info("=" * 60)

    dataset = load_dataset()
    logger.info("Loaded %d test cases", len(dataset))

    await redis_client.connect()
    embedder = NodeEmbedder(
        embedding_api_url=settings.EMBEDDING_API_URL,
        model_name=settings.EMBEDDING_MODEL,
    )

    router = IntentRouter(embedder=embedder)
    logger.info("Initializing intent embeddings...")
    await router.initialize()
    logger.info("Intent router ready.")

    # Metrics
    y_true = []
    y_pred = []
    latency_ms = []
    detail_results = []

    for tc in dataset:
        query = tc["query"]
        expected = tc["expected_intent"]

        start = time.perf_counter()
        result = await router.route(query)
        latency = (time.perf_counter() - start) * 1000

        # Determine predicted intent
        if result is None:
            predicted = "pass_to_llm"
        elif "hiện mình hỗ trợ" in result.answer.lower() or "3 môn" in result.answer.lower():
            predicted = "sports_overview"
        elif "chào" in result.answer.lower() or "xin chào" in result.answer.lower():
            predicted = "greeting"
        elif "không liên quan" in result.answer.lower() or "thể thao" in result.answer.lower():
            predicted = "off_topic"
        else:
            predicted = "domain"

        # The router has 2 possible outcomes:
        #   - returns IntentResult (sports_overview) → predicted = "sports_overview"
        #   - returns None (pass to LLM) → predicted = "pass_to_llm"
        # Correctness logic:
        #   greeting     → pass_to_llm is CORRECT (LLM handles greeting)
        #   domain       → pass_to_llm is CORRECT (LLM handles domain)
        #   off_topic    → pass_to_llm is CORRECT (LLM will refuse)
        #   sports_overview → sports_overview is CORRECT (router handles directly)

        is_correct = False
        if expected == "sports_overview":
            is_correct = (predicted == "sports_overview")
        else:
            # greeting, domain, off_topic all correctly go to LLM
            is_correct = (predicted == "pass_to_llm")

        # For per-class metrics, normalize predicted to match expected categories
        if predicted == "pass_to_llm":
            predicted_for_metrics = expected if is_correct else "wrong"
        else:
            predicted_for_metrics = predicted

        y_true.append(expected)
        y_pred.append(predicted_for_metrics)
        latency_ms.append(latency)

        status = "OK" if is_correct else "FAIL"
        logger.info(
            "  [%s] %s expected=%s predicted=%s %.1fms — %s",
            tc["id"], status, expected, predicted, latency, query[:40],
        )

        detail_results.append({
            "id": tc["id"],
            "query": query,
            "expected": expected,
            "predicted": predicted,
            "correct": is_correct,
            "latency_ms": latency,
        })

    # Calculate metrics
    logger.info("")
    logger.info("=" * 60)
    logger.info("RESULTS SUMMARY")
    logger.info("=" * 60)

    n = len(y_true)
    if n == 0:
        logger.error("No evaluations!")
        return

    # Overall accuracy
    correct = sum(1 for d in detail_results if d["correct"])
    accuracy = correct / n
    logger.info("Overall Accuracy: %.4f (%d/%d)", accuracy, correct, n)

    # Per-class metrics
    classes = set(y_true)
    logger.info("")
    logger.info("--- Per-Class Metrics ---")
    logger.info("%-20s %10s %10s %10s %10s", "Class", "Precision", "Recall", "F1", "Support")
    logger.info("-" * 65)

    class_metrics = {}
    for cls in sorted(classes):
        tp = sum(1 for t, p in zip(y_true, y_pred) if t == cls and p == cls)
        fp = sum(1 for t, p in zip(y_true, y_pred) if t != cls and p == cls)
        fn = sum(1 for t, p in zip(y_true, y_pred) if t == cls and p != cls)
        support = sum(1 for t in y_true if t == cls)

        precision = tp / (tp + fp) if (tp + fp) > 0 else 0
        recall = tp / (tp + fn) if (tp + fn) > 0 else 0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0

        class_metrics[cls] = {"precision": precision, "recall": recall, "f1": f1, "support": support}
        logger.info("%-20s %10.4f %10.4f %10.4f %10d", cls, precision, recall, f1, support)

    # Macro averages
    macro_p = sum(m["precision"] for m in class_metrics.values()) / len(class_metrics)
    macro_r = sum(m["recall"] for m in class_metrics.values()) / len(class_metrics)
    macro_f1 = sum(m["f1"] for m in class_metrics.values()) / len(class_metrics)
    logger.info("-" * 65)
    logger.info("%-20s %10.4f %10.4f %10.4f", "MACRO AVG", macro_p, macro_r, macro_f1)

    # Latency
    logger.info("")
    logger.info("--- Latency ---")
    logger.info("  Avg: %.1f ms", sum(latency_ms) / len(latency_ms))
    logger.info("  Min: %.1f ms", min(latency_ms))
    logger.info("  Max: %.1f ms", max(latency_ms))

    # Confusion matrix
    print("\n--- Confusion Matrix ---")
    all_classes = sorted(set(y_true) | set(y_pred))
    label = "True\\Pred"
    header = f"{label:<15}" + "".join(f"{cls[:10]:>12}" for cls in all_classes)
    print(header)
    for true_cls in all_classes:
        row = f"{true_cls[:13]:<15}"
        for pred_cls in all_classes:
            count = sum(1 for t, p in zip(y_true, y_pred) if t == true_cls and p == pred_cls)
            row += f"{count:>12}"
        print(row)

    # Save results
    output_path = Path(__file__).resolve().parent / "results_intent.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump({
            "summary": {
                "accuracy": accuracy,
                "macro_precision": macro_p,
                "macro_recall": macro_r,
                "macro_f1": macro_f1,
                "avg_latency_ms": sum(latency_ms) / len(latency_ms),
                "class_metrics": class_metrics,
            },
            "details": detail_results,
        }, f, ensure_ascii=False, indent=2)
    logger.info("")
    logger.info("Results saved to: %s", output_path)

    await redis_client.close()


if __name__ == "__main__":
    asyncio.run(main())
