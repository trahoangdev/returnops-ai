-- ReturnOps AI v1.1: REFERENCE RLS and Data API lockdown; not an executed migration.
-- Include this AFTER contracts/db_schema.sql when authoring the first Supabase SQL migration.
-- Explicitly list every business table in public. Do not expose browser CRUD for MVP.
-- For tables created later, ALWAYS add RLS and grants review to their migrations.
DO $rls$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'tenants', 'users', 'policy_versions', 'policy_chunks', 'orders',
    'order_items', 'conversations', 'messages', 'return_requests',
    'approvals', 'mock_refunds', 'idempotency_records', 'outbox_events', 'audit_events'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM anon, authenticated', table_name);
  END LOOP;
END
$rls$;
-- RLS without policies is intentionally deny-by-default for anon and authenticated.
-- Also inspect grants inherited from PUBLIC/other roles and default privileges in your environment.
-- Audit Data API exposed schemas and table grants before release.
-- WARNING: service_role and privileged DB roles bypass RLS: never ship their keys/URLs to browser.
-- The FastAPI SQL connection is trusted server-side; EVERY query requires backend authz scope.
-- Graph checkpoint tables in any exposed schema require the same review/lockdown.
