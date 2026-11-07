-- D80: an answer the client aborts (the app's preliminary answer is redone when the user keeps talking)
-- does not count against the user's own minute/day allowance. The handler gives the units back in the
-- window the request was counted in (p_at), never below zero. Network, global and new-user windows are
-- not released, so aborting cannot be used to get free answers.
create or replace function public.release_rate_limits(
  p_keys text[], p_windows integer[], p_cost integer, p_at timestamptz
) returns void
language sql
security definer
set search_path = public
as $$
  update public.rate_limits r
     set count = greatest(0, r.count - p_cost)
    from unnest(p_keys, p_windows) as k(key, win)
   where r.key = k.key
     and r.window_start = to_timestamp(floor(extract(epoch from p_at) / k.win) * k.win);
$$;
revoke all on function public.release_rate_limits(text[], integer[], integer, timestamptz) from public, anon, authenticated;
grant execute on function public.release_rate_limits(text[], integer[], integer, timestamptz) to service_role;
