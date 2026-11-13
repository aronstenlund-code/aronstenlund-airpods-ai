-- K52 (D155): the limit is 15 generated questions per account and calendar month (Swedish time), not 30 in total.
-- The counter starts again when the month changes. Applied as migration drill_quota_month.
alter table public.drill_quota add column if not exists period text not null default to_char(now() at time zone 'Europe/Stockholm', 'YYYY-MM');
update public.drill_settings set value = 15 where key = 'free_generated_questions';
insert into public.drill_settings (key, value) values ('free_generated_questions', 15) on conflict (key) do nothing;

create or replace function public.use_drill_quota(p_user uuid, p_n integer)
returns table (ok boolean, used integer, lim integer)
language plpgsql security invoker set search_path = public as $$
declare l integer; u integer; e integer; per text; cur text := to_char(now() at time zone 'Europe/Stockholm', 'YYYY-MM');
begin
  select value into l from public.drill_settings where key = 'free_generated_questions';
  l := coalesce(l, 15);
  insert into public.drill_quota (user_id, period) values (p_user, cur) on conflict (user_id) do nothing;
  select generated, extra, period into u, e, per from public.drill_quota where user_id = p_user for update;
  if per is distinct from cur then
    update public.drill_quota set generated = 0, period = cur, updated_at = now() where user_id = p_user;
    u := 0;
  end if;
  if p_n <= 0 then
    return query select true, u, l + e;
  elsif u + p_n <= l + e then
    update public.drill_quota set generated = generated + p_n, updated_at = now() where user_id = p_user;
    return query select true, u + p_n, l + e;
  else
    return query select false, u, l + e;
  end if;
end $$;
revoke all on function public.use_drill_quota(uuid, integer) from public, anon, authenticated;
grant execute on function public.use_drill_quota(uuid, integer) to service_role;
