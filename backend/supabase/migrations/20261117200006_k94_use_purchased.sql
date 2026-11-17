-- K94: take n bought credits if there are that many (one at a time per account: advisory lock).
create or replace function public.use_purchased_credits(p_user uuid, p_n integer) returns boolean
language plpgsql security invoker set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext('credits:' || p_user::text));
  if p_n <= 0 or public.credit_balance(p_user) < p_n then return false; end if;
  insert into public.credit_ledger (user_id, kind, credits) values (p_user, 'use', -p_n);
  return true;
end $$;
revoke all on function public.use_purchased_credits(uuid, integer) from public, anon, authenticated;
grant execute on function public.use_purchased_credits(uuid, integer) to service_role;
