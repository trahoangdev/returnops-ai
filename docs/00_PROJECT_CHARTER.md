# 00 — Project Charter

## Problem

Traditional store support requires agents to repeatedly locate orders, interpret changing return policies, gather evidence, escalate unusual situations and manually document outcomes. A plain LLM cannot safely decide eligibility or trigger refunds on its own, and purely scripted bots struggle with variable customer phrasing. ReturnOps combines natural-language assistance with deterministic policy enforcement and traceable business actions.

## Product vision

"A customer service agent that can explain **why** a return is or is not eligible, prepare the next safe operational action, and leave an audit trail." Focus: a **single fictitious retailer** using VND, `Asia/Ho_Chi_Minh` business dates and Vietnamese-first customer messages.

## Stakeholders and personas

- **Customer:** see eligible options, open a request, provide evidence, get status.
- **Support reviewer:** review prepared case, supporting citations, order facts, proposed simulated refund; approve/reject with reason.
- **Store admin:** publish versioned policies and inspect audit/eval records; cannot bypass transaction checks.
- **AI engineer:** measure policy accuracy, state changes, model latency, costs and failure modes.

## Goal hierarchy

| Goal | KPI (proposed MVP threshold; not measured result) |
|---|---|
| Resolve routine requests correctly | ≥80% end-to-end task success on a curated 100-case set |
| Prevent financial misuse | 0 unauthorized or duplicate mock refunds in adversarial test suite |
| Ground explanations | ≥90% policy citation precision on citation-required cases |
| Control latency | p95 ≤15 seconds per full simulated turn in an agreed test environment (goal, adjust after baseline) |
| Enable review | 100% of mock refunds linked to reviewer and approval record |
| Reproduce quality | fixed dataset, model/prompt versions and seed where supported |

## In scope — MVP

1. Customer demo login / seeded identity; basic customer chat and order lookup.
2. One order item per request; standardized reasons: changed_mind, damaged, wrong_item, other.
3. Read order and item facts from DB; retrieve versioned policy chunks.
4. Collect missing structured fields; run deterministic eligibility engine.
5. Create/read return request, request reviewer approval; approve/reject; simulate refund after approval.
6. Status history, immutable append-only audit events, idempotency safeguards.
7. Evaluation runner, tracing, metrics, Docker local environment and deployed demo.

## Out of scope

Real payment gateway integrations; actual inventory/shipping logistics; multi-currency/tax; multi-tenant SaaS UI; voice; multi-agent negotiation; automatic account creation with real PII; legal or regulatory compliance certification; production SLA; actual Shopify integration. Multi-tenant metadata may exist in schema to ease later extension, but MVP has one tenant.

## Key assumptions

- All store rules in this project are **invented demo policies**, not Vietnam law or marketplace-specific contractual terms.
- Test dataset uses fake customers, addresses, payments and orders only.
- Human reviewer approval is mandatory for **every** mock refund, regardless of amount.
- Data fields for order delivery, item category and request creation have reliable timestamps.
- The demo includes exception/escalation paths, not just happy path.

## Success means

A reviewer can replay the same case, see the exact policy version used, view tool calls and decision evidence, authorize a simulated action, and verify resulting state from the DB. The project must also demonstrate failing safely on prompt injection, concurrency and retry tests.
