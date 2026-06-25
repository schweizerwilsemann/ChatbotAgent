"""
Run All Evaluations — Comprehensive AI Metrics Report

Runs all evaluation scripts and generates a consolidated report.

Usage:
    cd backend
    python -m eval.run_all_evals
"""

import asyncio
import json
import logging
import sys
import time
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from dotenv import load_dotenv
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger(__name__)

RESULTS_DIR = Path(__file__).resolve().parent


def load_result(filename: str) -> dict | None:
    path = RESULTS_DIR / filename
    if not path.exists():
        return None
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


async def run_retrieval():
    from eval.eval_retrieval import main as retrieval_main
    logger.info("\n" + "=" * 70)
    logger.info("PHASE 1: RETRIEVAL EVALUATION")
    logger.info("=" * 70)
    await retrieval_main()


async def run_intent():
    from eval.eval_intent_router import main as intent_main
    logger.info("\n" + "=" * 70)
    logger.info("PHASE 2: INTENT ROUTER EVALUATION")
    logger.info("=" * 70)
    await intent_main()


async def run_rrf():
    from eval.eval_rrf import main as rrf_main
    logger.info("\n" + "=" * 70)
    logger.info("PHASE 3: RRF FUSION EVALUATION")
    logger.info("=" * 70)
    await rrf_main()


async def run_graph_rag():
    from eval.eval_graph_rag import main as graph_main
    logger.info("\n" + "=" * 70)
    logger.info("PHASE 4: GRAPH RAG EVALUATION")
    logger.info("=" * 70)
    await graph_main()


def generate_report():
    logger.info("\n" + "=" * 70)
    logger.info("CONSOLIDATED REPORT")
    logger.info("=" * 70)

    report = {
        "generated_at": datetime.now().isoformat(),
        "evaluations": {}
    }

    # Load all results
    retrieval = load_result("results_retrieval.json")
    intent = load_result("results_intent.json")
    rrf = load_result("results_rrf.json")
    graph = load_result("results_graph_rag.json")

    if retrieval:
        s = retrieval["summary"]
        logger.info("\n--- RETRIEVAL (HybridKnowledgeRetriever) ---")
        logger.info("  P@1: %.4f | P@3: %.4f | P@5: %.4f", s["p@1"], s["p@3"], s["p@5"])
        logger.info("  R@1: %.4f | R@3: %.4f | R@5: %.4f", s["r@1"], s["r@3"], s["r@5"])
        logger.info("  F1@5: %.4f", s["f1@5"])
        logger.info("  MRR: %.4f | NDCG@3: %.4f | NDCG@5: %.4f", s["mrr"], s["ndcg@3"], s["ndcg@5"])
        logger.info("  Keyword Coverage: %.4f", s["keyword_coverage"])
        logger.info("  Avg Latency: %.1f ms", s["avg_latency_ms"])
        report["evaluations"]["retrieval"] = s

    if intent:
        s = intent["summary"]
        logger.info("\n--- INTENT ROUTER ---")
        logger.info("  Accuracy: %.4f", s["accuracy"])
        logger.info("  Macro P: %.4f | Macro R: %.4f | Macro F1: %.4f",
                    s["macro_precision"], s["macro_recall"], s["macro_f1"])
        logger.info("  Avg Latency: %.1f ms", s["avg_latency_ms"])
        report["evaluations"]["intent_router"] = s

    if rrf:
        logger.info("\n--- RRF FUSION ---")
        comp = rrf["approach_comparison"]
        logger.info("  Hybrid RRF:  MRR=%.4f P@5=%.4f", comp["hybrid_rrf"]["mrr"], comp["hybrid_rrf"]["p@5"])
        logger.info("  Fulltext:    MRR=%.4f P@5=%.4f", comp["fulltext_only"]["mrr"], comp["fulltext_only"]["p@5"])
        logger.info("  Vector:      MRR=%.4f P@5=%.4f", comp["vector_only"]["mrr"], comp["vector_only"]["p@5"])
        if comp["fulltext_only"]["mrr"] > 0:
            improvement = (comp["hybrid_rrf"]["mrr"] - comp["fulltext_only"]["mrr"]) / comp["fulltext_only"]["mrr"] * 100
            logger.info("  RRF improvement over fulltext: %+.1f%%", improvement)
        report["evaluations"]["rrf"] = comp

        logger.info("\n  K Parameter Analysis:")
        for k, v in rrf.get("k_parameter_analysis", {}).items():
            logger.info("    K=%s: MRR=%.4f P@5=%.4f", k, v["mrr"], v["p@5"])

    if graph:
        logger.info("\n--- GRAPH RAG ---")
        logger.info("  Graph expansion hit rate: %.1f%%", graph["graph_expansion_hit_rate"] * 100)
        logger.info("  Avg related entities: %.1f", graph["avg_related_entities"])
        logger.info("  Sport detection accuracy: %.1f%%", graph["sport_detection_accuracy"] * 100)
        logger.info("  Latency with graph: %.1f ms", graph["latency_with_graph_ms"])
        logger.info("  Latency without graph: %.1f ms", graph["latency_without_graph_ms"])
        logger.info("  Graph overhead: %.1f ms", graph["graph_overhead_ms"])
        report["evaluations"]["graph_rag"] = graph

    # Save consolidated report
    report_path = RESULTS_DIR / "report_consolidated.json"
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    logger.info("\nConsolidated report saved to: %s", report_path)

    # Generate markdown table
    md_path = RESULTS_DIR / "REPORT.md"
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("# AI Evaluation Report\n\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")

        if retrieval:
            s = retrieval["summary"]
            f.write("## 1. Retrieval Metrics\n\n")
            f.write("| Metric | Value |\n|--------|-------|\n")
            f.write(f"| P@1 | {s['p@1']:.4f} |\n")
            f.write(f"| P@3 | {s['p@3']:.4f} |\n")
            f.write(f"| P@5 | {s['p@5']:.4f} |\n")
            f.write(f"| R@1 | {s['r@1']:.4f} |\n")
            f.write(f"| R@3 | {s['r@3']:.4f} |\n")
            f.write(f"| R@5 | {s['r@5']:.4f} |\n")
            f.write(f"| F1@5 | {s['f1@5']:.4f} |\n")
            f.write(f"| MRR | {s['mrr']:.4f} |\n")
            f.write(f"| NDCG@3 | {s['ndcg@3']:.4f} |\n")
            f.write(f"| NDCG@5 | {s['ndcg@5']:.4f} |\n")
            f.write(f"| Keyword Coverage | {s['keyword_coverage']:.4f} |\n")
            f.write(f"| Avg Latency | {s['avg_latency_ms']:.1f} ms |\n\n")

        if intent:
            s = intent["summary"]
            f.write("## 2. Intent Router Metrics\n\n")
            f.write("| Metric | Value |\n|--------|-------|\n")
            f.write(f"| Accuracy | {s['accuracy']:.4f} |\n")
            f.write(f"| Macro Precision | {s['macro_precision']:.4f} |\n")
            f.write(f"| Macro Recall | {s['macro_recall']:.4f} |\n")
            f.write(f"| Macro F1 | {s['macro_f1']:.4f} |\n")
            f.write(f"| Avg Latency | {s['avg_latency_ms']:.1f} ms |\n\n")

        if rrf:
            comp = rrf["approach_comparison"]
            f.write("## 3. RRF Fusion Comparison\n\n")
            f.write("| Approach | MRR | P@5 |\n|----------|-----|-----|\n")
            for name, m in comp.items():
                f.write(f"| {name} | {m['mrr']:.4f} | {m['p@5']:.4f} |\n")
            f.write("\n")

        if graph:
            f.write("## 4. Graph RAG Metrics\n\n")
            f.write("| Metric | Value |\n|--------|-------|\n")
            f.write(f"| Expansion Hit Rate | {graph['graph_expansion_hit_rate']*100:.1f}% |\n")
            f.write(f"| Avg Related Entities | {graph['avg_related_entities']:.1f} |\n")
            f.write(f"| Sport Detection Accuracy | {graph['sport_detection_accuracy']*100:.1f}% |\n")
            f.write(f"| Latency (with graph) | {graph['latency_with_graph_ms']:.1f} ms |\n")
            f.write(f"| Latency (no graph) | {graph['latency_without_graph_ms']:.1f} ms |\n")
            f.write(f"| Graph Overhead | {graph['graph_overhead_ms']:.1f} ms |\n\n")

    logger.info("Markdown report saved to: %s", md_path)


async def main():
    logger.info("=" * 70)
    logger.info("SPORTS VENUE AI CHATBOT — COMPREHENSIVE EVALUATION")
    logger.info("=" * 70)
    logger.info("Started at: %s", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

    start_time = time.perf_counter()

    # Run each evaluation phase
    try:
        await run_retrieval()
    except Exception as exc:
        logger.error("Retrieval evaluation failed: %s", exc)

    try:
        await run_intent()
    except Exception as exc:
        logger.error("Intent evaluation failed: %s", exc)

    try:
        await run_rrf()
    except Exception as exc:
        logger.error("RRF evaluation failed: %s", exc)

    try:
        await run_graph_rag()
    except Exception as exc:
        logger.error("Graph RAG evaluation failed: %s", exc)

    elapsed = time.perf_counter() - start_time
    logger.info("\nTotal evaluation time: %.1f seconds", elapsed)

    # Generate consolidated report
    generate_report()

    logger.info("\n" + "=" * 70)
    logger.info("EVALUATION COMPLETE")
    logger.info("=" * 70)


if __name__ == "__main__":
    asyncio.run(main())
