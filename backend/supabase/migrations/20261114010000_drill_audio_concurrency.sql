-- K55 (live 2026-11-14: 15 of 30 files failed): Aron's ElevenLabs plan allows at most 3 concurrent requests, and every
-- /drill status call started its own generator. The claim now keeps a global cap (drill_settings.tts_concurrency,
-- default 2, leaving one for the app's live voice), serialised by an advisory lock. Files that failed on 429 were put
-- back in the queue. Applied as migration drill_audio_concurrency.
insert into public.drill_settings (key, value) values ('tts_concurrency', 2) on conflict (key) do nothing;

create or replace function public.claim_drill_audio(n integer) returns setof public.drill_audio_files
language plpgsql security invoker set search_path = public as $$
declare cap integer; busy integer; free integer;
begin
  perform pg_advisory_xact_lock(hashtext('claim_drill_audio'));
  select value into cap from public.drill_settings where key = 'tts_concurrency';
  cap := coalesce(cap, 2);
  select count(*) into busy from public.drill_audio_files where status = 'working' and claimed_at > now() - interval '3 minutes';
  free := greatest(0, least(n, 10, cap - busy));
  if free = 0 then
    return;
  end if;
  return query
  update public.drill_audio_files f
     set status = 'working', claimed_at = now(), attempts = f.attempts + 1
   where f.hash in (
     select hash from public.drill_audio_files
      where (status = 'pending' or (status = 'working' and claimed_at < now() - interval '3 minutes'))
        and attempts < 3
      order by queued_at, seq
      limit free
      for update skip locked)
  returning f.*;
end $$;
revoke all on function public.claim_drill_audio(integer) from public, anon, authenticated;
grant execute on function public.claim_drill_audio(integer) to service_role;

update public.drill_audio_files set status = 'pending', attempts = 0, error = null
 where status = 'failed' and error like 'elevenlabs 429%';
