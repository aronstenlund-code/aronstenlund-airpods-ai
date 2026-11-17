-- K94: bought credits left = the ledger's sum (purchases +, refunds -, use -).
create or replace function public.credit_balance(p_user uuid) returns integer
language sql stable security invoker set search_path = public as $$
  select coalesce(sum(credits), 0)::integer from public.credit_ledger where user_id = p_user
$$;
revoke all on function public.credit_balance(uuid) from public, anon, authenticated;
grant execute on function public.credit_balance(uuid) to service_role;
