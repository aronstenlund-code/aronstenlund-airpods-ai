-- K43 (D140, owner): test mode sends the audio of each turn to us, ONLY for Aron's account and testers who turn it on
-- themselves (everyone else: no audio is ever stored, CLAUDE.md). Private bucket and table, service role only (RLS on,
-- no client grants); the app uploads through /functions/v1/debug-audio. Everything is deleted after 14 days.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('debug_audio', 'debug_audio', false, 2097152,
        array['audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/aac', 'audio/wav', 'audio/x-wav', 'audio/mpeg', 'audio/ogg', 'audio/webm', 'audio/flac'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- testers who turned test mode on themselves (signed in by email; Aron is a tester through OWNER_EMAIL)
create table if not exists public.debug_testers (
  user_id     uuid primary key,
  created_at  timestamptz not null default now()
);
alter table public.debug_testers enable row level security;
revoke all on public.debug_testers from public, anon, authenticated;
grant all on public.debug_testers to service_role;

create table if not exists public.debug_turns (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  user_id     uuid not null,
  turn_id     text check (char_length(turn_id) <= 64),
  mode        text check (char_length(mode) <= 32),
  audio_path  text check (char_length(audio_path) <= 200),
  audio_bytes integer,
  transcript  text check (char_length(transcript) <= 4000),
  words       jsonb,
  decision    text check (char_length(decision) <= 64),
  answer      text check (char_length(answer) <= 6000),
  meta        jsonb
);
create index if not exists debug_turns_created_idx on public.debug_turns (created_at);
alter table public.debug_turns enable row level security;
revoke all on public.debug_turns from public, anon, authenticated;
grant all on public.debug_turns to service_role;

create or replace function public.purge_debug_turns() returns bigint
language plpgsql security invoker set search_path = public as $$
declare n bigint;
begin
  delete from public.debug_turns where created_at < now() - interval '14 days';
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.purge_debug_turns() from public, anon, authenticated;
grant execute on function public.purge_debug_turns() to service_role;

-- rows by SQL; the audio files through the Storage API (direct deletes in storage.objects are not allowed), so the job
-- also calls the function's purge action, which removes only date folders older than 14 days (needs no login)
select cron.schedule('purge-debug-turns', '23 * * * *', $$select public.purge_debug_turns()$$);
select cron.schedule('purge-debug-audio', '27 * * * *',
  $$select net.http_post(url := 'https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/debug-audio?action=purge', body := '{}'::jsonb, headers := '{"content-type": "application/json"}'::jsonb)$$);
