# 17 — Implementation Brief for a Coding Agent

> Paste this into a coding assistant **after** placing the full docs package in your new repository. It is a specification, not an instruction to skip code review or testing.

## Mission

Implement ReturnOps AI MVP **incrementally** in a monorepo following README and docs. Focus on API/domain correctness, security and evaluations before UI polish. All customers/orders/policies are synthetic; refunds are a **local database simulation only**.

## Read before coding

1. `docs/02_DOMAIN_POLICY.md` and `contracts/policy_rules.yaml` for authoritative demo rules.
2. `docs/04_ARCHITECTURE.md`, `docs/05_AGENT_AND_TOOLS.md`, `docs/07_DATA_MODEL.md` for boundaries.
3. `contracts/openapi.yaml`, `contracts/db_schema.sql`, `contracts/supabase_rls.sql` and `docs/21_SUPABASE_IMPLEMENTATION.md` for contracts and Supabase security.
4. `docs/09_SECURITY_PRIVACY.md`, `docs/10_EVALUATION.md`, `docs/11_TEST_STRATEGY.md` for gates.
5. `docs/12_ROADMAP_BACKLOG.md` for scope and ticket ordering.

## Hard instructions

- Never connect payment/refund APIs or issue real money; simulated ledger only.
- Never allow LLM generated action or client supplied `approved=true` to authorize mock refund.
- Verify Supabase access tokens using Supabase Auth; map `sub` to active `users.auth_user_id`, then derive tenant and application role from DB, not JWT `role`/user metadata.
- Browser has only the publishable key; all domain reads/writes via FastAPI. Enable deny-by-default RLS on every exposed public table; never expose service keys or Postgres URL to browser.
- Use Supabase CLI SQL migrations, not Alembic. Supabase local stack replaces custom Postgres container.
- Keep policies versioned and compute eligibility via pure deterministic function.
- Require reviewer approval with immutable exact proposal hash and amount before ledger insert.
- Use transactions, unique constraints and idempotency for return/refund writes.
- Every external side effect must be replay safe; LangGraph checkpoints are not the business DB.
- Add tests before claiming a ticket complete; never change expected evaluation outcomes to fit implementation.
- Do not invent SDK functions: read local installed package docs and pin versions in lockfiles.
- No plaintext secrets/PII in git or telemetry.

## Suggested order of work

**PR 1** `RO-001`: scaffold Python API, Supabase CLI local stack/Auth/Postgres+pgvector, SQL migrations, deny-all public RLS, `/healthz`, unit tests.  
**PR 2** `RO-002/RO-003`: pure rules, Supabase Auth login + token validation, domain user binding, scoped fixtures, SQLAlchemy/typed schemas; test time edges and ownership.  
**PR 3** `RO-005/RO-006`: policy version retrieval, return state machine/idempotency, deterministic endpoint acceptance.  
**PR 4** `RO-007`: LangGraph tool-using conversation + durable checkpointer and strict read-only tools.  
**PR 5** `RO-008/RO-009`: reviewer approval + outbox + simulated ledger with concurrent tests.  
**PR 6** UI, evals, telemetry and CI.  

For each PR: identify acceptance criteria; update OpenAPI/schema if changed; write automated tests; run linter/types/tests; summarize actual verified results and remaining limitations. Stop and report if a safety invariant cannot be maintained.

## Initial repository structure

```text
apps/web/src/app/
services/api/app/main.py
services/api/app/{api,auth,models,schemas,domain,policy,agent,retrieval,tools,db}/
supabase/migrations/  # only DB migration authority
services/api/tests/{unit,integration,api,security}/
evals/{datasets,runner,reports}/
infra/{optional_app_compose,observability}/
docs/ contracts/ assets/
```

## Done per issue

A ticket is complete only when implementation, targeted automated tests, failure-path checks and docs are updated. Do not say "implemented" for pseudocode, untested placeholders or design-only artifacts.
