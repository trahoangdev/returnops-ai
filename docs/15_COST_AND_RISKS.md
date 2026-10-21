# 15 — Cost Model, Risks & Tradeoffs

## Cost accounting (formula-based, not live price quotes)

Monthly cost depends on selected provider/model, number of test runs, message tokens, embedding jobs, tracing retention and hosting. Do not treat these as current vendor quotes.

Let `N` = conversations, `t_in`/`t_out` = average tokens per conversation, and `p_in`/`p_out` = respective model USD per 1M tokens:

`LLM_cost_usd = N * (t_in*p_in + t_out*p_out) / 1_000_000`

Add: embedding requests (`embedding_tokens / 1e6 * rate`), Supabase subscription/compute, DB size, backups, egress and storage, tracing, bandwidth, eval repeats. Track **cost per successfully completed case**, not just cost per LLM request.

### Worked hypothetical (NOT provider pricing)

For **1,000 conversations**, each with **5,000 input tokens + 1,000 output tokens**, assumed toy price **$1/1M input tokens + $5/1M output tokens**: inference component = `1000 * (5000*1 + 1000*5)/1_000_000 = $10`. Actual cost can be very different. Hosting and retries excluded. Re-check real provider pricing before budgeting.

## Cost controls

- Cache published policy embeddings by content hash and model version.
- Hard max model steps/tokens, no unbounded retries.
- Run deterministic eval on each PR; live model eval on demand/limited quota.
- Traces sampled in shared demo; full metadata only on test failures with redacted content.
- Compare small and large models on strict success **and** cost, not accuracy alone.

## Risk register

| Risk | Likelihood | Impact | Mitigation/owner |
|---|---|---|---|
| R-01 Authorization bypass | Medium | Critical | RBAC + owner-scoped query + adversarial tests; backend |
| R-02 Duplicate fake refund | Medium | Critical | Unique ledger, transaction locks, idempotency; backend |
| R-03 Policy/text divergence | Medium | High | Versioned release + rule-to-section validation; domain |
| R-04 Wrong cited clause | Medium | High | Rule-aware retrieval, strict citation grading; AI |
| R-05 Prompt injection | High | High | No write tools, trust boundaries, injection eval; AI/security |
| R-06 Model/provider changes | Medium | Medium | Pin version/adapter; smoke and eval; AI |
| R-07 Benchmark overfit | High | Medium | Freeze holdout and prompt-version notes; eval |
| R-08 Overbuilt infrastructure | High | Medium | Minimal Postgres outbox and one agent; owner |
| R-09 Schedule slips | Medium | Medium | Strict P0, cut UI polish/P1 first; owner |
| R-10 Missing observability | Medium | Medium | Trace IDs and audit from first sprint; owner |
| R-11 Leakage in traces | Medium | High | Redact, synthetic fixtures, TTL; security |

## Technical debt policy

Every intentional shortcut needs issue ID, risk, expiry milestone and test gap. Never accept shortcuts on approvals, owner scoping or ledger uniqueness. Defer hybrid search, multi-tenant or real connectors before deferring safety invariants.

## Supabase-specific cost and operational risks

Hosted Supabase plan, database compute, storage, egress, backup/restore, Auth usage and connection limits can affect actual costs. Do not quote a fixed free-tier allowance without checking current plan details. Separate local tests from a modest hosted demo and monitor query/connection usage.

- **R-11** Wrong privilege boundary / broad project DB credentials → keep server-only, RLS deny-all for browser and test tenant ownership; replace with least-privilege role before real data.
- **R-12** Pooler mismatch / prepared statement errors → select direct/session vs transaction mode deliberately and test SQLAlchemy driver config.
- **R-13** Vendor coupling / migration drift → commit Supabase CLI SQL migration history, run local reset in CI, record hosted project deployment target.
