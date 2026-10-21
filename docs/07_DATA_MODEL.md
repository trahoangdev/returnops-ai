# 07 — Data Model & Transaction Design

Canonical draft schema: [`../contracts/db_schema.sql`](../contracts/db_schema.sql). Convert the draft into **Supabase CLI SQL migrations** (`supabase/migrations/`); do **not** also use Alembic. Apply `contracts/supabase_rls.sql` as part of your reviewed initial migration and validate locally.

## Entities

| Entity | Important fields | Invariants |
|---|---|---|
| `tenants` | id, slug | One demo tenant for MVP |
| `users` | tenant_id, id, `auth_user_id` → `auth.users.id`, role, demo_subject | Auth ID maps to one active application user; DB role is authoritative |
| `orders` | tenant_id, customer_id, placed_at, policy_version_id | Customer owns order; policy bound at checkout |
| `order_items` | order_id, category, status, paid_amount_vnd, delivered_at | Authoritative prices; VND integer |
| `policy_versions` | id, effective dates, status, content_hash | Published versions immutable |
| `policy_chunks` | policy_version_id, rule_id, text, embedding | Typed rule citations and RAG metadata |
| `conversations` | customer_id, graph_thread_id | Customer-scope durable thread |
| `messages` | conversation_id, role, body | Redaction; retention policy |
| `return_requests` | order_item_id, reason, evidence, status, proposed_amount, proposal_hash, version | At most one active request per item |
| `approvals` | return_request_id, reviewer_id, decision, proposal_hash | Immutable reviewer authority record |
| `mock_refunds` | return_request_id, amount_vnd, idempotency_key | Exactly one per request; simulated ledger |
| `idempotency_records` | tenant_id, operation, key, request_hash, response | Repeat-safe client/worker calls |
| `audit_events` | actor, action, target, previous/new, trace_id | Append-only audit; redact PII |
| `outbox_events` | aggregate_id, event_type, status, attempts | Durable internal execution after approval |

## Logical relationships

- `users 1—N orders`, `orders 1—N order_items`.
- `orders N—1 policy_versions`; `policy_versions 1—N policy_chunks`.
- `order_items 1—N return_requests` over history, only one **active** at a time.
- `return_requests 1—N approvals` (normally one final decision; corrections via new revisions and audit).
- `return_requests 0..1 mock_refunds`.
- `users 1—N conversations`, `conversations 1—N messages`.

## Return status model

`DRAFT → NEEDS_INFO → PENDING_APPROVAL → APPROVED → REFUND_PENDING → REFUNDED`; alternatives `INELIGIBLE`, `MANUAL_REVIEW`, `REJECTED`, `ESCALATED`, `CANCELED`. `REFUNDED`, `REJECTED`, `CANCELED` are terminal for MVP. Do not allow `REJECTED → REFUNDED` or `REFUNDED → APPROVED`.

For `MANUAL_REVIEW`, MVP records a reviewer handoff/escalation only; it does not convert damage claims directly to refundable cases. A later extension may add an explicit manual-verdict workflow with new proposal and separate authenticated approval. For MVP, approval is not a route around `R-008`–`R-012`.

## Money calculations

Use integer `paid_amount_vnd` on order item. `proposed_amount_vnd` is a snapshot of authorized item amount (`0..5_000_000`) and is never user/LLM supplied. Future partial refunds or currency conversion require a separate ADR and invariant tests. A `mock_refunds` row demonstrates a state transition in a **fake ledger only**.

## Source-of-truth and audit

`return_requests.status` and `mock_refunds` are business truth. LangGraph state may lag but cannot override them. Audit records are append-only; use transaction together with writes. Every mutation records `actor_type`, `actor_id`, `trace_id`, `reason_code`, `created_at`, and non-sensitive old/new state.

## Transaction pseudocode — mock refund

```text
BEGIN
  SELECT return_request FOR UPDATE
  assert status in {APPROVED, REFUND_PENDING}
  assert approved decision exists for exact proposal_hash and amount
  assert item paid_amount matches approved amount and amount <= 5_000_000
  assert no mock_refunds row for request
  INSERT mock_refunds(return_request_id UNIQUE, ...)
  UPDATE return_requests SET status='REFUNDED', version=version+1
  INSERT audit_events(...)
  UPDATE outbox_events SET status='DONE'
COMMIT
```

Duplicate execution: return existing ledger result, **not** another insert. If same idempotency key arrives with different body/hash, error `409`.

## Data lifecycle

Use only fictional data. Default design retention: chat 30 days, traces 14 days, demo audit 90 days, eval artifacts versioned and scrubbed (proposed values subject to final hosting policy). Add account/data deletion workflow before real users. Never store passwords in plaintext, bearer tokens, real addresses or payment card information.

## Supabase identity mapping and lifecycle

`public.users.id` stays a domain UUID used by existing foreign keys. The nullable `public.users.auth_user_id` maps one-to-one to `auth.users.id`; it is null only for fixtures until secure bootstrap binds a Supabase Auth user. Production-authenticated requests **reject** null mapping and inactive users. Never treat `demo_subject` (fixture label) as an authenticated token subject.

The `auth.users` record is managed by Supabase Auth, not inserted directly into application seed SQL. Create demo Auth users via a dedicated local-only bootstrap flow or Supabase Admin API from secure server tooling; then bind `users.auth_user_id`. Never commit demo passwords or real user IDs/secrets. If an Auth account is deleted, the mapping becomes null and the user cannot authorize any request.

All MVP business tables live in `public` but are locked down from the Data API: enable RLS, revoke direct `anon`/`authenticated` privileges, create **no direct CRUD policies**. FastAPI owns authorization and DB transactions through a protected connection. This is not a substitute for least-privilege Postgres roles when expanding beyond synthetic data.
