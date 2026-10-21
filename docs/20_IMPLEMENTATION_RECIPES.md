# 20 — Implementation Recipes (reference pseudocode)

These examples clarify logic and testability; **they are not runnable production modules**. Align imports and SDK signatures with pinned dependency versions when coding.

## 1. Pure policy evaluator

Inputs should use typed immutable models, an injected clock/submission time, and a published policy version matching the order. All data comes from authoritative DB rows, with customer statements captured separately. `condition` and `packaging_intact` are explicit customer attestations, not warehouse facts; reviewers still validate the case before any simulated refund.

```python
def evaluate(item, reason, condition, packaging_intact, evidence_refs,
             submitted_at, published_policy):
    if item.status != "DELIVERED" or item.delivered_at is None:
        return result("MISSING_INFO", ["R-001"], amount=None)

    delivered_day = item.delivered_at.astimezone(VN_TZ).date()
    submitted_day = submitted_at.astimezone(VN_TZ).date()
    days = (submitted_day - delivered_day).days
    if days < 0:
        return result("MANUAL_REVIEW", ["R-001"], amount=None)

    # Paid amount is authoritative. Check ceiling before preparing any proposal.
    amount = item.paid_amount_vnd
    if amount > 5_000_000:
        return result("MANUAL_REVIEW", ["R-010"], amount=None, escalate=True)

    if reason in ("damaged", "wrong_item"):
        if days > 30:
            return result("MANUAL_REVIEW", ["R-006"], amount=None, escalate=True)
        if not evidence_refs:
            return result("MISSING_INFO", ["R-006"], amount=None)
        return result("MANUAL_REVIEW", ["R-005"], amount=amount)

    if reason != "changed_mind":
        return result("MANUAL_REVIEW", ["R-007"], amount=None)
    if item.category != "standard":
        return result("INELIGIBLE", ["R-004"], amount=None)
    if days > 14:
        return result("INELIGIBLE", ["R-002"], amount=None)
    if condition in (None, "UNKNOWN") or packaging_intact is None:
        return result("MISSING_INFO", ["R-003"], amount=None)
    if condition != "UNUSED" or packaging_intact is False:
        return result("INELIGIBLE", ["R-003"], amount=None)
    return result("ELIGIBLE", ["R-001", "R-002", "R-003"], amount=amount)
```

If data is corrupted (negative price, status/delivery timestamp conflict, unpublished policy), fail closed and escalate instead of trying to repair with LLM guesses. The `amount` on `MANUAL_REVIEW` is **informational only**, not authority to issue a refund. For ordinary return, include rule `R-004` as exclusion evidence if implementing an expanded audit.

## 2. Canonical proposal hash

Build a canonical JSON object with stable types, sorted keys and no floating-point currency. Include `tenant_id`, `request_id`, `item_id`, `policy_version_id`, `amount_vnd`, `reason`, `condition`, `packaging_intact`, normalized evidence hashes and `case_version`. Hash UTF-8 bytes via SHA-256; store in request and approval. This prevents silent proposal swapping but **does not replace authorization or DB locks**.

## 3. Approval

```text
POST approval (verified reviewer role, tenant scope, idempotency key)
  BEGIN
  LOCK target return request
  require status == PENDING_APPROVAL
  require incoming case_version matches current
  require proposal_hash and amount snapshot match DB
  require reviewer not conflicted
  INSERT approvals APPROVE or REJECT, actor, reason, hash, case_version
  UPDATE case status to APPROVED or REJECTED, version += 1
  IF approved: INSERT outbox MOCK_REFUND_REQUESTED
  INSERT audit event
  COMMIT
```

## 4. Outbox execution

```text
BEGIN
  CLAIM outbox event (FOR UPDATE SKIP LOCKED)
  LOCK case
  IF matching mock_refunds row exists: mark done and return existing result
  REQUIRE case approved & approved snapshot matches current proposal
  REQUIRE authoritative order item amount <= 5m and equals approved amount
  INSERT single unique mock_refunds row
  UPDATE case REFUNDED (+version)
  INSERT audit event; mark outbox DONE
COMMIT
```

If a crash happens before commit, retry from pending event. If after commit but before HTTP response, a retry reads existing ledger and returns the same outcome. Protect against stuck `PROCESSING` claims with lease/retry policy and dead-letter state; monitor failures.

## 5. Retrieval version filter

```sql
SELECT id, rule_id, section, content
FROM policy_chunks
WHERE tenant_id = :server_tenant_id
  AND policy_version_id = :order_bound_policy_version
ORDER BY ordinal ASC;
```

For a small 13-rule document, exact rule-aware retrieval is a strong baseline. Only add semantic search and approximate indexes after measuring improvement; never allow cross-version hits.

## 6. Unit tests before agent wiring

1. Pure policy cases: day14/day15, packaging unknown, damage + evidence, 5m/5m+1.
2. Authorization: customer A cannot see customer B.
3. Transaction: simultaneous refund jobs insert one ledger entry.
4. Prompt: model says `APPROVED` but backend approval row absent → no ledger write.

## 7. Common traps

- Reading LangGraph interrupt state as approval; always query backend approval row.
- Using submitted LLM classification as the only source of `condition`; confirm facts.
- Computing days in UTC instead of HCMC calendar time.
- Attempting "exactly once delivery" over a queue without idempotent DB effect.
- Making published policy content mutable in place.
- Using LLM-as-judge as the only correctness gate for financial actions.
