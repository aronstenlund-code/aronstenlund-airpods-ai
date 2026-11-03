-- One round trip for several windows (minute/day/global). All-or-nothing: if one window denies,
-- the units already taken from the earlier windows are given back.
create or replace function public.check_rate_limits(
  p_keys text[], p_limits integer[], p_windows integer[], p_cost integer default 1
) returns table (allowed boolean, denied_key text, retry_after integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  i integer;
  j integer;
  r record;
begin
  if array_length(p_keys, 1) is distinct from array_length(p_limits, 1)
     or array_length(p_keys, 1) is distinct from array_length(p_windows, 1) then
    raise exception 'array length mismatch';
  end if;
  for i in 1 .. coalesce(array_length(p_keys, 1), 0) loop
    select * into r from public.check_rate_limit(p_keys[i], p_limits[i], p_windows[i], p_cost);
    if not r.allowed then
      for j in 1 .. i - 1 loop
        update public.rate_limits
           set count = count - p_cost
         where key = p_keys[j]
           and window_start = to_timestamp(floor(extract(epoch from now()) / p_windows[j]) * p_windows[j]);
      end loop;
      return query select false, p_keys[i], r.retry_after;
      return;
    end if;
  end loop;
  return query select true, null::text, 0;
end;
$$;
revoke all on function public.check_rate_limits(text[], integer[], integer[], integer) from public, anon, authenticated;
grant execute on function public.check_rate_limits(text[], integer[], integer[], integer) to service_role;
