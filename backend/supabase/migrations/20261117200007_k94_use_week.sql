-- K94: this ISO week's subscription characters; n < 0 gives back; n = 0 reads.
create or replace function public.use_week_chars(p_user uuid, p_n integer, p_lim integer)
returns table (ok boolean, used integer)
language plpgsql security invoker set search_path = public as $$
declare u integer; per text; cur text := to_char(now() at time zone 'Europe/Stockholm', 'IYYY-IW');
begin
  insert into public.drill_quota (user_id) values (p_user) on conflict (user_id) do nothing;
  select week_chars, week_period into u, per from public.drill_quota where user_id = p_user for update;
  if per is distinct from cur then u := 0; end if;
  if p_n > 0 and u + p_n > p_lim then return query select false, u; return; end if;
  u := greatest(0, u + p_n);
  update public.drill_quota set week_chars = u, week_period = cur, updated_at = now() where user_id = p_user;
  return query select true, u;
end $$;
revoke all on function public.use_week_chars(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.use_week_chars(uuid, integer, integer) to service_role;
