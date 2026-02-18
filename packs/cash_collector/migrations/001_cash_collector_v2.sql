-- CASH COLLECTOR V2 - Pack schema
-- MVP: CSV ingest -> drafts + approvals (no-send)

do $$ begin
  create type invoice_status as enum ('open','paid','disputed','promise','unreachable');
exception when duplicate_object then null; end $$;

do $$ begin
  create type action_type as enum ('email_soft','email_firm','email_final','task_call','escalation_draft');
exception when duplicate_object then null; end $$;

do $$ begin
  create type action_status as enum ('planned','pending_approval','approved','exported','skipped','failed');
exception when duplicate_object then null; end $$;

create table if not exists invoices (
  invoice_id text primary key,

  debtor_name text,
  debtor_email text,

  amount numeric not null,
  currency text not null default 'EUR',
  due_date date,

  status invoice_status not null default 'open',

  last_contact_at timestamptz,
  next_action_at timestamptz,

  source text not null check (source in ('csv','email')),
  source_ref text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists invoice_actions (
  id uuid primary key default gen_random_uuid(),
  invoice_id text not null references invoices(invoice_id) on delete cascade,

  action_type action_type not null,
  status action_status not null default 'planned',

  scheduled_at timestamptz,
  approved_at timestamptz,
  exported_at timestamptz,

  run_id uuid references runs(id) on delete set null,

  created_at timestamptz not null default now()
);

-- updated_at trigger defined in core migration (set_updated_at)
drop trigger if exists trg_invoices_updated_at on invoices;
create trigger trg_invoices_updated_at
before update on invoices
for each row execute function set_updated_at();

create index if not exists idx_invoices_status_next_action on invoices(status, next_action_at);
create index if not exists idx_actions_invoice_status on invoice_actions(invoice_id, status);
