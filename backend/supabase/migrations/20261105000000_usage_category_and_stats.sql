-- D49: anonymous usage insight. Only a fixed category + persona per request, never any text.
-- (Applied to project Lumen via the Supabase MCP on 2026-11-05.)
alter table public.answer_usage
  add column if not exists category text,
  add column if not exists persona text;
create index if not exists answer_usage_cat_idx on public.answer_usage (created_at desc, category);

create or replace view public.usage_by_category_day
with (security_invoker = true) as
select
  (created_at at time zone 'Europe/Stockholm')::date as day,
  coalesce(category, 'okänd')                         as category,
  count(*)                                            as requests,
  round(avg(ttft_ms))::int                            as avg_ttft_ms,
  sum(input_tokens)                                   as input_tokens,
  sum(output_tokens)                                  as output_tokens,
  round(sum(est_cost_usd)::numeric, 4)                as est_cost_usd
from public.answer_usage
where endpoint = 'answer'
group by 1, 2
order by 1 desc, 3 desc;

revoke all on public.usage_by_category_day from public, anon, authenticated;
grant select on public.usage_by_category_day to service_role;

create or replace function public.usage_stats(p_days int default 14)
returns table (day date, category text, requests bigint, avg_ttft_ms int,
               input_tokens bigint, output_tokens bigint, est_cost_usd numeric)
language sql stable security invoker set search_path = public as $$
  select * from public.usage_by_category_day
  where day >= (now() at time zone 'Europe/Stockholm')::date - greatest(1, least(p_days, 366))
$$;
revoke all on function public.usage_stats(int) from public, anon, authenticated;
grant execute on function public.usage_stats(int) to service_role;
