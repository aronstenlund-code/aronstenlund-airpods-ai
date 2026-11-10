-- K30 (D116, owner): every question and answer goes to Aron for analysis and is deleted once he has fetched it,
-- at the latest after 14 days. Never to git (B4). Service role only: RLS on, no client grants at all.
-- Personnummer, card and account numbers are masked by /answer before a row is written (answer/qalog.ts).
-- No user id, no install id, no audio: mode, persona, time, question, answer.

create table if not exists public.qa_log (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  mode        text check (char_length(mode) <= 32),
  persona     text check (char_length(persona) <= 32),
  question    text not null check (char_length(question) <= 1000),
  answer      text not null check (char_length(answer) <= 6000)
);
create index if not exists qa_log_created_idx on public.qa_log (created_at);

alter table public.qa_log enable row level security;
revoke all on public.qa_log from public, anon, authenticated;
grant all on public.qa_log to service_role;

create or replace function public.purge_qa_log() returns bigint
language plpgsql security invoker set search_path = public as $$
declare n bigint;
begin
  delete from public.qa_log where created_at < now() - interval '14 days';
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.purge_qa_log() from public, anon, authenticated;
grant execute on function public.purge_qa_log() to service_role;

select cron.schedule('purge-qa-log', '17 * * * *', $$select public.purge_qa_log()$$);
