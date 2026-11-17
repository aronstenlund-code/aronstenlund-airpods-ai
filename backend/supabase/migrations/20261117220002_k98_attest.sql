-- K98: App Attest keys (one account per key) and one-time challenges. service_role only.
create table if not exists public.app_attest_keys (key_id text primary key,
  user_id uuid not null references auth.users (id) on delete cascade, created_at timestamptz not null default now());
create table if not exists public.app_attest_challenges (challenge text primary key, user_id uuid not null,
  used boolean not null default false, expires_at timestamptz not null);
alter table public.app_attest_keys enable row level security;
alter table public.app_attest_challenges enable row level security;
revoke all on public.app_attest_keys, public.app_attest_challenges from public, anon, authenticated;
