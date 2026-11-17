-- K93 (D216): accounts with unlimited credits (Aron). Only service_role reaches the table (RLS on, no policies,
-- no grants to anon/authenticated); no list in code or app. Rows are added by an agent on Aron's word, never by the app.
create table if not exists public.credit_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  note text,
  created_at timestamptz not null default now()
);
alter table public.credit_admins enable row level security;
revoke all on public.credit_admins from public, anon, authenticated;

create or replace function public.is_credit_admin(p_user uuid)
returns boolean
language sql stable security invoker set search_path = public as $$
  select exists (select 1 from public.credit_admins where user_id = p_user)
$$;
revoke all on function public.is_credit_admin(uuid) from public, anon, authenticated;
grant execute on function public.is_credit_admin(uuid) to service_role;
