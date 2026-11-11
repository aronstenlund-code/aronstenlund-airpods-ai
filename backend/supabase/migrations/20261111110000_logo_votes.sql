-- K39 (D127, owner): users vote on the logo in the app (A54). One vote per user, can be changed. Only the anonymous
-- Supabase user id, the choice and the time: no other personal data. Service role only (RLS on, no client grants):
-- the app votes through /functions/v1/logo-vote, which sees only the caller's own vote, and Aron sees the totals on
-- his private page (backend/webtest/qa.html).

create table if not exists public.logo_votes (
  user_id     uuid primary key,
  choice      text not null check (choice in ('A', 'B', 'C')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.logo_votes enable row level security;
revoke all on public.logo_votes from public, anon, authenticated;
grant all on public.logo_votes to service_role;

-- one vote per user: insert or change it (updated_at moves, created_at stays)
create or replace function public.cast_logo_vote(p_user uuid, p_choice text) returns text
language sql security invoker set search_path = public as $$
  insert into public.logo_votes (user_id, choice) values (p_user, p_choice)
  on conflict (user_id) do update set choice = excluded.choice, updated_at = now()
  returning choice;
$$;

create or replace function public.logo_vote_counts() returns table (choice text, votes bigint)
language sql stable security invoker set search_path = public as $$
  select c.choice, count(v.user_id) from (values ('A'), ('B'), ('C')) as c(choice)
  left join public.logo_votes v on v.choice = c.choice group by c.choice order by c.choice;
$$;

revoke all on function public.cast_logo_vote(uuid, text) from public, anon, authenticated;
revoke all on function public.logo_vote_counts() from public, anon, authenticated;
grant execute on function public.cast_logo_vote(uuid, text) to service_role;
grant execute on function public.logo_vote_counts() to service_role;
