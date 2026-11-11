-- K41 (D129/D130 owner): six logos A-F in the vote. Existing votes (A-C) are kept as they are.
alter table public.logo_votes drop constraint if exists logo_votes_choice_check;
alter table public.logo_votes add constraint logo_votes_choice_check check (choice in ('A', 'B', 'C', 'D', 'E', 'F'));

create or replace function public.logo_vote_counts() returns table (choice text, votes bigint)
language sql stable security invoker set search_path = public as $$
  select c.choice, count(v.user_id) from (values ('A'), ('B'), ('C'), ('D'), ('E'), ('F')) as c(choice)
  left join public.logo_votes v on v.choice = c.choice group by c.choice order by c.choice;
$$;
revoke all on function public.logo_vote_counts() from public, anon, authenticated;
grant execute on function public.logo_vote_counts() to service_role;
