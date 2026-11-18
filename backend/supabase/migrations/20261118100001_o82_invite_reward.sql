-- O82 F1: the month's invitation cap, the claim and the credits in one transaction (service_role only).
create or replace function public.invite_reward(p_invitee uuid, p_credits integer, p_max integer) returns integer
language plpgsql security invoker set search_path = public as $$
declare inv uuid; done timestamptz; n integer;
begin
  select inviter_id, rewarded_at into inv, done from public.invite_claims where invitee_id = p_invitee for update;
  if inv is null or done is not null then return 0; end if;
  perform pg_advisory_xact_lock(hashtext('invite:' || inv::text));
  select count(*) into n from public.credit_ledger where user_id = inv and kind = 'invite'
    and created_at >= date_trunc('month', now() at time zone 'Europe/Stockholm') at time zone 'Europe/Stockholm';
  if n >= p_max then return -1; end if;
  update public.invite_claims set rewarded_at = now() where invitee_id = p_invitee;
  insert into public.credit_ledger (user_id, kind, transaction_id, credits)
    values (inv, 'invite', 'invite:' || p_invitee::text, p_credits) on conflict (transaction_id) do nothing;
  return p_credits;
end $$;
revoke all on function public.invite_reward(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.invite_reward(uuid, integer, integer) to service_role;
