# 12 — Delivery Roadmap & Ticket Backlog

**Assumption:** solo developer 12–15 h/week for 6 weeks. Dates are relative; adjust capacity. Estimate: 72–90 total hours, optimistic if already comfortable with Python/FastAPI/Supabase PostgreSQL/React. Reserve 20% contingency. Priority codes: P0 must; P1 desirable; P2 later.

## Sprint plan

| Week | Milestone | Demo exit criteria |
|---|---|---|
| W1 | Foundation + policy domain | Seeded orders, API auth scope and unit-tested pure policy engine |
| W2 | API + workflow shell | Owner-scoped orders, return case CRUD, status transitions, customer UI |
| W3 | Agent + grounded policies | LangGraph read-only tools, retrieval, citations, clarification |
| W4 | Reviewer approval + simulated ledger | Strict approval/money invariants, durable worker/outbox, test races |
| W5 | Quality/security/observability | 100-case eval target built out, traces, injection + auth tests |
| W6 | Deployment, benchmark and portfolio | Reproducible demo, benchmark report, architecture video, README |

## Dependency graph

`RO-001 → RO-002 → RO-003 → RO-006 → RO-009`; `RO-001 → RO-004 → RO-005`; `RO-003 + RO-005 → RO-007 → RO-008`; `RO-007 + RO-009 → RO-010`; `RO-010 → RO-011 → RO-012`. Security tests start W1 and remain cross-cutting.

## P0 tickets (paste directly into GitHub Issues)

| Ticket | Work | Estimate | Acceptance criteria |
|---|---|---:|---|
| RO-001 | Monorepo scaffold, Supabase CLI/Auth/Postgres, FastAPI, migrations, health endpoint | 5h | `supabase start`/`db reset --local` work; `/healthz` 200; tables RLS hardened |
| RO-002 | Pure policy evaluator, time-zone rules, category, amount ceiling | 8h | POL-001…POL-008 green, no LLM calls |
| RO-003 | Auth user bootstrap, scoped read-order APIs, role-based auth | 6h | Supabase token mapped to app role; cross-user 404; fixtures work |
| RO-004 | Customer order/chat UI and return submission form | 7h | Order picker/chat/return status flows functional |
| RO-005 | Versioned policy model, Markdown ingest, citations | 5h | Query returns correct `POL-2026-001` rule IDs |
| RO-006 | Domain return case service + lifecycle + idempotency | 8h | exactly one active case/item, safe replay/conflict |
| RO-007 | LangGraph orchestrator + tools + durable checkpoints | 10h | clarification & valid proposal; restart resumes |
| RO-008 | Reviewer inbox, approval/rejection, proposal hash | 7h | role checks + stale proposal denial |
| RO-009 | Mock refund outbox/worker + concurrency transaction | 8h | two retries produce one ledger entry |
| RO-010 | Eval runner, dataset growth to 100, experiment reports | 10h | strict DB-state grader, per-case trace IDs |
| RO-011 | Security, logging, rate limiting, tool budgets, CI | 8h | adversarial tests green; traces scrubbed |
| RO-012 | Deploy synthetic demo, README + 3–5m walkthrough | 6h | clean setup and reproducible benchmark attached |

**Estimates are planning hypotheses**, not guarantees. Total ≈88 hours; reduce UI polish / P1 features if schedule slips, never delete approval and idempotency controls.

## P1 backlog

- RO-101: Hybrid retrieval and reranker experiment with Recall@3 comparison.
- RO-102: Admin policy publishing with semantic diff and publication validation.
- RO-103: Dashboard for approval turnaround, latency, costs and rubric failures.
- RO-104: SSE chat progress, cancellation and user-friendly retries.
- RO-105: Attach fake image evidence and reviewer preview.

## P2 backlog

- RO-201: Multi-tenant direct-access RLS policy design and granular DB roles (deny-by-default RLS in MVP).
- RO-202: External commerce connector via sandbox (no real money).
- RO-203: Multilingual support and voice.
- RO-204: Partial refunds, shipping and coupon proration.
- RO-205: Human feedback → curated dataset workflow.

## Example issue template

**Title:** RO-002 — Deterministic eligibility evaluator  
**Motivation:** Financial/eligibility decisions cannot depend on model prose.  
**Scope:** Implement pure `evaluate(order_item, reason, condition, evidence_refs, submitted_at, policy)` returning decision, reason codes, proposed amount and citations.  
**Acceptance:** day14 eligible/day15 denied, excluded categories denied, damage evidence manual, negative date escalated, amount >5m blocked, 100% rule-unit tests.  
**Not in scope:** LLM integration, real payment service.

## Weekly management ritual

Monday: pick P0 tickets with dependencies satisfied; midweek: run deterministic tests + inspect latest traces; end-of-week: record a 1-minute demo, update risk register and eval baseline. Report blockers without silently changing functional scope.
