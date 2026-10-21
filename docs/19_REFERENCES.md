# 19 — Research & Official Documentation References

Checked around **2026-10-22**. Vendor APIs/pricing can change: pin versions and verify docs again when coding. Links are for technical grounding and inspiration, not proof that this project has been implemented or benchmarked.

1. **LangGraph interrupts (human-in-the-loop), checkpoints and resume**  
   https://docs.langchain.com/oss/python/langgraph/interrupts
2. **LangGraph persistence** (checkpointer vs store, durable threads)  
   https://docs.langchain.com/oss/python/langgraph/persistence
3. **FastAPI OAuth2 / JWT tutorial** (examples; apply production identity validation)  
   https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/
4. **pgvector official README** (exact/approximate vector search, HNSW, hybrid retrieval)  
   https://github.com/pgvector/pgvector/blob/master/README.md
5. **τ²-bench (tau2-bench)** customer-service domain simulation; look at retail domain/task design, check license and separate benchmark tasks from ReturnOps fixtures  
   https://github.com/sierra-research/tau2-bench
6. **Langfuse current Python SDK docs**, note OpenTelemetry-based SDK changes  
   https://python.reference.langfuse.com/langfuse
7. **Langfuse experiments via SDK** (dataset runner and evals)  
   https://langfuse.com/docs/evaluation/experiments/experiments-via-sdk
8. **OWASP LLM Top 10 — Excessive Agency**  
   https://genai.owasp.org/llmrisk/llm062025-excessive-agency/
9. **OWASP LLM Top 10 2025**  
   https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/
10. **OpenTelemetry demo** (optional observability patterns, not needed for MVP)  
    https://github.com/open-telemetry/opentelemetry-demo

## Distinguish sources from design assumptions

The following are **ReturnOps project decisions**, not documented external facts: 14-day normal return window, 30-day damaged-item review period, 5,000,000 VND demo maximum, all-refunds-human-approval rule, target p95 latency, proposed eval success thresholds, 6-week estimate and selected stack. They must not be represented as common industry or legal standards.

## Reuse and licensing

Link to and cite external projects; don't redistribute benchmark data or code without verifying original license and dataset terms. Version/control provenance of any adapted evaluation prompts, policies or fixtures. Use only invented ReturnOps customer/order data in public repo.

## Supabase references (checked for v1.1)

- Supabase changelog (review new breaking changes before implementation): https://supabase.com/changelog
- Local development workflow / SQL migrations: https://supabase.com/docs/guides/local-development/cli-workflows
- Row Level Security / exposed schemas: https://supabase.com/docs/guides/database/postgres/row-level-security
- Data API security/grants: https://supabase.com/docs/guides/api/securing-your-api
- Supabase Auth + SSR Next.js: https://supabase.com/docs/guides/auth/server-side/nextjs
- Supabase database connection modes/poolers: https://supabase.com/docs/guides/database/connecting-to-postgres
- pgvector on Supabase: https://supabase.com/docs/guides/database/extensions/pgvector
