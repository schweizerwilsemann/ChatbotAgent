# AI Evaluation Report

Generated: 2026-06-25 15:45:06

## 1. Retrieval Metrics

| Metric | Value |
|--------|-------|
| P@1 | 0.5200 |
| P@3 | 0.3333 |
| P@5 | 0.2320 |
| R@1 | 0.3600 |
| R@3 | 0.7200 |
| R@5 | 0.8333 |
| F1@5 | 0.3500 |
| MRR | 0.5800 |
| NDCG@3 | 0.6194 |
| NDCG@5 | 0.6699 |
| Keyword Coverage | 0.2733 |
| Avg Latency | 472.6 ms |

## 2. Intent Router Metrics

| Metric | Value |
|--------|-------|
| Accuracy | 0.9000 |
| Macro Precision | 1.0000 |
| Macro Recall | 0.8500 |
| Macro F1 | 0.8929 |
| Avg Latency | 49.9 ms |

## 3. RRF Fusion Comparison

| Approach | MRR | P@5 |
|----------|-----|-----|
| hybrid_rrf | 0.5067 | 0.1920 |
| fulltext_only | 0.7000 | 0.3360 |
| vector_only | 0.1933 | 0.0880 |

## 4. Graph RAG Metrics

| Metric | Value |
|--------|-------|
| Expansion Hit Rate | 92.8% |
| Avg Related Entities | 3.5 |
| Sport Detection Accuracy | 84.8% |
| Latency (with graph) | 610.7 ms |
| Latency (no graph) | 375.2 ms |
| Graph Overhead | 235.5 ms |

