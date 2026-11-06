-- D62: waitlist for the public demo page. Only the Edge Function `waitlist` (service role) writes: it
-- validates the e-mail, requires consent, limits per network and ignores duplicates. RLS is on with NO
-- policy for anon/authenticated, so nobody can read, change or insert directly through the REST API
-- (a direct insert policy would bypass the validation, consent check and rate limit).
create table if not exists public.waitlist (
  id              uuid primary key default gen_random_uuid(),
  email           text not null unique check (char_length(email) <= 254 and email = lower(email)),
  created_at      timestamptz not null default now(),
  source          text not null default 'demo' check (source ~ '^[a-z0-9_-]{1,32}$'),
  consent_at      timestamptz not null default now(),
  consent_version text check (char_length(consent_version) <= 16)
);
create index if not exists waitlist_created_idx on public.waitlist (created_at desc);

alter table public.waitlist enable row level security;
revoke all on public.waitlist from public, anon, authenticated;
grant all on public.waitlist to service_role;
