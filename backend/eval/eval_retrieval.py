"""
Retrieval Evaluation — Precision, Recall, F1, MRR, NDCG@K

Tests HybridKnowledgeRetriever against ground truth dataset.
Requires: Neo4j running with knowledge graph populated.

Usage:
    cd backend
    python -m eval.eval_retrieval
"""

import asyncio
import json
import logging
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from dotenv import load_dotenv
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

from app.core.config import settings
from app.core.neo4j_client import Neo4jClient
from app.kg.embeddings import NodeEmbedder
from app.kg.query import HybridKnowledgeRetriever

logging.basicConfig(level=logging.WARNING, format="%(message)s")
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

DATASET_PATH = Path(__file__).resolve().parent / "datasets" / "retrieval_ground_truth.json"


def load_dataset() -> list[dict]:
    with open(DATASET_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data["test_cases"]


def precision_at_k(retrieved: list[str], expected: set[str], k: int) -> float:
    top_k = retrieved[:k]
    if not top_k:
        return 0.0
    hits = sum(1 for r in top_k if r in expected)
    return hits / len(top_k)


def recall_at_k(retrieved: list[str], expected: set[str], k: int) -> float:
    if not expected:
        return 1.0
    top_k = retrieved[:k]
    hits = sum(1 for r in top_k if r in expected)
    return hits / len(expected)


def f1_at_k(precision: float, recall: float) -> float:
    if precision + recall == 0:
        return 0.0
    return 2 * precision * recall / (precision + recall)


def reciprocal_rank(retrieved: list[str], expected: set[str]) -> float:
    for i, r in enumerate(retrieved):
        if r in expected:
            return 1.0 / (i + 1)
    return 0.0


def ndcg_at_k(retrieved: list[str], expected: set[str], k: int) -> float:
    import math
    dcg = 0.0
    for i, r in enumerate(retrieved[:k]):
        rel = 1.0 if r in expected else 0.0
        dcg += rel / math.log2(i + 2)

    ideal_hits = min(len(expected), k)
    idcg = sum(1.0 / math.log2(i + 2) for i in range(ideal_hits))
    return dcg / idcg if idcg > 0 else 0.0


def keyword_coverage(retrieved_descriptions: list[str], expected_keywords: list[str]) -> float:
    if not expected_keywords:
        return 1.0
    combined = " ".join(retrieved_descriptions).lower()
    hits = sum(1 for kw in expected_keywords if kw.lower() in combined)
    return hits / len(expected_keywords)


async def main():
    logger.info("=" * 60)
    logger.info("RETRIEVAL EVALUATION — HybridKnowledgeRetriever")
    logger.info("=" * 60)

    dataset = load_dataset()
    logger.info("Loaded %d test cases", len(dataset))

    # Connect to Neo4j (AuraDB → Local fallback)
    from eval.neo4j_helper import connect_neo4j
    neo4j_driver = await connect_neo4j()
    
    class _Client:
        def __init__(self, driver):
            self._driver = driver
        async def execute_query(self, cypher, params=None):
            async with self._driver.session() as session:
                result = await session.run(cypher, params or {})
                return await result.data()
        async def connect(self): pass
        async def verify_connectivity(self): pass
        async def close(self): await self._driver.close()
    
    neo4j_client = _Client(neo4j_driver)

    # Create embedder
    embedder = NodeEmbedder(
        embedding_api_url=settings.EMBEDDING_API_URL,
        model_name=settings.EMBEDDING_MODEL,
    )

    retriever = HybridKnowledgeRetriever(
        neo4j_client=neo4j_client,
        embedder=embedder,
        embedding_timeout_seconds=settings.KG_EMBEDDING_TIMEOUT_SECONDS,
    )

    # Metrics accumulators
    metrics = {
        "p@1": [], "p@3": [], "p@5": [],
        "r@1": [], "r@3": [], "r@5": [],
        "f1@5": [],
        "mrr": [],
        "ndcg@3": [], "ndcg@5": [],
        "keyword_coverage": [],
        "latency_ms": [],
        "sources_used": {"fulltext_only": 0, "vector_only": 0, "both": 0},
    }

    results_detail = []

    for tc in dataset:
        query = tc["query"]
        expected_names = set(tc["expected_entities"])
        expected_keywords = tc.get("expected_keywords", [])

        start = time.perf_counter()
        try:
            results = await retriever.retrieve(query, limit=5)
        except Exception as exc:
            logger.warning("  FAIL [%s] '%s': %s", tc["id"], query, exc)
            continue
        latency = (time.perf_counter() - start) * 1000

        retrieved_names = [r.get("name", "") for r in results]
        retrieved_descs = [
            f"{r.get('name', '')} {r.get('description', '')} "
            + " ".join(
                rel.get('name', '') if isinstance(rel, dict) else str(rel)
                for rel in r.get("related_entities", [])[:3]
            )
            for r in results
        ]

        # Normalize for case-insensitive comparison
        retrieved_lower = [n.lower().strip() for n in retrieved_names]
        expected_lower = {n.lower().strip() for n in expected_names}

        # Track which retrieval sources were used
        for r in results:
            sources = r.get("retrieval_sources", [])
            if "fulltext" in sources and "vector" in sources:
                metrics["sources_used"]["both"] += 1
            elif "fulltext" in sources:
                metrics["sources_used"]["fulltext_only"] += 1
            elif "vector" in sources:
                metrics["sources_used"]["vector_only"] += 1

        p1 = precision_at_k(retrieved_lower, expected_lower, 1)
        p3 = precision_at_k(retrieved_lower, expected_lower, 3)
        p5 = precision_at_k(retrieved_lower, expected_lower, 5)
        r1 = recall_at_k(retrieved_lower, expected_lower, 1)
        r3 = recall_at_k(retrieved_lower, expected_lower, 3)
        r5 = recall_at_k(retrieved_lower, expected_lower, 5)
        f1 = f1_at_k(p5, r5)
        rr = reciprocal_rank(retrieved_lower, expected_lower)
        ndcg3 = ndcg_at_k(retrieved_lower, expected_lower, 3)
        ndcg5 = ndcg_at_k(retrieved_lower, expected_lower, 5)
        kw_cov = keyword_coverage(retrieved_descs, expected_keywords)

        metrics["p@1"].append(p1)
        metrics["p@3"].append(p3)
        metrics["p@5"].append(p5)
        metrics["r@1"].append(r1)
        metrics["r@3"].append(r3)
        metrics["r@5"].append(r5)
        metrics["f1@5"].append(f1)
        metrics["mrr"].append(rr)
        metrics["ndcg@3"].append(ndcg3)
        metrics["ndcg@5"].append(ndcg5)
        metrics["keyword_coverage"].append(kw_cov)
        metrics["latency_ms"].append(latency)

        hit = "HIT" if rr > 0 else "MISS"
        logger.info(
            "  [%s] %s P@5=%.2f R@5=%.2f RR=%.2f %dms — %s",
            tc["id"], hit, p5, r5, rr, latency, query[:40],
        )

        results_detail.append({
            "id": tc["id"],
            "query": query,
            "expected": list(expected_names),
            "retrieved": retrieved_names,
            "p@5": p5, "r@5": r5, "mrr": rr, "ndcg@5": ndcg5,
            "latency_ms": latency,
            "matched": [n for n in retrieved_names if n.lower().strip() in expected_lower],
        })

    # Print summary
    logger.info("")
    logger.info("=" * 60)
    logger.info("RESULTS SUMMARY")
    logger.info("=" * 60)

    n = len(metrics["p@1"])
    if n == 0:
        logger.error("No successful evaluations!")
        return

    def avg(lst): return sum(lst) / len(lst) if lst else 0

    logger.info("Test cases: %d", n)
    logger.info("")
    logger.info("--- Precision ---")
    logger.info("  P@1:  %.4f", avg(metrics["p@1"]))
    logger.info("  P@3:  %.4f", avg(metrics["p@3"]))
    logger.info("  P@5:  %.4f", avg(metrics["p@5"]))
    logger.info("")
    logger.info("--- Recall ---")
    logger.info("  R@1:  %.4f", avg(metrics["r@1"]))
    logger.info("  R@3:  %.4f", avg(metrics["r@3"]))
    logger.info("  R@5:  %.4f", avg(metrics["r@5"]))
    logger.info("")
    logger.info("--- F1 ---")
    logger.info("  F1@5: %.4f", avg(metrics["f1@5"]))
    logger.info("")
    logger.info("--- Ranking ---")
    logger.info("  MRR:      %.4f", avg(metrics["mrr"]))
    logger.info("  NDCG@3:   %.4f", avg(metrics["ndcg@3"]))
    logger.info("  NDCG@5:   %.4f", avg(metrics["ndcg@5"]))
    logger.info("")
    logger.info("--- Keyword Coverage ---")
    logger.info("  Avg:      %.4f", avg(metrics["keyword_coverage"]))
    logger.info("")
    logger.info("--- Latency ---")
    logger.info("  Avg:      %.1f ms", avg(metrics["latency_ms"]))
    logger.info("  P50:      %.1f ms", sorted(metrics["latency_ms"])[len(metrics["latency_ms"])//2])
    logger.info("  P95:      %.1f ms", sorted(metrics["latency_ms"])[int(len(metrics["latency_ms"])*0.95)])
    logger.info("")
    logger.info("--- Retrieval Sources ---")
    src = metrics["sources_used"]
    total = src["fulltext_only"] + src["vector_only"] + src["both"]
    logger.info("  Fulltext only: %d (%.1f%%)", src["fulltext_only"], 100*src["fulltext_only"]/max(total,1))
    logger.info("  Vector only:   %d (%.1f%%)", src["vector_only"], 100*src["vector_only"]/max(total,1))
    logger.info("  Both (fusion): %d (%.1f%%)", src["both"], 100*src["both"]/max(total,1))

    # Save detailed results
    output_path = Path(__file__).resolve().parent / "results_retrieval.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump({
            "summary": {
                "p@1": avg(metrics["p@1"]),
                "p@3": avg(metrics["p@3"]),
                "p@5": avg(metrics["p@5"]),
                "r@1": avg(metrics["r@1"]),
                "r@3": avg(metrics["r@3"]),
                "r@5": avg(metrics["r@5"]),
                "f1@5": avg(metrics["f1@5"]),
                "mrr": avg(metrics["mrr"]),
                "ndcg@3": avg(metrics["ndcg@3"]),
                "ndcg@5": avg(metrics["ndcg@5"]),
                "keyword_coverage": avg(metrics["keyword_coverage"]),
                "avg_latency_ms": avg(metrics["latency_ms"]),
                "sources_used": src,
            },
            "details": results_detail,
        }, f, ensure_ascii=False, indent=2)
    logger.info("")
    logger.info("Detailed results saved to: %s", output_path)

    await neo4j_client.close()


if __name__ == "__main__":
    asyncio.run(main())
