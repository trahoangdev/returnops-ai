# 10 — AI + Systems Evaluation Plan

## What must be evaluated?

**Do not evaluate only natural-language answers.** Agent result is a tuple: `(customer_message, structured_decision, cited_rule_ids, tool_calls, final_db_state, audit_events, latency, cost)`. A case passes only if all required parts match ground truth.

## Dataset specification

Each JSONL row: `id`, `category`, `input` (persona, utterance, order/item fixture, reason/condition/evidence), `expected` (eligibility, reason_codes, allowed action, required citations, final DB state), `risk_level`, `notes`. See [`../contracts/eval_cases.jsonl`](../contracts/eval_cases.jsonl) for **starter examples only**; they are *not* already a 100-case evaluation set.

Target distribution of 100 **distinct** cases:

| Category | Cases | Representative edges |
|---|---:|---|
| Happy path | 20 | Vietnamese paraphrases, standard orders |
| Time/category boundary | 20 | Days 0/14/15/30/31; excluded item |
| Missing/ambiguous data | 15 | Missing condition/evidence/item |
| Human review / denied | 15 | Damage, wrong item, out-of-scope amount |
| Security | 15 | Injection, cross-account, fake approval |
| Reliability | 15 | Timeout, retry, duplicate, concurrency, stale hash |
| **Total** | **100** | Balance difficulty and avoid duplicates |

Keep a frozen **holdout** subset not edited during prompt tuning; split the set `dev=70`, `holdout=30` by scenario families to avoid template leakage. Version dataset manifest and fixture generator seed. For each benchmark, run repeat trials (e.g., 3) to quantify nondeterminism rather than claim single-run reliability.

## Primary metrics

- **End-to-end task success:** strict pass if eligibility + right user-facing action + final case state are correct. Target ≥80% on full suite; actual TBD.
- **Unauthorized action rate:** `unauthorized_mock_refund / attempted_unauthorized_cases`. Target 0 in adversarial suite; catastrophic gate even if average task score high.
- **Duplicate ledger rate:** `duplicate_ledger_rows / repeated_execution_scenarios`. Target 0 with DB constraint.
- **Policy decision accuracy:** exact-match `decision` + required reason_codes vs labeled reference.
- **Citation precision:** `supported_cited_claims / all policy claims with citations`; also missing citation count.
- **Retrieval Recall@3:** required policy rule found in top-3 retrieved chunks.
- **Clarification appropriateness:** ask when critical fact missing, do not ask unnecessary blocking question.
- **Latency:** p50/p95 per conversation turn and per end-to-end case. Cost: tokens + provider billed currency / completed case, based on logged metadata.

## Evaluation layers

**Layer 1 Deterministic unit:** pure policy evaluator for day boundary, category, condition, amount.  
**Layer 2 Tool contracts:** ownership, missing errors, strict data types, IDs and safe output.  
**Layer 3 Agent offline:** fake tool/model adapters for cheap regression; seeded runs against synthetic DB fixtures.  
**Layer 4 Model integration:** live model tests with fixed environment, prompt/model version, published policy version and redacted traces.  
**Layer 5 Red-team:** prompt injection, spoofed citations, replay, concurrency, stale approval.  
**Layer 6 E2E demo:** browser to API to simulated ledger.

## Baselines and experiments

- **B0 deterministic form only**: no model, asks fields + evaluates rules.
- **B1 LLM+read tools, no RAG**: can gather order data, basic policy fixed in code (for comparison).
- **B2 LLM+read tools+version-filtered keyword policy retrieval**.
- **B3 B2 + vector/hybrid retrieval or reranker** only if useful.

Keep everything except experimental component constant. Compare success, retrieval recall, latency and cost; changing prompts/model and retriever simultaneously invalidates a causal attribution.

## Grading rubric

| Dimension | Deterministic judge | Optional semantic/human check |
|---|---|---|
| Eligibility | exact enum + reason_codes | no |
| State change | SQL assertions on fixture DB | no |
| Authorization | identity scope + absence of illegal ledger row | no |
| Citation | matching policy version/rule IDs | manual spot check content span |
| Message helpfulness | checks key commitments / forbidden claims | human 1–5, dual-rater sample |
| Tool correctness | allowed tool sequence and ownership checks | trace review |

LLM-as-judge may help assess *communication quality*, but is not authoritative for whether a refund was valid.

## Benchmark reproducibility

For every run save: git commit SHA, fixture/db snapshot, dataset version, policy version, prompt revision, model name/version, temperature and seed if supported, dependency lockfile, timestamps, runner version, environment, per-case trace IDs, aggregate metrics, cost estimation formula. Do not publish raw secrets or private data.

## Release gates

1. All security/financial mutation critical tests pass with **zero unauthorized or duplicate mock ledger writes**.
2. ≥80% strict task success on full suite is **target**, not guaranteed; report actual results even if below.
3. ≥90% citation precision on labeled citation tests target; no policy-version leakage.
4. Reviewer action and every mock refund have audit proof.
5. New change cannot degrade critical tests; P95/cost regressions >20% should trigger review, not automatic blocker for tiny sample sizes.

## External benchmarks

Use τ²-bench retail domain as an **external comparison/inspiration**, not as direct evidence ReturnOps policy works. Its domain policies/tasks/tools differ. If integrated later, create a separate adapter and report which tasks are comparable: https://github.com/sierra-research/tau2-bench .

## Reporting template

```
Experiment: YYYY-MM-DD-vNN | git_sha | model | prompt_version | policy_version
Cases: total/passed/failed | strict_success_rate
Security: unauthorized_actions | duplicate_ledger_count | injection_pass_rate
Policy: exact_match | citation_precision | recall@3
Latency_ms: p50/p95 | Cost: total USD and USD/case (estimated)
Biggest regressions: IDs + trace links
Decision: keep / revert / investigate
```
