-- K94 (D218): the weekly subscription per account (from StoreKit 2 and App Store Server Notifications v2).
create table if not exists public.store_subscriptions (
  original_transaction_id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id text not null, expires_at timestamptz not null,
  status text not null default 'active', environment text, updated_at timestamptz not null default now()
);
create index if not exists store_subscriptions_user on public.store_subscriptions (user_id);
alter table public.store_subscriptions enable row level security;
revoke all on public.store_subscriptions from public, anon, authenticated;
