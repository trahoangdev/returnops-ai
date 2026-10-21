# 03 — User Stories, Jobs To Be Done & UX

## Jobs to be done

- Customer: "When I need to return an order item, tell me exactly what information is missing and what happens next."
- Reviewer: "When a case arrives, show policy justification, original order facts, amount and risk flags; let me safely approve or reject."
- Engineer: "When a case fails, let me replay inputs and inspect tool, policy and state transitions."

## Core stories and acceptance

**US-01** As a customer, I can select my own order. **Given** a seeded customer, **when** I open the order picker, **then** only owned orders appear. Direct guessing another order ID returns `404` (avoid enumeration).  
**US-02** As a customer, I can describe a return in Vietnamese. Assistant parses reason and selects an item, but confirms ambiguous references.  
**US-03** As a customer, I see factual policy citation. Each policy-based answer points to a policy version + section, or says it cannot verify.  
**US-04** As a customer, I can submit required facts. UI collects reason, condition, packaging condition, item, evidence reference where required; no hidden assumptions.  
**US-05** As a customer, I can see my request status. Server status always wins over free-form LLM message.  
**US-06** As a reviewer, I see exact proposed VND amount and approval reason; approving requires a confirmation click and reason.  
**US-07** As a reviewer, I can reject a case. Rejection records who, when and why; cannot silently write refund.  
**US-08** As an engineer, I can open the trace by request/correlation ID and inspect masked tool spans.

## Screens

1. `/login` — local demo persona login (seeded account; warn DEMO / NOT FOR MONEY).
2. `/orders` — customer-owned orders, delivered date and line items.
3. `/chat?order_id=...` — persistent thread, chat bubbles, referenced policy cards, structured clarifying prompts, status chip.
4. `/returns/:id` — request status, dates, policy snippet, timeline; never show reviewer secrets.
5. `/review` — reviewer inbox; search/filter by `PENDING_APPROVAL`, `MANUAL_REVIEW`, `ESCALATED`.
6. `/review/:id` — frozen proposal, original data, policy evidence, conflict flags; approve/reject with confirmation.
7. `/admin/policies` (P1) — draft/publish policy versions, diff, effective interval.
8. `/dev/evals` (optional) — report summaries and trace links.

## Happy path

Customer chooses delivered order item → types "Tôi muốn trả hàng, chưa dùng" → read order → retrieve policy → decision `ELIGIBLE` → confirm summary → create return `PENDING_APPROVAL` → reviewer approves → worker creates mock refund `REFUNDED` → customer sees simulated status.

## Failure UX

- Unknown order: "Mình chưa tìm thấy đơn hàng trong tài khoản này. Bạn có thể chọn từ danh sách đơn hàng của mình."
- Missing condition: ask one specific question, not an invented answer.
- Policy source unavailable: "Chưa thể xác minh chính sách cho đơn này; mình sẽ chuyển nhân viên."
- Denied: explain which rule and date, no blame or false guarantee.
- Approval pending: never say "tiền đã hoàn".
- Retry: show consistent prior outcome; no second refund.
- Tool failure: show a retryable status and correlation ID; never expose traceback.

## Accessibility / internationalization

Use keyboard navigation, semantic controls, text alternatives and accessible status changes. Vietnamese-first; English internal enums. Localize monetary amount as `1.250.000 ₫`, store integer minor arithmetic (VND integers); localize timestamps to HCMC in UI, persist UTC instants in DB.

## Demo realism

Seed a handful of orders covering: exactly day 14, day 15, damaged with evidence, missing evidence, excluded category, item amount >5m, already refunded, and unknown policy version. Never seed real people or personal data.
