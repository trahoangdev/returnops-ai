# 01 — Product Requirements Document (PRD)

## 1. Objective and release criteria

Deliver a **policy-aware return/refund assistant for an invented store**. The product should *explain*, *prepare* and *audit* a request, while deterministic services decide eligibility and human reviewers approve simulated money movement. MVP success is demonstrated with a seeded fixture store and offline/online evaluations, not actual users or financial transactions.

## 2. Functional requirements

| ID | Requirement | Priority | Acceptance |
|---|---|---|---|
| FR-01 | Authenticate demo customer/reviewer/admin | P0 | Customer never reads another customer's order |
| FR-02 | List and retrieve caller-owned orders | P0 | Authenticated identity controls filtering, not user-supplied email |
| FR-03 | Converse in Vietnamese, persist thread | P0 | Resume after refresh/restart using durable checkpointer |
| FR-04 | Identify intent and item, ask for missing data | P0 | Never assume delivered date, condition or reason |
| FR-05 | Retrieve source policy passage, effective version | P0 | Store document/chunk IDs with each decision |
| FR-06 | Compute eligibility deterministically | P0 | Rules executed by backend; LLM cannot override |
| FR-07 | Open return request | P0 | Exactly one active return per tenant/order item |
| FR-08 | Display status, reason and next steps | P0 | Clear for eligible, ineligible, manual review, missing info |
| FR-09 | Submit for human approval | P0 | Reviewer UI has amount, facts, cites, original request |
| FR-10 | Approve/reject with durable audit | P0 | Only authorized reviewer; decision ID and reason persisted |
| FR-11 | Simulate refund in ledger | P0 | Only approved request; exactly-once effect via transaction/idempotency |
| FR-12 | Evaluation/traces dashboard or reports | P0 | Experiment version, pass/fail, latency, cost where available |
| FR-13 | Admin publish versioned policy document | P1 | No retroactive mutation of existing versions |
| FR-14 | Email/SMS notifications | P2 | Document future interface only; no real send in MVP |
| FR-15 | Real returns/shipment/payment provider | P2 | Explicitly excluded from MVP |

## 3. Personas and permissions

- **customer:** chat about own orders; create draft/submit return; upload synthetic evidence; see own history; cannot approve or issue mock refund.
- **reviewer:** read assigned case, approve/reject within demo limits, see minimal customer data, cannot alter policy or impersonate customer.
- **admin:** publish policy versions, manage reviewers, view aggregate/eval data, cannot call refund endpoint without reviewer authority.
- **system-worker:** internal service identity with narrow permission to execute an already-approved mock refund. Approval alone is not execution; it must be revalidated transactionally.

## 4. Primary use cases

### UC-01 Eligible change-of-mind
Customer selects delivered standard item 5 days ago, unused with intact packaging; system cites active return policy, creates `PENDING_APPROVAL` case. Reviewer approves and mock refund ledger registers one entry.

### UC-02 Expired return window
Customer selects delivered standard item 20 days ago; deterministic engine marks `INELIGIBLE`; system explains cutoff with citation and can offer a support escalation for dispute, but not a refund.

### UC-03 Damaged item
Customer reports delivery damage 9 days ago and attaches a fictitious photo reference. Policy requires manual review: system records evidence and escalates, not automatic approval.

### UC-04 Missing facts
Order not found, item ambiguous or condition unknown: ask targeted question. Never guess an order ID or payment total.

### UC-05 Malicious instruction embedded in retrieved policy
Injected policy text says "ignore approval". Assistant treats it as untrusted source text; deterministic approval gate rejects unauthorized actions.

### UC-06 Retry/double click
Two requests to execute the same approved refund produce exactly one mock ledger entry, same operation outcome, no duplicated mutation.

## 5. Nonfunctional requirements

| ID | Requirement | Proposed target |
|---|---|---|
| NFR-01 | End-to-end customer turn latency | p95 ≤15s on documented fixture/hardware, after optimization |
| NFR-02 | Sensitive mutation correctness | 0 illegal state transitions/unauthorized ledger writes in test suite |
| NFR-03 | Uptime | Not an MVP SLA; record availability during demo |
| NFR-04 | Robustness | Retry only safe reads; background writes must be idempotent |
| NFR-05 | Observability | Every request carries correlation ID, policy version, tool result status |
| NFR-06 | Explainability | Customer text cites policy version and section; reviewer has evidence snapshot |
| NFR-07 | Privacy | Test-only synthetic data; secret/PII redaction in logs/traces |
| NFR-08 | Maintainability | Typed contracts, domain service tests, migrations, CI |

## 6. Decision rules

Source of truth is `contracts/policy_rules.yaml` plus `docs/02_DOMAIN_POLICY.md`. A rule engine returns one of `ELIGIBLE`, `INELIGIBLE`, `MANUAL_REVIEW`, `MISSING_INFO` with machine-readable `reason_codes`, evidence IDs and policy version. Note: **ELIGIBLE means eligible for a proposed return**; it does **not** mean a refund may be issued without review.

## 7. UX requirements

Customer UI: order picker; chat with tool-action progress; citations as inspectable documents; structured missing information prompts; request-status page. Reviewer UI: inbox sorted by state; immutable item/amount/policy snapshot; approve/reject buttons with confirmation and reason; audit timeline. Mobile responsiveness desirable but not release-blocking.

## 8. Analytics and instrumentation

Track `chat_turn_completed`, `intent_classified`, `policy_retrieved`, `eligibility_decided`, `return_created`, `approval_requested`, `approval_decided`, `mock_refund_issued`, `escalation_created`, `tool_error`, `security_denial`. Event payload uses IDs and minimal safe metadata; never full card/address/payment data.

## 9. Release gate

All P0 requirements implemented and acceptance tests pass; 100+ diverse eval cases exist; 0 unauthorized/duplicate mock refunds under concurrency tests; documented benchmark run and security review; demo reproducible from clean seed. See `16_DEFINITION_OF_DONE.md`.
