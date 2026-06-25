"""
RRF Fusion Evaluation — Compares Hybrid vs Fulltext-only vs Vector-only

Demonstrates that RRF fusion outperforms individual retrieval methods.

Usage:
    cd backend
    python -m eval.eval_rrf
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


def reciprocal_rank(retrieved: list[str], expected: set[str]) -> float:
    for i, r in enumerate(retrieved):
        if r in expected:
            return 1.0 / (i + 1)
    return 0.0


def precision_at_k(retrieved: list[str], expected: set[str], k: int) -> float:
    top_k = retrieved[:k]
    if not top_k:
        return 0.0
    return sum(1 for r in top_k if r in expected) / len(top_k)


async def main():
    logger.info("=" * 60)
    logger.info("RRF FUSION EVALUATION — Hybrid vs Single Methods")
    logger.info("=" * 60)

    dataset = load_dataset()

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

    embedder = NodeEmbedder(
        embedding_api_url=settings.EMBEDDING_API_URL,
        model_name=settings.EMBEDDING_MODEL,
    )

    retriever = HybridKnowledgeRetriever(
        neo4j_client=neo4j_client,
        embedder=embedder,
        embedding_timeout_seconds=settings.KG_EMBEDDING_TIMEOUT_SECONDS,
    )

    # Collect metrics for 3 approaches
    approaches = {
        "hybrid_rrf": {"mrr": [], "p@5": [], "r@5": []},
        "fulltext_only": {"mrr": [], "p@5": [], "r@5": []},
        "vector_only": {"mrr": [], "p@5": [], "r@5": []},
    }

    for tc in dataset:
        query = tc["query"]
        expected = set(tc["expected_entities"])

        # 1. Hybrid (full retrieval pipeline)
        try:
            hybrid_results = await retriever.retrieve(query, limit=5)
            hybrid_names = [r.get("name", "") for r in hybrid_results]
        except Exception:
            hybrid_names = []

        # 2. Fulltext only
        try:
            ft_results = await retriever._fulltext_search(query, 5)
            ft_names = [r.get("name", "") for r in ft_results]
        except Exception:
            ft_names = []

        # 3. Vector only
        try:
            embedding = await retriever._embed_query(query)
            if embedding:
                vec_results = await retriever._vector_search(embedding, 5)
                vec_names = [r.get("name", "") for r in vec_results]
            else:
                vec_names = []
        except Exception:
            vec_names = []

        approaches["hybrid_rrf"]["mrr"].append(reciprocal_rank(hybrid_names, expected))
        approaches["hybrid_rrf"]["p@5"].append(precision_at_k(hybrid_names, expected, 5))
        approaches["hybrid_rrf"]["r@5"].append(precision_at_k(hybrid_names, expected, 5))

        approaches["fulltext_only"]["mrr"].append(reciprocal_rank(ft_names, expected))
        approaches["fulltext_only"]["p@5"].append(precision_at_k(ft_names, expected, 5))
        approaches["fulltext_only"]["r@5"].append(precision_at_k(ft_names, expected, 5))

        approaches["vector_only"]["mrr"].append(reciprocal_rank(vec_names, expected))
        approaches["vector_only"]["p@5"].append(precision_at_k(vec_names, expected, 5))
        approaches["vector_only"]["r@5"].append(precision_at_k(vec_names, expected, 5))

    # Print comparison
    logger.info("")
    logger.info("=" * 60)
    logger.info("COMPARISON RESULTS")
    logger.info("=" * 60)
    logger.info("")
    logger.info("%-20s %10s %10s %10s", "Approach", "MRR", "P@5", "R@5")
    logger.info("-" * 55)

    def avg(lst): return sum(lst) / len(lst) if lst else 0

    results = {}
    for name, metrics in approaches.items():
        mrr = avg(metrics["mrr"])
        p5 = avg(metrics["p@5"])
        r5 = avg(metrics["r@5"])
        results[name] = {"mrr": mrr, "p@5": p5, "r@5": r5}
        logger.info("%-20s %10.4f %10.4f %10.4f", name, mrr, p5, r5)

    # Show improvement
    if results["fulltext_only"]["mrr"] > 0:
        mrr_improvement = (results["hybrid_rrf"]["mrr"] - results["fulltext_only"]["mrr"]) / results["fulltext_only"]["mrr"] * 100
        logger.info("")
        logger.info("RRF vs Fulltext-only MRR improvement: %+.1f%%", mrr_improvement)
    if results["vector_only"]["mrr"] > 0:
        mrr_improvement = (results["hybrid_rrf"]["mrr"] - results["vector_only"]["mrr"]) / results["vector_only"]["mrr"] * 100
        logger.info("RRF vs Vector-only MRR improvement:  %+.1f%%", mrr_improvement)

    # RRF K value analysis
    logger.info("")
    logger.info("--- RRF K Parameter Analysis ---")
    logger.info("%-8s %10s %10s %10s", "K", "MRR", "P@5", "R@5")
    logger.info("-" * 40)

    k_results = {}
    for k in [10, 30, 60, 100, 200]:
        # Re-compute RRF with different K
        mrrs = []
        p5s = []
        for tc in dataset:
            query = tc["query"]
            expected = set(tc["expected_entities"])
            try:
                ft_results = await retriever._fulltext_search(query, 10)
                embedding = await retriever._embed_query(query)
                vec_results = []
                if embedding:
                    vec_results = await retriever._vector_search(embedding, 10)
            except Exception:
                continue

            # Manual RRF with custom K
            merged = {}
            for rank, r in enumerate(ft_results, 1):
                key = r.get("name", "")
                merged.setdefault(key, {"name": key, "score": 0.0})
                merged[key]["score"] += 1.0 / (k + rank)
            for rank, r in enumerate(vec_results, 1):
                key = r.get("name", "")
                merged.setdefault(key, {"name": key, "score": 0.0})
                merged[key]["score"] += 1.1 / (k + rank)

            sorted_results = sorted(merged.values(), key=lambda x: x["score"], reverse=True)
            names = [r["name"] for r in sorted_results[:5]]
            mrrs.append(reciprocal_rank(names, expected))
            p5s.append(precision_at_k(names, expected, 5))

        mrr_val = avg(mrrs)
        p5_val = avg(p5s)
        k_results[k] = {"mrr": mrr_val, "p@5": p5_val}
        marker = " ← current" if k == 60 else ""
        logger.info("%-8d %10.4f %10.4f %10s%s", k, mrr_val, p5_val, "", marker)

    # Save results
    output_path = Path(__file__).resolve().parent / "results_rrf.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump({
            "approach_comparison": results,
            "k_parameter_analysis": k_results,
        }, f, ensure_ascii=False, indent=2)
    logger.info("")
    logger.info("Results saved to: %s", output_path)

    await neo4j_client.close()


if __name__ == "__main__":
    asyncio.run(main())
