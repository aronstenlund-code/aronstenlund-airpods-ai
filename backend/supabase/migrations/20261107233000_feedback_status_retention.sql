-- D80 (owner): feedback rows get a status. The owner marks a row `processed` once the reported problem is
-- fixed (POST /feedback-admin {id, status:"processed"}); processed rows are deleted by the hourly purge.
-- Rows that are never processed are deleted at the latest 90 days after they were sent.
alter table public.feedback
  add column if not exists status text not null default 'new' check (status in ('new', 'processed')),
  add column if not exists processed_at timestamptz;

create or replace view public.feedback_admin with (security_invoker = true) as
select id, created_at, type, install_id, mode, persona, app_version, fragment, answer, comment, timings, status
from public.feedback
order by created_at desc;
revoke all on public.feedback_admin from public, anon, authenticated;
grant select on public.feedback_admin to service_role;

create or replace function public.mark_feedback_processed(p_id uuid) returns boolean
language plpgsql security invoker set search_path = public as $$
begin
  update public.feedback set status = 'processed', processed_at = now() where id = p_id;
  return found;
end $$;
revoke all on function public.mark_feedback_processed(uuid) from public, anon, authenticated;
grant execute on function public.mark_feedback_processed(uuid) to service_role;

create or replace function public.purge_feedback() returns bigint
language plpgsql security invoker set search_path = public as $$
declare n bigint;
begin
  delete from public.feedback
   where status = 'processed' or created_at < now() - interval '90 days';
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.purge_feedback() from public, anon, authenticated;
grant execute on function public.purge_feedback() to service_role;

select cron.schedule('purge-feedback', '41 * * * *', $$select public.purge_feedback()$$);
