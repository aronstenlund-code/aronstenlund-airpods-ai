-- K62: what /drill last saw of the ElevenLabs credits (the subscription when the key may read it, else the
-- "credits remaining" of a quota error), for the morning report's warning under 20 %. Service role only.
create table if not exists public.provider_status (
  provider text primary key,
  status integer,
  used bigint,
  lim bigint,
  reset_unix bigint,
  remaining_hint bigint,
  updated_at timestamptz not null default now()
);
alter table public.provider_status enable row level security;
revoke all on public.provider_status from public, anon, authenticated;
grant select, insert, update on public.provider_status to service_role;
