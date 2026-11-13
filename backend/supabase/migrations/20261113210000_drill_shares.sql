-- K47 (D143): sharing a drill with classmates. A share is a code that points at the drill; importing copies the
-- questions and answers into the recipient's account, and the copy uses the same audio files (no new generation).
-- Photos and documents are never stored, so they are never shared (B4). Service role only (through /functions/v1/drill).
create table if not exists public.drill_shares (
  code        text primary key check (code ~ '^[a-z0-9]{8,16}$'),
  drill_id    uuid not null references public.drills(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  revoked_at  timestamptz,
  imports     integer not null default 0
);
create index if not exists drill_shares_drill_idx on public.drill_shares (drill_id);
alter table public.drill_shares enable row level security;
revoke all on public.drill_shares from public, anon, authenticated;
grant all on public.drill_shares to service_role;
