-- K94 (D218): bought credits per account; transaction_id unique so a purchase never counts twice. service_role only.
create table if not exists public.credit_ledger (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('purchase', 'refund', 'use')),
  product_id text, transaction_id text unique, original_transaction_id text,
  credits integer not null, environment text, created_at timestamptz not null default now()
);
create index if not exists credit_ledger_user on public.credit_ledger (user_id);
alter table public.credit_ledger enable row level security;
revoke all on public.credit_ledger from public, anon, authenticated;
