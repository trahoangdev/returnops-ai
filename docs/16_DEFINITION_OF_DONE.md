# 16 — Definition of Done / Release Checklist

## P0 product

- [ ] Customer sees only own orders and owned case status.
- [ ] Vietnamese chat clarifies absent fields rather than guessing.
- [ ] Policy-based answers cite version + rule/section.
- [ ] Server-side eligibility covers normal, excluded, damage/wrong-item and time boundaries.
- [ ] User explicitly confirms before a return case is created.
- [ ] Reviewer sees frozen proposal and must approve/reject with reason.
- [ ] Mock ledger write requires valid reviewer approval; no real payment integration.

## Reliability and security

- [ ] All status transitions are validated and tested.
- [ ] Two concurrent executions create exactly one mock ledger row.
- [ ] Same idempotency key + conflicting payload produces 409.
- [ ] Invalid role/cross-account read denied and tested.
- [ ] Prompt injection in user text and policy content cannot cause privileged actions.
- [ ] Stale proposal approval is blocked.
- [ ] Runtime errors preserve safe status; no false "refunded" message.
- [ ] Tokens and customer-sensitive fields absent from traces and git history.

## Engineering

- [ ] Typed API schemas and documented errors match OpenAPI.
- [ ] Database migrations and rollback path tested against clean local instance.
- [ ] Docker Compose / setup script builds from clean clone.
- [ ] Unit, integration, API and E2E tests run in CI.
- [ ] 100 diverse eval cases labeled; dev/holdout split fixed.
- [ ] Benchmark report records actual outcomes, tool traces, costs and limitations.
- [ ] System architecture/state diagram updated from implementation.
- [ ] README explains both product and safe simulation disclaimer.

## Portfolio artifacts

- [ ] Public repo with synthetic data and no secrets.
- [ ] 3–5 minute walkthrough: eligible, ineligible, manual review, injection, duplicate replay.
- [ ] One screenshot of trace and an example error triage.
- [ ] Benchmark table baseline vs improved with measured values.
- [ ] ADRs explain why not multi-agent and why no real refund.
- [ ] Limitations and next milestones stated honestly.

**Release decision:** Do not claim done if any critical financial/auth security checkbox fails, regardless of UX quality or LLM task score.
