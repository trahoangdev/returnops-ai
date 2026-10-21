-- ReturnOps AI v1.1 REFERENCE schema for SUPABASE PostgreSQL, NOT an applied migration.
-- Use Supabase CLI SQL migrations as the sole source of truth; add contracts/supabase_rls.sql
-- to the initial migration AFTER table creation. Verify against a disposable Supabase local stack.
-- Supabase usually provisions `extensions`; enable pgvector there, not public.
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

CREATE TABLE tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  demo_subject text NOT NULL,
  -- Null only for disconnected fixture rows until the local Auth bootstrap binds identity.
  auth_user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  role text NOT NULL CHECK (role IN ('customer','reviewer','admin','system_worker')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, demo_subject),
  UNIQUE (tenant_id, id)
);

CREATE TABLE policy_versions (
  id text PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  status text NOT NULL CHECK (status IN ('DRAFT','PUBLISHED','RETIRED')),
  effective_from timestamptz NOT NULL,
  effective_to timestamptz,
  content_sha256 char(64) NOT NULL,
  source_path text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (effective_to IS NULL OR effective_to > effective_from),
  UNIQUE (tenant_id, id)
);
-- Application/admin publishing service must additionally prevent overlapping effective intervals.

CREATE TABLE policy_chunks (
  id text PRIMARY KEY,
  tenant_id uuid NOT NULL,
  policy_version_id text NOT NULL,
  rule_id text NOT NULL,
  section text NOT NULL,
  content text NOT NULL,
  ordinal integer NOT NULL CHECK (ordinal >= 0),
  content_sha256 char(64) NOT NULL,
  embedding_model text,
  embedding extensions.vector(1536), -- illustrative dimension; MUST match chosen embedding model
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, policy_version_id) REFERENCES policy_versions(tenant_id, id),
  UNIQUE (tenant_id, policy_version_id, rule_id, ordinal)
);
CREATE INDEX policy_chunks_policy_idx ON policy_chunks(tenant_id, policy_version_id);
-- Add HNSW only after benchmark and dimension/model choice:
-- CREATE INDEX ... USING hnsw (embedding vector_cosine_ops);

CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  order_number text NOT NULL,
  placed_at timestamptz NOT NULL,
  policy_version_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, customer_id) REFERENCES users(tenant_id, id),
  FOREIGN KEY (tenant_id, policy_version_id) REFERENCES policy_versions(tenant_id, id),
  UNIQUE (tenant_id, order_number),
  UNIQUE (tenant_id, id)
);

CREATE TABLE order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  order_id uuid NOT NULL,
  sku text NOT NULL,
  category text NOT NULL CHECK (category IN ('standard','hygiene','customized','digital','final_sale')),
  status text NOT NULL CHECK (status IN ('PENDING','SHIPPED','DELIVERED','CANCELED')),
  paid_amount_vnd bigint NOT NULL CHECK (paid_amount_vnd >= 0),
  delivered_at timestamptz,
  FOREIGN KEY (tenant_id, order_id) REFERENCES orders(tenant_id, id),
  UNIQUE (tenant_id, id)
);

CREATE TABLE conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  graph_thread_id uuid NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, customer_id) REFERENCES users(tenant_id, id),
  UNIQUE (tenant_id, id)
);

CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  conversation_id uuid NOT NULL,
  role text NOT NULL CHECK (role IN ('customer','assistant','system_notice')),
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, conversation_id) REFERENCES conversations(tenant_id, id)
);

CREATE TABLE return_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  customer_id uuid NOT NULL,
  order_item_id uuid NOT NULL,
  policy_version_id text NOT NULL,
  reason text NOT NULL CHECK (reason IN ('changed_mind','damaged','wrong_item','other')),
  item_condition text CHECK (item_condition IN ('UNUSED','USED','UNKNOWN')),
  packaging_intact boolean,
  evidence_refs jsonb NOT NULL DEFAULT '[]'::jsonb,
  eligibility text NOT NULL CHECK (eligibility IN ('ELIGIBLE','INELIGIBLE','MANUAL_REVIEW','MISSING_INFO')),
  reason_codes jsonb NOT NULL DEFAULT '[]'::jsonb,
  status text NOT NULL CHECK (status IN ('DRAFT','NEEDS_INFO','PENDING_APPROVAL','APPROVED','REFUND_PENDING','REFUNDED','INELIGIBLE','MANUAL_REVIEW','REJECTED','ESCALATED','CANCELED')),
  proposed_amount_vnd bigint CHECK (proposed_amount_vnd BETWEEN 0 AND 5000000),
  proposal_hash char(64),
  version integer NOT NULL DEFAULT 1 CHECK (version > 0),
  submitted_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, customer_id) REFERENCES users(tenant_id, id),
  FOREIGN KEY (tenant_id, order_item_id) REFERENCES order_items(tenant_id, id),
  FOREIGN KEY (tenant_id, policy_version_id) REFERENCES policy_versions(tenant_id, id),
  UNIQUE (tenant_id, id)
);
CREATE UNIQUE INDEX one_active_return_per_item ON return_requests (tenant_id, order_item_id)
WHERE status IN ('DRAFT','NEEDS_INFO','PENDING_APPROVAL','APPROVED','REFUND_PENDING','MANUAL_REVIEW');
CREATE INDEX return_reviewer_queue ON return_requests(tenant_id, status, updated_at);

CREATE TABLE approvals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  return_request_id uuid NOT NULL,
  reviewer_id uuid NOT NULL,
  decision text NOT NULL CHECK (decision IN ('APPROVE','REJECT')),
  reason text NOT NULL,
  proposal_hash char(64) NOT NULL,
  proposed_amount_vnd bigint NOT NULL CHECK (proposed_amount_vnd BETWEEN 0 AND 5000000),
  case_version integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, return_request_id) REFERENCES return_requests(tenant_id, id),
  FOREIGN KEY (tenant_id, reviewer_id) REFERENCES users(tenant_id, id),
  UNIQUE (tenant_id, return_request_id, case_version)
);

CREATE TABLE mock_refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  return_request_id uuid NOT NULL,
  approved_by uuid NOT NULL,
  amount_vnd bigint NOT NULL CHECK (amount_vnd BETWEEN 0 AND 5000000),
  idempotency_key text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (tenant_id, return_request_id) REFERENCES return_requests(tenant_id, id),
  FOREIGN KEY (tenant_id, approved_by) REFERENCES users(tenant_id, id),
  UNIQUE (tenant_id, return_request_id),
  UNIQUE (tenant_id, idempotency_key)
);

CREATE TABLE idempotency_records (
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  operation text NOT NULL,
  idem_key text NOT NULL,
  request_hash char(64) NOT NULL,
  response_code integer,
  response_body jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, operation, idem_key)
);

CREATE TABLE outbox_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  return_request_id uuid NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('MOCK_REFUND_REQUESTED')),
  status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','PROCESSING','DONE','FAILED')),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  FOREIGN KEY (tenant_id, return_request_id) REFERENCES return_requests(tenant_id, id),
  UNIQUE (tenant_id, return_request_id, event_type)
);

CREATE TABLE audit_events (
  id bigserial PRIMARY KEY,
  tenant_id uuid NOT NULL REFERENCES tenants(id),
  actor_type text NOT NULL CHECK (actor_type IN ('customer','reviewer','admin','system_worker')),
  actor_id uuid,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id uuid NOT NULL,
  old_state text,
  new_state text,
  reason_code text,
  policy_version_id text,
  trace_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_target_idx ON audit_events(tenant_id, target_type, target_id, created_at);

-- Design guardrails NOT enforced by this DDL alone:
-- 1. FastAPI MUST verify Supabase Auth bearer token, look up users.auth_user_id and check users.role, tenant and ownership.
--    JWT `role=authenticated` IS NOT the ReturnOps reviewer role.
-- 1b. Run contracts/supabase_rls.sql in the same reviewed migration: all public tables RLS enabled, no direct anon/authenticated CRUD.
-- 2. Enforce transitions with transactionally validated domain service.
-- 3. Enforce policy effective interval exclusion on publishing.
-- 4. Keep published policy immutable via privileges/triggers/service controls.
-- 5. Restrict server-only DB credentials. Initially a privileged project connection is acceptable ONLY
--    in an isolated synthetic demo; use dedicated roles/policies before sensitive production use.
-- 6. Add durable graph checkpoint tables according to pinned LangGraph version.
