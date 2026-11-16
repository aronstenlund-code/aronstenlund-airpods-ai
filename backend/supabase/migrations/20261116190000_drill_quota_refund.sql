-- K78 (D200): out of ElevenLabs credits costs the user nothing. Questions counted at Starta prov whose audio then failed
-- for lack of credits are given back once (drills.refunded = how many of this drill's questions were given back).
alter table public.drills add column if not exists refunded integer not null default 0 check (refunded >= 0);

create or replace function public.refund_drill_quota(p_user uuid, p_n integer)
returns table (used integer)
language plpgsql security invoker set search_path = public as $$
begin
  if p_n <= 0 then
    return query select coalesce((select generated from public.drill_quota where user_id = p_user), 0);
    return;
  end if;
  update public.drill_quota set generated = greatest(0, generated - p_n), updated_at = now() where user_id = p_user;
  return query select coalesce((select generated from public.drill_quota where user_id = p_user), 0);
end $$;
revoke all on function public.refund_drill_quota(uuid, integer) from public, anon, authenticated;
grant execute on function public.refund_drill_quota(uuid, integer) to service_role;
