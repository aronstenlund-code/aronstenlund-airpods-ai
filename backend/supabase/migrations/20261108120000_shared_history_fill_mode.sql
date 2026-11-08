-- 2026-11-08 (owner, from Aron's shared history): mode and persona were null on every row (older app builds do
-- not send them). A row that arrives without them gets them from the same user's nearest answer_usage row
-- (answers are uploaded right after they are given). The 34 existing rows were back-filled the same way.
create or replace function public.shared_history_fill_mode() returns trigger
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if new.mode is not null and new.persona is not null then
    return new;
  end if;
  select a.mode, a.persona into r
    from public.answer_usage a
   where a.user_id = new.user_id and a.endpoint = 'answer'
     and a.created_at between coalesce(new.created_at, now()) - interval '3 minutes' and coalesce(new.created_at, now()) + interval '5 seconds'
   order by a.created_at desc
   limit 1;
  if found then
    new.mode := coalesce(new.mode, r.mode);
    new.persona := coalesce(new.persona, r.persona);
  end if;
  return new;
end $$;
revoke all on function public.shared_history_fill_mode() from public, anon, authenticated;

drop trigger if exists shared_history_fill_mode on public.shared_history;
create trigger shared_history_fill_mode before insert on public.shared_history
  for each row execute function public.shared_history_fill_mode();
