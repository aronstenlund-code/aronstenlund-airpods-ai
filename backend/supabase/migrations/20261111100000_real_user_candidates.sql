-- K38 (Oscar O36): the weekly K22 candidates (general questions real users chose to share, D57) used to be an Actions
-- artifact, which anyone signed in to GitHub can download from a public repo. They now live here instead: service role
-- only (RLS on, no client grants), read and decided on Aron's private page (/functions/v1/real-users-admin, owner
-- email + email sign-in) or by Oscar through the Supabase MCP. Only rows with decision 'approved' ever reach git, and
-- only through `scripts/real_users.py --approve-db` (the "approve" run of .github/workflows/real-users.yml), which
-- filters them once more and then deletes them here. No user id, no install id: the text, the mode and two counts.

create table if not exists public.real_user_candidates (
  id          text primary key check (char_length(id) <= 40),           -- real_users.case_id(): mode + normalised text
  created_at  timestamptz not null default now(),
  week        date not null,
  q           text not null check (char_length(q) <= 300),
  mode        text not null check (mode in ('fragor', 'prov')),
  installs    int  not null check (installs >= 0),
  count       int  not null check (count >= 0),
  decision    text check (decision in ('approved', 'rejected')),         -- null = waiting for a person
  decided_at  timestamptz
);
create index if not exists real_user_candidates_created_idx on public.real_user_candidates (created_at);

alter table public.real_user_candidates enable row level security;
revoke all on public.real_user_candidates from public, anon, authenticated;
grant all on public.real_user_candidates to service_role;

-- Waiting and approved rows go after 30 days (a candidate nobody looked at is not kept); rejected rows are kept 90 days
-- so the same question is not offered again every week, then they go too.
create or replace function public.purge_real_user_candidates() returns bigint
language plpgsql security invoker set search_path = public as $$
declare n bigint;
begin
  delete from public.real_user_candidates
   where (decision is distinct from 'rejected' and created_at < now() - interval '30 days')
      or (decision = 'rejected' and created_at < now() - interval '90 days');
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.purge_real_user_candidates() from public, anon, authenticated;
grant execute on function public.purge_real_user_candidates() to service_role;

select cron.schedule('purge-real-user-candidates', '29 3 * * *', $$select public.purge_real_user_candidates()$$);
