# ReturnOps AI — Engineering Blueprint v1.1 · Supabase Edition

> **Status:** design baseline / implementation-ready documentation, **not an implemented application**.  
> **Updated:** 2026-10-22 · **Language:** Vietnamese (engineering names in English)  
> **Audience:** solo builder or 2–3 person engineering team · **Suggested time:** 6 weeks / 12–15h per week

## Project summary

ReturnOps AI is a **policy-aware returns and simulated refund agent** for a fictional Vietnamese e-commerce store. A customer submits a return/refund request, the assistant retrieves the order and relevant policy evidence, gathers missing facts, proposes an auditable outcome, and creates a return request. **All refund issuance requires explicit review approval and is simulated in a local ledger: no real money movement.**

The database is **Supabase managed PostgreSQL** (locally: Supabase CLI); identity uses **Supabase Auth** while FastAPI exclusively owns business mutations. The LLM handles conversation, classification and policy explanation. Deterministic services own eligibility, authorization, status transitions, financial limits, and database writes. This is an AI Engineering project (agent + RAG + backend + reliability), not a generic chat-with-PDF demo.

## Quick navigation (recommended reading order)

| Order | Document | Purpose |
|---|---|---|
| 1 | [Project Charter](docs/00_PROJECT_CHARTER.md) | Goals, scope, measurable outcomes |
| 2 | [PRD](docs/01_PRD.md) | Product requirements and acceptance |
| 3 | [Policy & Domain Rules](docs/02_DOMAIN_POLICY.md) | Fictional store rules; source of truth |
| 4 | [UX & User Stories](docs/03_USER_STORIES_AND_UX.md) | Personas, flows and screens |
| 5 | [System Architecture](docs/04_ARCHITECTURE.md) | Boundaries, diagrams, components |
| 6 | [Agent & Tool Contracts](docs/05_AGENT_AND_TOOLS.md) | State machine, function contracts, approvals |
| 7 | [Knowledge/RAG](docs/06_RAG_AND_KNOWLEDGE.md) | Indexing, retrieval, citations |
| 8 | [Data Model](docs/07_DATA_MODEL.md) | Tables, constraints, transaction patterns |
| 9 | [API Contract](docs/08_API_CONTRACT.md) | Routes, example requests and errors |
| 10 | [Security](docs/09_SECURITY_PRIVACY.md) | Threats, auth, injection, retention |
| 11 | [Evaluation Plan](docs/10_EVALUATION.md) | Metrics, datasets, baselines and gates |
| 12 | [Test Strategy](docs/11_TEST_STRATEGY.md) | Unit/integration/e2e/security |
| 13 | [Roadmap & Backlog](docs/12_ROADMAP_BACKLOG.md) | 6 sprints, tickets and dependencies |
| 14 | [Operations](docs/13_DEVOPS_RUNBOOK.md) | Environments, setup, monitoring, incidents |
| 15 | [ADRs](docs/14_ADRS.md) | Architecture decisions & alternatives |
| 16 | [Cost/Risks](docs/15_COST_AND_RISKS.md) | Budget assumptions, mitigations |
| 17 | [Definition of Done](docs/16_DEFINITION_OF_DONE.md) | Release/portfolio checklist |
| 18 | [Coding-Agent Brief](docs/17_AGENT_IMPLEMENTATION_BRIEF.md) | Paste as build instructions to an AI coding agent |
| 19 | [Demo Script](docs/18_DEMO_SCRIPT.md) | Portfolio presentation |
| 20 | [Sources](docs/19_REFERENCES.md) | Official references and caveats |
| 21 | [Implementation Recipes](docs/20_IMPLEMENTATION_RECIPES.md) | Pure rules and transactional pseudocode |
| 22 | [Supabase Implementation](docs/21_SUPABASE_IMPLEMENTATION.md) | Supabase Postgres, Auth, RLS and CLI workflow |

## Machine-readable starting contracts

- [`contracts/openapi.yaml`](contracts/openapi.yaml) — curated OpenAPI 3.1 surface for MVP.
- [`contracts/db_schema.sql`](contracts/db_schema.sql) — **reference schema draft** for Supabase PostgreSQL (not a deploy-ready migration).
- [`contracts/supabase_rls.sql`](contracts/supabase_rls.sql) — reference RLS/GRANT hardening for the exposed `public` schema; migrate and verify locally.
- [`examples/.env.supabase.example`](examples/.env.supabase.example) — Supabase configuration placeholders (no real credentials).
- [`docs/21_SUPABASE_IMPLEMENTATION.md`](docs/21_SUPABASE_IMPLEMENTATION.md) — complete connection, Auth, RLS, migrations, testing and deployment decisions.
- [`contracts/policy_rules.yaml`](contracts/policy_rules.yaml) — **synthetic**, deterministic policy configuration.
- [`knowledge/POL-2026-001.md`](knowledge/POL-2026-001.md) — matching published policy text for RAG and citations.
- [`contracts/eval_cases.jsonl`](contracts/eval_cases.jsonl) — initial deterministic scenario seeds; expand to ≥100 unique scenarios.
- [`contracts/seed_data.json`](contracts/seed_data.json) — fictional test fixtures, not real customer data.
- [`assets/architecture.mmd`](assets/architecture.mmd), [`assets/state_machine.mmd`](assets/state_machine.mmd) — Mermaid source diagrams.
- `templates/` — suggested pull-request and issue descriptions.
- [`examples/agent_instructions.md`](examples/agent_instructions.md) — draft bounded agent instruction, requires adaptation and testing.

## Supabase-specific boundary

Browser/Next.js uses the Supabase **publishable** key for sign-in only; sends the access token to FastAPI. FastAPI validates the token with Supabase Auth and maps `auth.users.id` to the application `users.auth_user_id`; the application role is taken from `users.role`, **not** the JWT `role=authenticated` or editable user metadata. All order/refund/approval CRUD is via FastAPI using a **server-only** SQL connection. No direct Data API access to ReturnOps business tables; enable RLS and deny `anon`/`authenticated` privileges on all exposed tables. This intentionally does **not** implement browser-to-database policies. See [Supabase implementation](docs/21_SUPABASE_IMPLEMENTATION.md).

## Non-negotiable architectural invariants

1. **No live refunds/payments**. `mock_refunds` is an internal simulated ledger.
2. A model output **never directly authorizes a write**. Only backend policy/permission checks do.
3. **Every mock refund requires a human reviewer approval** linked to an immutable proposed amount and order item.
4. Caller identity comes from a verified session/token, **never from a field generated by the LLM**.
5. Idempotency keys, database constraints and transaction boundaries stop duplicate operations.
6. Customer-visible policy claims need citations to versioned source chunks; ambiguous facts trigger clarification or escalation.
7. Evaluations must check **actual final database state**, not just chat text.

## Implementation sequence

**Phase A (weeks 1–2):** FastAPI + Supabase local PostgreSQL/Auth + deterministic policy evaluator + synthetic order data + basic UI.  
**Phase B (weeks 3–4):** LangGraph conversation, policy retrieval, checkpoint/approval integration, 30+ evals.  
**Phase C (weeks 5–6):** security hardening, 100+ evals, traces, CI/CD, benchmark report, demo.

Do not paste random current SDK snippets blindly: pin and verify dependency versions before implementation. Model/provider credentials and nontrivial infra are optional for early unit tests (use deterministic fake adapters).

## Suggested repo layout when coding begins

```text
returnops-ai/
  apps/web/                     # Next.js customer + reviewer UIs
  services/api/app/
    api/ auth/ domain/ policies/ agent/ retrieval/ tools/ persistence/
  services/api/tests/           # unit, integration, security, agent
  supabase/                     # CLI-generated config, SQL migrations, seed.sql
  infra/                        # optional API/web compose, telemetry
  evals/                        # datasets, runner, reports
  docs/ contracts/ assets/
  .github/workflows/
```

## First implementation ticket

Begin with `RO-001` in [the backlog](docs/12_ROADMAP_BACKLOG.md): initialize FastAPI, Supabase CLI local stack and versioned Supabase SQL migrations; implement `healthz`; then `RO-002` to implement a pure, deterministic policy evaluator. Do **not** start by writing a giant agent prompt.

## External dependency note

The tau2-bench retail domain can inspire *evaluation design*; its schemas and policy should **not** silently become ReturnOps's own fictional policy. Verify all third-party licenses and model-provider data handling before redistribution/commercial use.
