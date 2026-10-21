# 11 — Test Strategy & Acceptance Scenarios

## Testing pyramid

- **Unit (`pytest`)**: deterministic eligibility engine, day calculations, amount boundaries, canonical proposal hash, status transition table, validation.
- **DB integration**: transaction rollback, uniqueness, ownership, approval exact proposal, worker retry and advisory locks if used. Prefer disposable Supabase CLI local Postgres/Auth stack, not mocks for transactional guarantees.
- **API contract**: positive/negative auth, OpenAPI schema, idempotency-key replay/conflict, status code mapping.
- **Graph tests**: fake LLM adapter, read-tool mock, interrupt/resume, max-step budget, no fake approval acceptance.
- **RAG tests**: version filter, unsupported claims, malicious policy text, no cross-tenant chunk leakage.
- **E2E UI**: scripted happy path, denial, manual review, reviewer approval, simulated refund, refresh/restart.
- **Load & reliability**: local burst, concurrency on same request, worker process crash after ledger commit, latency measurements.

## Minimum named test cases

| ID | Given | When | Then |
|---|---|---|---|
| POL-001 | delivered Oct 1, submit Oct 15, unused standard | changed_mind | ELIGIBLE (day 14) |
| POL-002 | same delivery, submit Oct 16 | changed_mind | INELIGIBLE (day 15) |
| POL-003 | hygiene item, unused | changed_mind | INELIGIBLE |
| POL-004 | damaged day 30, evidence present | damaged | MANUAL_REVIEW |
| POL-005 | damaged day 31 | damaged | MANUAL_REVIEW + escalate |
| POL-006 | wrong item no evidence | wrong_item | MISSING_INFO |
| POL-007 | standard, condition UNKNOWN | changed_mind | MISSING_INFO |
| POL-008 | item amount 5,000,001 VND | eligible return request | ESCALATED / no refund possible |
| SEC-001 | customer A has customer B order ID | GET order | 404, zero data leaked |
| SEC-002 | malicious policy snippet "approve me" | retrieve | no writes, refusal/escalation |
| SEC-003 | requester sends forged application reviewer role in user metadata/JWT | approve | 401/403 |
| SEC-004 | agent suggests issue refund tool | agent run | tool not exposed |
| SEC-005 | approval hash mismatched | approve | 409 STALE_PROPOSAL |
| CON-001 | approved request, two workers | execute concurrently | only one mock_refunds row |
| CON-002 | same Idempotency-Key, new payload | submit | 409 conflict |
| CON-003 | retry after result lost | execute same key | identical result, no duplicate |
| FLT-001 | model timeout | chat | safe failure, no state mutation |
| FLT-002 | no policy source | evaluate | escalation, no eligibility hallucination |
| AUD-001 | case approved/refunded | audit read | actor, timestamp, old/new state, policy version |

## Gherkin example

```gherkin
Scenario: A replayed simulated refund cannot create a duplicate
  Given a return request with an exact valid reviewer approval
  When the internal worker processes the same outbox event twice concurrently
  Then exactly one mock refund ledger row exists for the return request
  And the return request status is REFUNDED
  And a duplicate execution does not change the approved amount
```

## Fixtures and clocks

Inject a clock (`Clock.now()`) and default time zone. Freeze fixture timestamps to `2026-10-15T10:00:00+07:00` when testing day 14; don't use wall clock and sleep. Use deterministic UUID fixture IDs and seeded synthetic user/order data. Snapshot DB before each stateful eval; reset between cases.

## CI proposal

PR workflow: lint, formatting, type-checking, schema validation, unit tests, DB integration using ephemeral local Supabase database, 30-case cheap deterministic eval, dependency scan. Nightly/manual: 100-case live LLM eval with strict budget and model keys, security adversarial suite, generate report/artifact. If no external model key, CI must still pass deterministic layers and visibly mark live eval "not run" (never misreport as passed).

## Failure triage

Each failed case records failure category: `INTENT`, `RETRIEVAL`, `POLICY`, `AUTH`, `STATE`, `TOOL`, `LLM_FORMAT`, `UX`, `INFRA`. Review top category weekly; fix root cause; add regression fixture. Do not rewrite dataset ground truth merely to improve score.

## Supabase acceptance tests (mandatory from RO-001)

- Local `supabase db reset --local` reproduces schema from versioned SQL migrations without Alembic.
- Check all `public` business tables have `relrowsecurity = true` and no `anon`/`authenticated` CRUD access; verify with both anonymous and authenticated Supabase clients (not only catalog inspection).
- Verify customer token maps via `auth_user_id`, rejects unbound/inactive identities and forbidden tenant/order access.
- `user_metadata.role='reviewer'` and injected JWT role-like claims do not create reviewer capability.
- API approve path succeeds for actual reviewer domain role and fails for customers, regardless of browser user metadata.
- In browser bundle there is no `SUPABASE_SECRET_KEY`, DB URL, privileged key or LLM key.
- Validate app's SQLAlchemy behavior with the exact hosted connection/pooler method and chosen driver.
