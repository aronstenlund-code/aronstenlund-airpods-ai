-- K62b (D180): accounts the server has seen as test traffic (header, script user agent, GitHub Actions IP, or the
-- account flag). They get fake audio and a fake transcript and never reach ElevenLabs. Service role only.
create table if not exists public.test_accounts (
  user_id uuid primary key references auth.users (id) on delete cascade,
  reason text not null,
  first_fn text,
  first_seen timestamptz not null default now()
);
alter table public.test_accounts enable row level security;
revoke all on public.test_accounts from public, anon, authenticated;
grant select, insert, update, delete on public.test_accounts to service_role;
