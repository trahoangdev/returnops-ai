# 06 — Policy Knowledge Base & RAG Specification

## Purpose

RAG helps **locate and cite published textual policy**. It is not the business rule evaluator. The same published version has a deterministic YAML/rule representation for execution; any mismatch between prose and rules is a content-release defect and blocks publishing.

## Documents

Each policy document has: `tenant_id`, `policy_version_id`, `doc_id`, `title`, `status` (`DRAFT`/`PUBLISHED`), `effective_from`, `effective_to`, `content_sha256`, `source_uri` (local repo), `language`. Each chunk has `chunk_id`, section heading, canonical text, `ordinal`, `embedding_model`, `embedding`, `policy_version_id` and `source_hash`.

## Version-aware ingest

1. Admin edits **draft** Markdown policy and YAML rules.
2. Validator checks linked rule IDs, dates, allowed item categories and non-overlapping effective intervals.
3. Split by numbered section boundaries, not arbitrary sentence mixing. Target 150–350 tokens/chunk; small docs may simply use one section per chunk.
4. Compute content hash, embed under a pinned embedding model/version, insert chunks transactionally.
5. Publish version atomically; never mutate a published document.
6. Existing orders keep bound policy version; reindex/re-embed as a new index generation, not by silently changing text/history.

## Retrieval query and filters

Request context always includes server-resolved `tenant_id` and `order.policy_version_id`. Retrieval first filters these fields and `status='PUBLISHED'`. Never search across tenants or policy versions and filter *only afterward*.

Baseline: deterministic lookup by rule ID / keyword (small policy corpus) + Supabase PostgreSQL full-text. Add pgvector cosine similarity and reciprocal rank fusion as experimental improvement. If using HNSW, benchmark recall under metadata filters since approximate retrieval can under-return filtered results. **Do not introduce vector search just for architecture theater**; include comparison against simple baseline.

## Evidence contract

```json
{
  "policy_version_id": "POL-2026-001",
  "citations": [
    {
      "chunk_id": "POL-2026-001:R-002",
      "section": "Normal returns / timing",
      "rule_id": "R-002",
      "quote": "Normal changed-mind returns: through local calendar day 14 inclusive"
    }
  ],
  "retrieval_status": "OK"
}
```

Quotes above are fixture examples rather than actual published statutory language. In the app, quotations must be **verbatim source spans** and displayed alongside rule version ID. If retrieved citations conflict with deterministic rules, set `RETRIEVAL_CONFLICT` and escalate; do not auto-answer.

## Retrieval quality eval

Construct at least 30 labeled policy questions across synonyms, ambiguous wording, time boundaries, excluded categories and injection attacks. Score Recall@3, MRR, version leakage count, citation precision and unsupported claim rate. For each case, define expected `rule_id` and `policy_version_id`. Compare `keyword` vs `vector` vs `hybrid + reranker` on identical dataset; log embedding/index version and retrieval latency.

## Guardrails

- Treat all retrieved text as **data**, never instructions; delimit source passages with provenance and escape untrusted content.
- Bound query length/chunk count; redact PII from search queries.
- No HTTP fetch from arbitrary customer-supplied URL.
- Policy changes require admin auth and release validation.
- Prevent chunk spoofing by enforcing server-side version/rule metadata; never accept citations invented by LLM.

## Source references

- pgvector hybrid search and index considerations: https://github.com/pgvector/pgvector/blob/master/README.md
- LangGraph persistence: https://docs.langchain.com/oss/python/langgraph/persistence

## Supabase pgvector notes

Supabase enables the extension named `vector` (typically in `extensions` schema). Reference DDL uses `extensions.vector(1536)` as a placeholder; choose a matching embedding provider and dimension before generating final migration. Retrieval executes in FastAPI over scoped SQL, **not** client-side Data API calls. Authenticated browsers cannot query `policy_chunks` directly. Review metadata filters and pgvector index recall after choosing HNSW/IVFFlat.
