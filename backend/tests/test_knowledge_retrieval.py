from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.agent.tools.query_faq import _format_results
from app.agent.intent_router import IntentRouter
from app.core.neo4j_client import Neo4jClient
from app.kg.embeddings import NodeEmbedder
from app.kg.query import HybridKnowledgeRetriever


@pytest.mark.asyncio
async def test_hybrid_retrieval_fuses_text_vector_and_graph_context():
    client = AsyncMock()
    embedder = AsyncMock()
    embedder.embed_query.return_value = [0.1, 0.2, 0.3]

    async def execute_query(query, params):
        if "db.index.fulltext.queryNodes" in query:
            return [
                {
                    "node_id": "rule-serve",
                    "name": "Luật giao bóng pickleball",
                    "type": "Rule",
                    "description": "Giao bóng phải thực hiện đúng vùng quy định.",
                    "source": "USAP",
                    "score": 2.4,
                },
                {
                    "node_id": "rule-score",
                    "name": "Luật tính điểm pickleball",
                    "type": "Rule",
                    "description": "Quy định cách tính điểm.",
                    "source": "USAP",
                    "score": 1.2,
                },
            ]
        if "db.index.vector.queryNodes" in query:
            return [
                {
                    "node_id": "rule-serve",
                    "name": "Luật giao bóng pickleball",
                    "type": "Rule",
                    "description": "Giao bóng phải thực hiện đúng vùng quy định.",
                    "source": "USAP",
                    "score": 0.91,
                },
                {
                    "node_id": "tech-serve",
                    "name": "Kỹ thuật giao bóng",
                    "type": "Technique",
                    "description": "Kỹ thuật giao bóng ổn định.",
                    "source": "USAP",
                    "score": 0.84,
                },
            ]
        if "MATCH path" in query:
            return [
                {
                    "seed_id": "rule-serve",
                    "related_name": "Pickleball",
                    "related_type": "Sport",
                    "related_description": "Môn thể thao pickleball.",
                    "related_source": "USAP",
                    "relationship_path": ["THUOC"],
                    "distance": 1,
                },
                {
                    "seed_id": "rule-serve",
                    "related_name": "Lỗi giao bóng",
                    "related_type": "Concept",
                    "related_description": "Các lỗi thường gặp khi giao bóng.",
                    "related_source": "USAP",
                    "relationship_path": ["QUY_DINH"],
                    "distance": 1,
                },
                {
                    "seed_id": "rule-serve",
                    "related_name": "Vùng giao bóng",
                    "related_type": "Concept",
                    "related_description": "Khu vực bóng phải rơi vào.",
                    "related_source": "USAP",
                    "relationship_path": ["THUOC", "LIEN_QUAN"],
                    "distance": 2,
                },
            ]
        return []

    client.execute_query.side_effect = execute_query
    retriever = HybridKnowledgeRetriever(client, embedder=embedder)

    results = await retriever.retrieve(
        "Luật giao bóng pickleball như thế nào?",
        limit=3,
    )

    assert results[0]["node_id"] == "rule-serve"
    assert set(results[0]["retrieval_sources"]) == {"fulltext", "vector"}
    assert results[0]["matched_sport"] == "pickleball"
    assert [item["name"] for item in results[0]["related_entities"]] == [
        "Pickleball",
        "Lỗi giao bóng",
        "Vùng giao bóng",
    ]
    assert results[0]["related_entities"][2]["distance"] == 2
    queries = [call.args[0] for call in client.execute_query.await_args_list]
    assert any("head([label IN labels(node)" in query for query in queries)
    assert any("head([label IN labels(related)" in query for query in queries)


@pytest.mark.asyncio
async def test_hybrid_retrieval_falls_back_when_vector_index_is_missing():
    client = AsyncMock()
    embedder = AsyncMock()
    embedder.embed_query.return_value = [0.4, 0.5]

    async def execute_query(query, params):
        if "db.index.fulltext.queryNodes" in query:
            return [
                {
                    "node_id": "badminton-smash",
                    "name": "Kỹ thuật đập cầu",
                    "type": "Technique",
                    "description": "Đập cầu ở điểm tiếp xúc cao.",
                    "source": "BWF",
                    "score": 1.8,
                }
            ]
        if "db.index.vector.queryNodes" in query:
            raise RuntimeError("There is no such vector schema index")
        if "MATCH path" in query:
            return []
        return []

    client.execute_query.side_effect = execute_query
    retriever = HybridKnowledgeRetriever(client, embedder=embedder)

    results = await retriever.retrieve("Làm sao smash cầu lông mạnh hơn?", limit=2)

    assert len(results) == 1
    assert results[0]["name"] == "Kỹ thuật đập cầu"
    assert results[0]["retrieval_sources"] == ["fulltext"]


@pytest.mark.asyncio
async def test_hybrid_retrieval_uses_keyword_fallback_without_fulltext_index():
    client = AsyncMock()

    async def execute_query(query, params):
        if "db.index.fulltext.queryNodes" in query:
            raise RuntimeError("full-text index missing")
        if "reduce(matches" in query:
            assert "bida" in params["terms"]
            return [
                {
                    "node_id": "billiards-concept",
                    "name": "Đường ngắm bida",
                    "type": "Concept",
                    "description": "Cách xác định đường đi của bi mục tiêu.",
                    "source": "WPA",
                    "score": 2.0,
                }
            ]
        if "MATCH path" in query:
            return []
        return []

    client.execute_query.side_effect = execute_query
    retriever = HybridKnowledgeRetriever(client)

    results = await retriever.retrieve("Cách ngắm bida chính xác", limit=2)

    assert len(results) == 1
    assert results[0]["name"] == "Đường ngắm bida"
    assert results[0]["retrieval_sources"] == ["fulltext"]


@pytest.mark.asyncio
async def test_hybrid_retrieval_uses_keyword_fallback_when_fulltext_is_empty():
    client = AsyncMock()

    async def execute_query(query, params):
        if "db.index.fulltext.queryNodes" in query:
            return []
        if "reduce(matches" in query:
            return [
                {
                    "node_id": "badminton-serve",
                    "name": "Luật giao cầu lông",
                    "type": "Rule",
                    "description": "Điểm tiếp xúc cầu phải đúng quy định.",
                    "source": "BWF",
                    "score": 2.0,
                }
            ]
        if "MATCH path" in query:
            return []
        return []

    client.execute_query.side_effect = execute_query
    retriever = HybridKnowledgeRetriever(client)

    results = await retriever.retrieve("Luật giao cầu lông", limit=2)

    assert len(results) == 1
    assert results[0]["name"] == "Luật giao cầu lông"


@pytest.mark.asyncio
async def test_hybrid_retrieval_expands_vietnamese_badminton_query_to_english_terms():
    client = AsyncMock()

    async def execute_query(query, params):
        if "db.index.fulltext.queryNodes" in query:
            return []
        if "reduce(matches" in query:
            assert "badminton" in params["terms"]
            assert "service" in params["terms"]
            assert "serve" in params["terms"]
            assert "rules" in params["terms"]
            return [
                {
                    "node_id": "badminton-service-faults",
                    "name": "Service faults",
                    "type": "Rule",
                    "description": (
                        "Service faults are a specific category of faults that "
                        "occur during the serve in badminton."
                    ),
                    "source": "BWF",
                    "score": 4.0,
                }
            ]
        if "MATCH path" in query:
            return []
        return []

    client.execute_query.side_effect = execute_query
    retriever = HybridKnowledgeRetriever(client)

    results = await retriever.retrieve("Luật giao bóng cầu lông như thế nào?", limit=2)

    assert len(results) == 1
    assert results[0]["name"] == "Service faults"


def test_format_results_keeps_related_node_when_it_is_also_a_primary_result():
    results = [
        {
            "name": "Luật giao bóng",
            "type": "Rule",
            "description": "Quy định giao bóng.",
            "related_entities": [
                {
                    "name": "Pickleball",
                    "description": "Môn thể thao pickleball.",
                    "relationship_path": ["THUOC"],
                    "distance": 1,
                }
            ],
        },
        {
            "name": "Pickleball",
            "type": "Sport",
            "description": "Tổng quan môn pickleball.",
            "related_entities": [],
        },
    ]

    formatted = _format_results(results)

    assert "**Pickleball** [Sport]" in formatted


@pytest.mark.asyncio
async def test_vector_index_uses_common_knowledge_entity_label():
    embedder = NodeEmbedder()
    embedder._generate_embedding = AsyncMock(return_value=[0.1, 0.2, 0.3])

    session = AsyncMock()
    driver = MagicMock(spec=["session"])
    session_context = MagicMock()
    session_context.__aenter__ = AsyncMock(return_value=session)
    session_context.__aexit__ = AsyncMock(return_value=False)
    driver.session.return_value = session_context

    await embedder._ensure_vector_index(driver, dimension=3)

    queries = [call.args[0] for call in session.run.await_args_list]
    assert any("SET n:KnowledgeEntity" in query for query in queries)
    assert any("FOR (n:KnowledgeEntity)" in query for query in queries)
    assert any("OPTIONS {indexConfig:" in query for query in queries)
    assert any(query.endswith("'cosine'}}") for query in queries)
    assert all("Rule|Technique" not in query for query in queries)


@pytest.mark.asyncio
async def test_startup_embedding_sync_stores_only_missing_or_stale_nodes():
    client = AsyncMock(spec=Neo4jClient)
    embedder = NodeEmbedder()
    embedder.generate_embeddings = AsyncMock(
        return_value=[[0.1, 0.2], [0.3, 0.4]]
    )

    async def execute_query(query, params):
        if "SET n:KnowledgeEntity" in query and "UNWIND" not in query:
            return []
        if "AS embedding_source" in query:
            return [
                {
                    "node_id": "rule-1",
                    "name": "Luật giao bóng",
                    "type": "Rule",
                    "description": "Quy định giao bóng.",
                    "embedding_source": "Luật giao bóng\nQuy định giao bóng.",
                },
                {
                    "node_id": "tech-1",
                    "name": "Kỹ thuật smash",
                    "type": "Technique",
                    "description": "Đập cầu ở điểm cao.",
                    "embedding_source": "Kỹ thuật smash\nĐập cầu ở điểm cao.",
                },
            ]
        if "CREATE VECTOR INDEX" in query:
            return []
        if "UNWIND $rows" in query:
            assert params["model"] == "nomic-embed-text"
            assert params["profile"] == "nomic-v1.5-task-prefix-v1"
            assert len(params["rows"]) == 2
            return [{"stored": 2}]
        return []

    client.execute_query.side_effect = execute_query

    stats = await embedder.sync_missing_embeddings(client)

    assert stats == {"checked": 2, "stored": 2}
    embedder.generate_embeddings.assert_awaited_once()


@pytest.mark.asyncio
async def test_startup_embedding_sync_skips_ollama_when_graph_is_current():
    client = AsyncMock(spec=Neo4jClient)
    embedder = NodeEmbedder()
    embedder.generate_embeddings = AsyncMock()

    async def execute_query(query, params):
        if "SET n:KnowledgeEntity" in query:
            return []
        if "AS embedding_source" in query:
            return []
        if "size(n.embedding)" in query:
            return [{"dimension": 768}]
        if "CREATE VECTOR INDEX" in query:
            return []
        return []

    client.execute_query.side_effect = execute_query

    stats = await embedder.sync_missing_embeddings(client)

    assert stats == {"checked": 0, "stored": 0}
    embedder.generate_embeddings.assert_not_awaited()


@pytest.mark.asyncio
async def test_nomic_embedder_uses_task_specific_prefixes():
    embedder = NodeEmbedder(model_name="nomic-embed-text")
    embedder._generate_embedding = AsyncMock(return_value=[0.1, 0.2])

    document_text = embedder._prepare_embedding_text(
        {
            "name": "Luật giao bóng",
            "type": "Rule",
            "description": "Quy định giao bóng.",
        }
    )
    await embedder.embed_query("Giao bóng thế nào?")
    await embedder.embed_classification("Cách nấu phở")

    assert document_text.startswith("search_document: ")
    calls = [call.args[0] for call in embedder._generate_embedding.await_args_list]
    assert calls == [
        "search_query: Giao bóng thế nào?",
        "classification: Cách nấu phở",
    ]


@pytest.mark.asyncio
@patch("app.agent.intent_router.redis_client")
async def test_intent_router_reuses_cached_exemplar_embeddings(mock_redis):
    embedder = MagicMock()
    embedder.model_name = "nomic-embed-text"
    embedder.embedding_profile = "nomic-v1.5-task-prefix-v1"
    embedder.embed_classification = AsyncMock()
    mock_redis.get_json = AsyncMock(
        return_value={
            "greeting": [[1.0, 0.0]],
            "domain": [[0.0, 1.0]],
            "sports": [[0.5, 0.5]],
            "off_topic": [[-1.0, 0.0]],
        }
    )

    router = IntentRouter(embedder=embedder)
    await router.initialize()

    assert router._embedding_ready is True
    embedder.embed_classification.assert_not_awaited()
    mock_redis.get_json.assert_awaited_once()
