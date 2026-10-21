# 02 — Domain & Demo Policy (fictional)

**Important:** These policies are **made up for the ReturnOps demo**. They are **not legal advice**, not a claim about actual retailers, and should not be used on real payments. Machine-readable version: `../contracts/policy_rules.yaml`.

## Store context

Store `demo-vn` sells standard goods, hygiene products, custom items and digital goods. Currency: VND (integer, no floating-point arithmetic). Time zone: `Asia/Ho_Chi_Minh`; store business-day calculations use local **calendar dates**.

## Versioning

- `POL-2026-001`, `effective_from: 2026-01-01T00:00:00+07:00`, `effective_to: null` in baseline fixtures.
- At order checkout, bind `policy_version_id` to the applicable published policy. For that order/return, preserve the **purchase-time policy version** and **delivery-time timestamps**. Later policy releases cannot silently change a historical request.
- The rule engine reads only published versions; a draft cannot authorize actions. Document retrieval filters by the bound version and store.
- Editing an existing published version is forbidden. Publish a new version with a non-overlapping effective interval.

## Rules — standard items

**R-001:** Order item must be in `DELIVERED` state. If shipped but not delivered: `MISSING_INFO`/wait, not approval.  
**R-002:** For a normal `changed_mind` request, elapsed local calendar dates between `delivered_at` and **request submission** must be `0..14`, inclusive. Day 14 counts; day 15 does not. A negative difference is a data error and triggers `MANUAL_REVIEW`.  
**R-003:** `condition=UNUSED`, packaging intact, standard non-final-sale category. Unknown condition **or packaging condition** → `MISSING_INFO`. Used item → `INELIGIBLE` (unless separately damaged/wrong item flow).  
**R-004:** Hygiene, customized/personalized, digital and final-sale items are not eligible for ordinary change-of-mind return.

## Rules — damaged/wrong item

**R-005:** `damaged` or `wrong_item` claims within **30 local calendar days**, inclusive, of delivery require manual review and an evidence reference. The photo/evidence is never automatically interpreted as conclusive proof.  
**R-006:** Over 30 days → `MANUAL_REVIEW`/escalation (even if evidence is missing; no automatic promise) for an exceptional dispute. At 30 days or less, missing evidence → `MISSING_INFO`. Reviewer may reject or route to manager, but cannot bypass stated refund limit.  
**R-007:** Excluded normal-return categories can still raise a damage/wrong-item dispute; only manual investigation may resolve it.

## Refund and approval rules

**R-008:** Proposed amount is **item amount actually paid** from authoritative order-item fields, no more than `5,000,000 VND` in MVP. Never calculate from customer-provided prices or LLM-generated amounts. Shipping/coupons/tax adjustment complexities are out of scope; fixtures include `paid_amount_vnd` already allocated per item.  
**R-009:** Every simulated refund, including `≤500,000 VND`, requires explicit `APPROVED` record by an authenticated `reviewer` and a separate server-side execution step. Reviewer cannot approve own customer's request if conflict-of-interest flag is set.  
**R-010:** Above `5,000,000 VND` → `ESCALATED`; no execution in MVP.  
**R-011:** An approval references `request_id`, `policy_version_id`, item ID, `proposed_amount_vnd`, and immutable `proposal_hash`. Any proposal change invalidates previous approval.  
**R-012:** Execute only if still `APPROVED`, not refunded, version/hash match, underlying paid amount is unchanged; lock request row and atomically write mock ledger + state + audit. Repeated execution is idempotent.  
**R-013:** Only `customer` may submit own request; `reviewer` approves; an internal authorized worker simulates issuing a refund. The LLM **never** holds a write-capable payment credential.

## Eligibility matrix

| Condition | Result | Customer-safe action |
|---|---|---|
| Standard, unused, delivered ≤14d, adequate facts | `ELIGIBLE` | Create case; queue reviewer approval |
| Standard, changed mind, delivered ≥15d | `INELIGIBLE` | Explain reason and possible dispute route |
| Item condition unknown | `MISSING_INFO` | Ask condition question |
| Wrong/damaged, within 30d, evidence present | `MANUAL_REVIEW` | Record and queue human review |
| Wrong/damaged, missing evidence | `MISSING_INFO` | Ask for evidence |
| Excluded category, ordinary change of mind | `INELIGIBLE` | Explain category exclusion |
| Not delivered / data mismatch / policy unavailable | `MISSING_INFO` or `MANUAL_REVIEW` | Clarify or escalate; no refund |
| Proposed amount > 5m | `MANUAL_REVIEW` / `ESCALATED` | No mock refund execution |

## Time boundary examples

With delivery date `2026-10-01` in HCMC: normal change-of-mind submitted **2026-10-15** is day 14 and eligible if all other facts pass; submitted **2026-10-16** is day 15 and ineligible. Day calculations use `(submitted_local_date - delivered_local_date).days`, not rounded elapsed hours.

## Denial vs escalation

`INELIGIBLE` = rules do not permit normal return. `MANUAL_REVIEW` = facts/rules demand human investigation, **not** approval. `MISSING_INFO` = no final decision. For exceptions, reviewer can document rationale and reject/route to manager; the MVP may not override deterministic refund constraints to force a payment.

## Customer language rules

Do not claim a refund has happened until a ledger record is committed. Before approval say "đã ghi nhận yêu cầu, đang chờ nhân viên xem xét". After simulated refund say "đã ghi nhận hoàn tiền giả lập trong hệ thống demo", **never** imply real bank payment. Cite policy ID and section for decisions.
