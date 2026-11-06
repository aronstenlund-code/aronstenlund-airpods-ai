-- D57: feedback (user-triggered reports, app feedback, suggestions) and opt-in shared history.
-- One migration. Both tables: RLS on, insert-own-only policy, NO client select/update/delete.
-- The Edge Functions `feedback` / `shared-history` / `feedback-admin` use the service role and set
-- user_id from the verified JWT. Never mixed with answer_usage (D49 anonymous category stats).

create table if not exists public.feedback (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  user_id     uuid not null default auth.uid(),
  install_id  text not null check (install_id ~ '^[A-Za-z0-9_-]{8,64}$'),
  type        text not null default 'report' check (type in ('report', 'app', 'suggestion')),
  fragment    text check (char_length(fragment) <= 1000),
  answer      text check (char_length(answer) <= 4000),
  comment     text check (char_length(comment) <= 2000),
  mode        text check (char_length(mode) <= 32),
  persona     text check (char_length(persona) <= 32),
  timings     jsonb,
  app_version text check (char_length(app_version) <= 32)
);
create index if not exists feedback_created_idx on public.feedback (created_at desc);
create index if not exists feedback_user_idx on public.feedback (user_id);

create table if not exists public.shared_history (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  user_id     uuid not null default auth.uid(),
  install_id  text not null check (install_id ~ '^[A-Za-z0-9_-]{8,64}$'),
  fragment    text not null check (char_length(fragment) <= 1000),
  answer      text not null check (char_length(answer) <= 4000),
  summary     text check (char_length(summary) <= 600),
  mode        text check (char_length(mode) <= 32),
  persona     text check (char_length(persona) <= 32)
);
create index if not exists shared_history_created_idx on public.shared_history (created_at);
create index if not exists shared_history_user_idx on public.shared_history (user_id);
create index if not exists shared_history_install_idx on public.shared_history (install_id);

alter table public.feedback enable row level security;
alter table public.shared_history enable row level security;

revoke all on public.feedback, public.shared_history from public, anon, authenticated;
grant insert on public.feedback, public.shared_history to authenticated;
grant all on public.feedback, public.shared_history to service_role;

drop policy if exists feedback_insert_own on public.feedback;
create policy feedback_insert_own on public.feedback
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists shared_history_insert_own on public.shared_history;
create policy shared_history_insert_own on public.shared_history
  for insert to authenticated with check (user_id = auth.uid());

-- Owner view (service role only): latest feedback, newest first.
create or replace view public.feedback_admin with (security_invoker = true) as
select id, created_at, type, install_id, mode, persona, app_version, fragment, answer, comment, timings
from public.feedback
order by created_at desc;
revoke all on public.feedback_admin from public, anon, authenticated;
grant select on public.feedback_admin to service_role;

-- Retention: shared history is kept at most 12 months.
create or replace function public.purge_shared_history() returns bigint
language plpgsql security invoker set search_path = public as $$
declare n bigint;
begin
  delete from public.shared_history where created_at < now() - interval '12 months';
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.purge_shared_history() from public, anon, authenticated;
grant execute on function public.purge_shared_history() to service_role;

create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('purge-shared-history', '17 3 * * *', $$select public.purge_shared_history()$$);
