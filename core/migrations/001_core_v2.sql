-- OPS CORE V2 - Core schema (Supabase Postgres)
-- Notes:
-- - Ledger/events is append-only by convention (enforced at app/workflow level).
-- - PII must be redacted before insert into *_redacted fields.
-- - approvals use token_hash (never store raw token).
-- - locks table prevents duplicate/concurrent execution (idempotence).

-- ===== ENUMS =====
do $$ begin
  create type run_status as enum ('queued','running','needs_approval','done','error','dead');
exception when duplicate_object then null; end $$;

do $$ begin
  create type job_status as enum ('queued','running','done','error','dead');
exception when duplicate_object then null; end $$;

do $$ begin
  create type approval_status as enum ('pending','approved','rejected','expired');
exception when duplicate_object then null; end $$;

-- ===== UPDATED_AT TRIGGER =====
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end; $$ language plpgsql;

-- ===== RUNS =====
create table if not exists runs (
  id uuid primary key default gen_random_uuid(),

  wedge text not null, -- ex: cashflow, support_ops
  pack text not null, -- ex: cash_collector
  client_id text not null,

  entity_type text, -- ex: invoice, ticket
  entity_id text, -- ex: INV-123

  status run_status not null default 'queued',

  trigger_type text not null, -- csv|email|manual|schedule|webhook
  trigger_ref text,

  policy_version text not null, -- cash_collector@1.0.0
  confidence numeric check (confidence is null or (confidence >= 0 and confidence <= 1)),

  idempotency_key text not null unique,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_runs_updated_at on runs;
create trigger trg_runs_updated_at
before update on runs
for each row execute function set_updated_at();

create index if not exists idx_runs_pack_status on runs(pack, status);
create index if not exists idx_runs_entity on runs(entity_type, entity_id);

-- ===== LOCKS (idempotence / concurrency) =====
create table if not exists locks (
  key text primary key, -- idempotency_key
  run_id uuid references runs(id) on delete set null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_locks_expires on locks(expires_at);

-- ===== EVENTS (IMMUTABLE LEDGER) =====
create table if not exists events (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references runs(id) on delete cascade,

  step text not null, -- extract|classify|draft|gate|export|log
  status text not null check (status in ('ok','warning','error')),

  input_redacted jsonb,
  output_redacted jsonb,

  error_code text,
  error_message_redacted text,

  duration_ms int check (duration_ms is null or duration_ms >= 0),

  created_at timestamptz not null default now()
);

create index if not exists idx_events_run_created on events(run_id, created_at);

-- ===== APPROVALS (HMAC LINKS, TOKEN HASH ONLY) =====
create table if not exists approvals (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references runs(id) on delete cascade,

  approval_type text not null, -- email_draft_send|escalation|dispute
  payload_redacted jsonb,

  status approval_status not null default 'pending',
  approver text,
  comment text,

  token_hash text not null, -- sha256(raw_token) hex/base64 (never raw)
  expires_at timestamptz not null,

  created_at timestamptz not null default now(),
  decided_at timestamptz
);

create index if not exists idx_approvals_run_status on approvals(run_id, status);
create index if not exists idx_approvals_expires on approvals(expires_at);

-- ===== POLICIES (VERSIONED) =====
create table if not exists policies (
  id uuid primary key default gen_random_uuid(),
  wedge text not null,
  pack text not null,
  version text not null,
  policy_json jsonb not null,
  created_at timestamptz not null default now(),
  unique(pack, version)
);

create index if not exists idx_policies_pack_version on policies(pack, version);

-- ===== JOBS QUEUE (RELIABLE ASYNC) =====
create table if not exists jobs_queue (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references runs(id) on delete cascade,

  job_type text not null, -- generate_draft|export_csv|sync_status
  payload_redacted jsonb,

  attempt int not null default 0 check (attempt >= 0),
  max_attempts int not null default 5 check (max_attempts >= 1),

  next_run_at timestamptz not null default now(),
  status job_status not null default 'queued',

  last_error_redacted text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_jobs_updated_at on jobs_queue;
create trigger trg_jobs_updated_at
before update on jobs_queue
for each row execute function set_updated_at();

create index if not exists idx_jobs_status_next_run on jobs_queue(status, next_run_at);

-- ===== DEAD LETTER =====
create table if not exists dead_letter (
  id uuid primary key default gen_random_uuid(),
  job_id uuid,
  run_id uuid,
  reason text not null,
  payload_redacted jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_dead_letter_run on dead_letter(run_id);

-- ===== CONNECTORS REGISTRY (NO SECRETS STORED) =====
create table if not exists connectors (
  name text primary key, -- supabase, smtp, etc
  type text not null,
  scopes text,
  secrets_ref text not null, -- reference only (ENV/secret store path)
  created_at timestamptz not null default now()
);

-- ===== ARTIFACTS (DRAFTS / EXPORTS) =====
create table if not exists artifacts (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references runs(id) on delete cascade,

  type text not null, -- email_draft|csv_export|report
  uri text,
  hash text,
  payload_redacted jsonb, -- inline for MVP

  created_at timestamptz not null default now()
);

create index if not exists idx_artifacts_run_type on artifacts(run_id, type);

-- ===== METRICS =====
create table if not exists metrics_daily (
  day date not null,
  wedge text not null,
  pack text not null,
  kpi_json jsonb not null,
  created_at timestamptz not null default now(),
  primary key(day, wedge, pack)
);
