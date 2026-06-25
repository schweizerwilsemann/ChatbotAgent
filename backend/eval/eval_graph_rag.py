"""
Graph RAG Evaluation — Tests graph expansion + sport-aware re-ranking

Measures:
- Graph expansion hit rate (does expansion add relevant entities?)
- Sport-aware boost effectiveness
- Relationship weight contribution
- Latency overhead of graph operations

Usage:
    cd backend
    python -m eval.eval_graph_rag
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


async def main():
    logger.info("=" * 60)
    logger.info("GRAPH RAG EVALUATION — Expansion & Re-ranking")
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

    # Metrics
    metrics = {
        "graph_expansion_hit_rate": 0,
        "graph_expansion_miss_rate": 0,
        "avg_related_entities": [],
        "sport_detection_accuracy": [],
        "sport_boost_cases": 0,
        "type_boost_cases": 0,
        "latency_with_graph_ms": [],
        "latency_without_graph_ms": [],
    }

    for tc in dataset:
        query = tc["query"]
        expected_sport = tc.get("sport", "")
        expected_type = tc.get("expected_type", "")

        # Test with graph expansion (full pipeline)
        start = time.perf_counter()
        try:
            results_full = await retriever.retrieve(query, limit=5)
        except Exception:
            continue
        latency_full = (time.perf_counter() - start) * 1000
        metrics["latency_with_graph_ms"].append(latency_full)

        # Test without graph expansion (RRF only, no enrichment)
        start = time.perf_counter()
        try:
            candidate_limit = 15
            ft_results = await retriever._fulltext_search(query, candidate_limit)
            embedding = await retriever._embed_query(query)
            vec_results = []
            if embedding:
                vec_results = await retriever._vector_search(embedding, candidate_limit)
            results_no_graph = retriever._reciprocal_rank_fusion(ft_results, vec_results)[:5]
        except Exception:
            results_no_graph = []
        latency_no_graph = (time.perf_counter() - start) * 1000
        metrics["latency_without_graph_ms"].append(latency_no_graph)

        # Check if graph expansion added relevant entities
        for r in results_full:
            related = r.get("related_entities", [])
            metrics["avg_related_entities"].append(len(related))

            if related:
                metrics["graph_expansion_hit_rate"] += 1
            else:
                metrics["graph_expansion_miss_rate"] += 1

            # Check sport match
            matched_sport = r.get("matched_sport")
            if expected_sport and matched_sport == expected_sport:
                metrics["sport_detection_accuracy"].append(1)
            elif expected_sport:
                metrics["sport_detection_accuracy"].append(0)

            # Check if boost was applied (score increased)
            if r.get("score", 0) > 0:
                raw_scores = r.get("raw_scores", {})
                if raw_scores:
                    metrics["sport_boost_cases"] += 1

    # Print results
    logger.info("")
    logger.info("=" * 60)
    logger.info("RESULTS")
    logger.info("=" * 60)

    def avg(lst): return sum(lst) / len(lst) if lst else 0

    total_expansion = metrics["graph_expansion_hit_rate"] + metrics["graph_expansion_miss_rate"]
    logger.info("")
    logger.info("--- Graph Expansion ---")
    logger.info("  Total results examined: %d", total_expansion)
    logger.info("  With related entities:  %d (%.1f%%)",
                metrics["graph_expansion_hit_rate"],
                100 * metrics["graph_expansion_hit_rate"] / max(total_expansion, 1))
    logger.info("  Avg related entities:   %.1f", avg(metrics["avg_related_entities"]))

    logger.info("")
    logger.info("--- Sport Detection ---")
    if metrics["sport_detection_accuracy"]:
        sport_acc = avg(metrics["sport_detection_accuracy"])
        logger.info("  Accuracy: %.4f (%d/%d)",
                    sport_acc,
                    sum(metrics["sport_detection_accuracy"]),
                    len(metrics["sport_detection_accuracy"]))
    else:
        logger.info("  No sport detection cases")

    logger.info("")
    logger.info("--- Latency Impact ---")
    logger.info("  With graph expansion:    %.1f ms avg", avg(metrics["latency_with_graph_ms"]))
    logger.info("  Without graph expansion: %.1f ms avg", avg(metrics["latency_without_graph_ms"]))
    overhead = avg(metrics["latency_with_graph_ms"]) - avg(metrics["latency_without_graph_ms"])
    logger.info("  Graph overhead:          %.1f ms (+%.1f%%)",
                overhead,
                100 * overhead / max(avg(metrics["latency_without_graph_ms"]), 1))

    # Relationship weight analysis
    logger.info("")
    logger.info("--- Relationship Weight Analysis ---")
    logger.info("%-15s %8s %s", "Relationship", "Weight", "Description")
    logger.info("-" * 50)
    weight_desc = {
        "THUOC": "belongs to (hard classification)",
        "QUY_DINH": "regulates (hard rule)",
        "DUNG_DE": "used for (purpose)",
        "SU_DUNG": "uses (dependency)",
        "LA_LOAI": "is a type of (taxonomy)",
        "LIEN_QUAN": "related to (soft association)",
    }
    for rel, weight in retriever._RELATION_WEIGHTS.items():
        logger.info("%-15s %8.1f %s", rel, weight, weight_desc.get(rel, ""))

    # Save results
    output_path = Path(__file__).resolve().parent / "results_graph_rag.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump({
            "graph_expansion_hit_rate": metrics["graph_expansion_hit_rate"] / max(total_expansion, 1),
            "avg_related_entities": avg(metrics["avg_related_entities"]),
            "sport_detection_accuracy": avg(metrics["sport_detection_accuracy"]) if metrics["sport_detection_accuracy"] else 0,
            "latency_with_graph_ms": avg(metrics["latency_with_graph_ms"]),
            "latency_without_graph_ms": avg(metrics["latency_without_graph_ms"]),
            "graph_overhead_ms": overhead,
            "relationship_weights": retriever._RELATION_WEIGHTS,
        }, f, ensure_ascii=False, indent=2)
    logger.info("")
    logger.info("Results saved to: %s", output_path)

    await neo4j_client.close()


if __name__ == "__main__":
    asyncio.run(main())
