# 08 — REST API Contract (v1)

Machine-readable MVP baseline: [`../contracts/openapi.yaml`](../contracts/openapi.yaml). Base URL `/v1`, JSON UTF-8, dates ISO 8601 with offsets; server stores UTC instants. **OpenAPI covers the documented primary MVP routes; implementation must extend it for any future endpoints.**

## Auth and roles

Authentication uses **Supabase Auth**. Next.js obtains an access token through its Supabase SSR session flow and sends `Authorization: Bearer <supabase-access-token>` to FastAPI. FastAPI verifies the token **against Supabase Auth** (or a carefully validated project JWT/JWKS flow) and resolves `sub` to `public.users.auth_user_id`; it then loads `tenant_id`, `role` and `is_active` from `public.users` for all business authorization. JWT `role=authenticated` is a Supabase infrastructure claim, **not** the ReturnOps application `reviewer` role; never authorize from editable `user_metadata`. There is no custom demo JWT signer in v1.1. Business APIs remain FastAPI-only; no Supabase Data API routes for orders or refunds.

## Routes

| Method | Path | Role | Result |
|---|---|---|---|
| GET | `/healthz` | public | API process status (no secrets) |
| GET | `/v1/orders` | customer | Owned orders only |
| GET | `/v1/orders/{order_id}` | customer | One owned order; masked 404 otherwise |
| POST | `/v1/conversations` | customer | New server-bound graph thread |
| POST | `/v1/conversations/{conversation_id}/messages` | customer | LLM response, clarification or proposal; no automatic money mutation |
| POST | `/v1/returns` | customer | Create validated case after UI confirmation |
| GET | `/v1/returns/{request_id}` | owner/reviewer | Read status and citations |
| GET | `/v1/review/queue` | reviewer | Cases requiring review |
| POST | `/v1/returns/{request_id}/approval` | reviewer | Approve/reject exact proposal |
| POST | `/v1/internal/returns/{request_id}/mock-refund` | internal worker | Protected simulation mutation; NOT public browser API |
| GET | `/v1/returns/{request_id}/audit` | authorized reviewer/admin | Redacted history |

## Key request/response examples

**Chat turn**

```http
POST /v1/conversations/0aa04005-9fe6-4e64-bdc2-e9689365607f/messages
Authorization: Bearer <access-token>
Content-Type: application/json

{"message":"Đơn hàng này chưa dùng, mình muốn trả nhé"}
```

```json
{
  "message_id":"server-generated-uuid",
  "reply":"Mình đã ghi nhận yêu cầu. Bạn xác nhận sản phẩm chưa sử dụng và còn nguyên bao bì nhé.",
  "state":"NEEDS_CLARIFICATION",
  "citations":[],
  "proposal":null,
  "trace_id":"server-trace-id"
}
```

**Create return** (server **re-evaluates**, does not trust `proposed_amount_vnd` from client)

```http
POST /v1/returns
Authorization: Bearer <access-token>
Idempotency-Key: ret-create-demo-001
Content-Type: application/json

{"order_id":"<uuid>","item_id":"<uuid>","reason":"changed_mind","condition":"UNUSED","packaging_intact":true,"evidence_refs":[]}
```

```json
{
  "request_id":"<uuid>",
  "status":"PENDING_APPROVAL",
  "eligibility":"ELIGIBLE",
  "proposed_amount_vnd":350000,
  "policy_version_id":"POL-2026-001",
  "proposal_hash":"sha256-hex",
  "citations":[{"rule_id":"R-002","policy_version_id":"POL-2026-001","chunk_id":"POL-2026-001:R-002"}]
}
```

**Approval**

```http
POST /v1/returns/<uuid>/approval
Authorization: Bearer <reviewer-token>
Idempotency-Key: approve-demo-001
Content-Type: application/json

{"decision":"APPROVE","reason":"Đã xác minh chính sách và số tiền", "proposal_hash":"<hash>", "case_version":1}
```

```json
{"approval_id":"<uuid>","status":"APPROVED","execution":"QUEUED"}
```

## Validation & error taxonomy

All API errors return:

```json
{
  "error":{"code":"POLICY_VERSION_UNAVAILABLE","message":"Cannot validate the applicable policy", "retryable":false},
  "trace_id":"<trace-id>"
}
```

- `400 BAD_REQUEST` invalid domain request; `401 UNAUTHENTICATED`; `403 FORBIDDEN`; `404 NOT_FOUND` (also hides other customer's order); `409 INVALID_STATE`/`IDEMPOTENCY_CONFLICT`/`STALE_PROPOSAL`; `422 VALIDATION_ERROR`; `429 RATE_LIMITED`; `503 DEPENDENCY_UNAVAILABLE`.
- Server-side validation includes UUID, enum, max message length, number of evidence refs, case version, policy snapshot and amount ceiling.
- Replay with same key + payload returns same result; same key + different payload returns 409.

## Pagination, correlations, rate limits

Use cursor pagination for orders and reviewer queue (MVP may start with limit/offset). Return `X-Request-ID`; propagate W3C trace context internally, but never accept privileged context from browser. Target initial rate limit: 10 chat turns per minute per demo user, 30 read requests/minute; tune after measurement. Reviewer approval rate limited and requires CSRF defenses if cookie-based session is used.

## SSE/streaming (optional P1)

Initially return the completed reply. Later add a separate `GET /v1/conversations/{id}/events` stream with events `progress`, `citation`, `reply`, `error`, `done`; never stream secrets or use streamed LLM prose as proof of committed state.
