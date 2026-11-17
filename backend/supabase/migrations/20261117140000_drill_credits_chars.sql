-- K90 (D213): credits per character of new audio instead of questions. 1 credit = 1 character of text that gets
-- new audio; audio that already exists and repeats cost 0. 1 500 a calendar month (Swedish time), set in
-- drill_settings without code. The counter starts at 0 for everyone now; old question counts are not converted.
alter table public.drill_quota add column if not exists chars integer not null default 0 check (chars >= 0);
alter table public.drill_quota add column if not exists chars_period text not null default to_char(now() at time zone 'Europe/Stockholm', 'YYYY-MM');
insert into public.drill_settings (key, value) values ('free_chars_per_month', 1500) on conflict (key) do nothing;
-- what a drill was charged and given back in characters (refunds only ever give back what was charged in chars)
alter table public.drills add column if not exists charged_chars integer not null default 0 check (charged_chars >= 0);
alter table public.drills add column if not exists refunded_chars integer not null default 0 check (refunded_chars >= 0);

create or replace function public.use_drill_chars(p_user uuid, p_n integer)
returns table (ok boolean, used integer, lim integer)
language plpgsql security invoker set search_path = public as $$
declare l integer; u integer; per text; cur text := to_char(now() at time zone 'Europe/Stockholm', 'YYYY-MM');
begin
  select value into l from public.drill_settings where key = 'free_chars_per_month';
  l := coalesce(l, 1500);
  insert into public.drill_quota (user_id, period, chars_period) values (p_user, cur, cur) on conflict (user_id) do nothing;
  select chars, chars_period into u, per from public.drill_quota where user_id = p_user for update;
  if per is distinct from cur then
    update public.drill_quota set chars = 0, chars_period = cur, updated_at = now() where user_id = p_user;
    u := 0;
  end if;
  if p_n <= 0 then
    return query select true, u, l;
  elsif u + p_n <= l then
    update public.drill_quota set chars = chars + p_n, updated_at = now() where user_id = p_user;
    return query select true, u + p_n, l;
  else
    return query select false, u, l;
  end if;
end $$;
revoke all on function public.use_drill_chars(uuid, integer) from public, anon, authenticated;
grant execute on function public.use_drill_chars(uuid, integer) to service_role;

create or replace function public.refund_drill_chars(p_user uuid, p_n integer)
returns table (used integer)
language plpgsql security invoker set search_path = public as $$
begin
  if p_n > 0 then
    update public.drill_quota set chars = greatest(0, chars - p_n), updated_at = now() where user_id = p_user;
  end if;
  return query select coalesce((select chars from public.drill_quota where user_id = p_user), 0);
end $$;
revoke all on function public.refund_drill_chars(uuid, integer) from public, anon, authenticated;
grant execute on function public.refund_drill_chars(uuid, integer) to service_role;
