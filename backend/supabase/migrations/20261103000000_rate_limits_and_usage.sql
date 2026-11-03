-- Rate limiting (fixed window, atomic) and per-request usage log for Lumen backend.
-- Only the Edge Functions (service_role) may touch these objects.

create table if not exists public.rate_limits (
  key          text        not null,
  window_start timestamptz not null,
  count        integer     not null default 0,
  primary key (key, window_start)
);
create index if not exists rate_limits_window_idx on public.rate_limits (window_start);
alter table public.rate_limits enable row level security;  -- no policies: anon/authenticated get nothing

create or replace function public.check_rate_limit(
  p_key text, p_limit integer, p_window_seconds integer, p_cost integer default 1
) returns table (allowed boolean, current_count integer, retry_after integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_now    timestamptz := now();
  v_start  timestamptz := to_timestamp(floor(extract(epoch from v_now) / p_window_seconds) * p_window_seconds);
  v_count  integer;
begin
  -- Opportunistic cleanup (1 in 50 calls) so the table stays tiny without pg_cron.
  if random() < 0.02 then
    delete from public.rate_limits where window_start < v_now - interval '3 days';
  end if;

  insert into public.rate_limits as r (key, window_start, count)
  values (p_key, v_start, p_cost)
  on conflict (key, window_start)
  do update set count = r.count + p_cost
  returning r.count into v_count;

  if v_count > p_limit then
    -- Over the limit: give the units back so a denied request does not burn budget.
    update public.rate_limits set count = count - p_cost where key = p_key and window_start = v_start;
    return query select false, v_count - p_cost,
      greatest(1, ceil(extract(epoch from (v_start + make_interval(secs => p_window_seconds) - v_now)))::integer);
    return;
  end if;
  return query select true, v_count, 0;
end;
$$;
revoke all on function public.check_rate_limit(text, integer, integer, integer) from public, anon, authenticated;
grant execute on function public.check_rate_limit(text, integer, integer, integer) to service_role;

create table if not exists public.answer_usage (
  id            bigint generated always as identity primary key,
  created_at    timestamptz not null default now(),
  user_id       uuid        not null,
  endpoint      text        not null,            -- 'answer' | 'tts'
  mode          text,
  language      text,
  provider      text,
  model         text,
  is_question   boolean,
  confidence    real,
  input_tokens  integer,
  output_tokens integer,
  chars         integer,                         -- tts: characters sent to ElevenLabs
  ttft_ms       integer,                         -- request received -> first delta
  total_ms      integer,
  est_cost_usd  numeric(12,8),
  status        text        not null             -- 'ok' | 'not_question' | 'provider_error' | ...
);
create index if not exists answer_usage_created_idx on public.answer_usage (created_at desc);
create index if not exists answer_usage_user_idx on public.answer_usage (user_id, created_at desc);
alter table public.answer_usage enable row level security;  -- service_role only
