-- K98: invitation codes and claims (one per invitee). service_role only.
create table if not exists public.invite_codes (code text primary key,
  user_id uuid not null unique references auth.users (id) on delete cascade);
create table if not exists public.invite_claims (invitee_id uuid primary key references auth.users (id) on delete cascade,
  inviter_id uuid not null, created_at timestamptz not null default now(), rewarded_at timestamptz);
alter table public.invite_codes enable row level security;
alter table public.invite_claims enable row level security;
revoke all on public.invite_codes, public.invite_claims from public, anon, authenticated;
