# 13 — DevOps, Runbook & Supabase Local Development Plan (v1.1)

**Status:** blueprint only. The package contains contracts/examples, not a deployed Supabase project, a runnable FastAPI app or an already-executed migration.

## Prerequisites

- Python 3.12+, Node.js LTS, pnpm, Docker-compatible runtime.
- Supabase CLI (check installed version and `supabase --help` before commands); Supabase project for hosted demo.
- Optional `uv`, model API key, observability credentials. Pin exact versions/lockfiles during implementation.

## Local architecture

Use **Supabase CLI** for local Postgres/Auth/Studio. Run FastAPI, Next.js and optional refund worker as separate processes or via Compose that **does not** start another Postgres container. Database migrations are SQL files under `supabase/migrations`; do not run Alembic independently.

## Expected environment variables

See [`../examples/.env.supabase.example`](../examples/.env.supabase.example). Local/hosted Supabase URLs/credentials must be read from `supabase status` or the project's dashboard **Connect** panel and not guessed. `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` is intentionally public; all other secrets stay server-only. FastAPI must use a database connection string kept private and a validated Supabase Auth API/JWT verification path. `REFUND_MODE=simulation_only` is mandatory.

## Bootstrap workflow (commands are targets, NOT executed here)

```bash
# In the application repository, after installing a current Supabase CLI:
supabase --version
supabase init
supabase start
supabase status
supabase migration new init_returnops
# Copy reviewed schema SQL then contracts/supabase_rls.sql into the GENERATED migration.
# Implement repeatable seed/bootstrap for fictional data; never seed auth.users manually.
supabase db reset --local           # destructive local reset; does NOT target hosted demo
# In separate terminals once app is implemented: start FastAPI, Next.js, worker.
```

When deploying a project later, review the diff/migration against the linked **development** Supabase project, use `supabase db push --linked` only with explicit verification and an approved deploy procedure. Never run destructive reset against hosted data.

## Identity fixtures

Use Supabase Auth to create **fictional** demo identities (`customer-a`, `customer-b`, `reviewer-1`, `admin-1`) through a secure, local-only bootstrap routine. Seed domain `users` rows from `contracts/seed_data.json`, then bind `users.auth_user_id` to actual Auth user UUIDs. No fixed real credentials or sensitive test accounts in Git. Unbound fixture users are denied access.

## Connection selection

- Persistent FastAPI server: direct connection if IPv6/network permits, or Supavisor **session pooler** on IPv4-only networks. Store URL only on API/worker server; bound SQL parameters and short transactions.
- Serverless: transaction pooler may be appropriate but lacks support for prepared statements; test driver/config explicitly before use.
- Separate SQLAlchemy connection pools should have conservative sizes; load-test before tuning. Never use a browser-facing DB connection string.
- A privileged initial DB connection is tolerated ONLY for synthetic isolated demo; migrate to dedicated narrowly scoped DB role and stronger RLS design before real traffic or sensitive data.

## Operational health checks

- `/healthz`: liveness without exposing secrets.
- `/readyz`: Supabase Postgres connectivity, expected migration version and applicable published policy.
- Auth health: no exposed credential, log verification failures without storing bearer tokens.
- Outbox monitor: pending age, retries, fail counts, duplicate ledger invariant.
- Agent metrics: trace IDs, success rate, latency, tokens, redacted tool errors.

## Failure response

- **Supabase Auth unreachable:** fail closed on privileged requests; never fall back to trusting decoded JWT claims.
- **Postgres unreachable:** return retryable 503; no optimistic "refund created" success.
- **RLS/Data API test fails:** freeze deploy, deny API access, inspect table grants and policies.
- **Wrong database branch or project:** stop writes, check connection config and linked Supabase project before migration.
- **Worker retries:** unique `(tenant_id,return_request_id)` mock ledger plus DB locks and idempotency must prevent duplicates.

## Backup/security/deploy

Maintain separate local/dev/production Supabase projects. Use dashboard-managed backups appropriate to plan and test restoring synthetic data. Never expose the CLI dev stack publicly. Track schema migration history, immutable policy version and git SHA per demo release. Before opening demo to visitors, run database RLS/grants tests, API ownership tests and refund-race tests. See security checklist and [Supabase Implementation](21_SUPABASE_IMPLEMENTATION.md).
