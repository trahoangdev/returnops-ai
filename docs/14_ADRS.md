# 14 — Architecture Decision Records (ADRs)

These decisions are **accepted for the design baseline**, not proof of implementation. Revisit via a new ADR with measurements.

## ADR-001 — Single stateful agent, not multi-agent
**Status:** Accepted. **Context:** MVP must reliably handle a bounded returns workflow. **Decision:** One LangGraph workflow with explicit states/read tools and deterministic service gates. **Consequences:** Easier tracing and testing; less role specialization. **Revisit when:** metrics prove multiple independently testable subworkflows are needed.

## ADR-002 — Deterministic eligibility outside LLM
**Status:** Accepted. **Decision:** LLM extracts/converses; Python policy engine computes eligibility against published policy rules. **Why:** Money-affecting decisions need repeatable rules and unit tests. **Tradeoff:** Must maintain mapping between policy prose and machine rules; publishing validation addresses drift.

## ADR-003 — Simulated refund, human approval for all amounts
**Status:** Accepted. **Decision:** All refund effects go to a local `mock_refunds` ledger, after authenticated reviewer approval of exact proposal. **Why:** Avoid financial side effects and unsafe agent autonomy. **Tradeoff:** User flow is slower; represents realistic governance.

## ADR-004 — Supabase-managed PostgreSQL as system of record, pgvector optional
**Status:** Accepted. **Decision:** Orders, policies, audit, mock ledger, outbox and (later) vectors in Supabase PostgreSQL. Start keyword/FTS retrieval; compare vector/hybrid only if justified. **Tradeoff:** Simpler infra, vector search less specialized than dedicated platforms.

## ADR-005 — Order-bound policy version
**Status:** Accepted. **Decision:** Bind published policy effective at purchase time, preserve unchanged historical version for each order. **Why:** Repeatable, auditable behavior. **Tradeoff:** Store versions and indexes across revisions. This is a fictional store product rule, not a legal claim.

## ADR-006 — Database transaction/outbox for mock refunds
**Status:** Accepted. **Decision:** Approval commit emits durable outbox; internal worker transaction validates state and inserts unique ledger row. **Why:** Graph replay and job retries must not duplicate writes. **Tradeoff:** More components than direct sync write.

## ADR-007 — Versioned benchmark and strict DB-state evaluation
**Status:** Accepted. **Decision:** Freeze scenario ground truth, check final DB state, run deterministic + live model suites, trace input/prompt/model/policy versions. **Why:** Plain chat judging misses unauthorized mutations. **Tradeoff:** Additional fixture maintenance.

## ADR-008 — No direct MCP integration in MVP
**Status:** Accepted. **Decision:** Typed in-process/server tools; introduce MCP only after interfaces mature. **Why:** Avoid another trust boundary and complexity. **Revisit:** Need cross-agent/third-party tool interoperability and access policies have been validated.

## ADR-009 — First release only one store/tenant
**Status:** Accepted. **Decision:** One demo store, tenant IDs retained in schema. **Why:** Multi-tenancy security overhead not core to portfolio. **Revisit:** SaaS product interest validated and isolation architecture reviewed.

## ADR-010 — Supabase PostgreSQL, Auth and CLI migrations
**Status:** Accepted in v1.1. **Decision:** Use Supabase-managed PostgreSQL for hosted demo, Supabase CLI local stack for development, SQL migrations under `supabase/migrations`, `@supabase/ssr` for Next.js Auth, FastAPI for all business endpoints. No Alembic history and no second Compose Postgres. **Why:** Managed DB/Auth plus reproducible schema. **Tradeoff:** Vendor-specific local tooling, Auth integration, exposed-schema security obligations.

## ADR-011 — Deny direct business Data API access in MVP
**Status:** Accepted in v1.1. **Decision:** Enable RLS on all public domain tables; revoke anon/authenticated table privileges and create no direct CRUD policies. Frontend only authenticates and calls FastAPI; backend validates Supabase token and uses SQL transactions. **Why:** Centralized server-side business rules and review approvals. **Tradeoff:** No direct Supabase-js CRUD/realtime on business data until separately designed. **Warning:** Privileged server DB connection may bypass RLS; ownership/tenant checks in application remain critical, dedicated DB roles recommended for production.
