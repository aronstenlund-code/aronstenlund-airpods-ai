-- K46 (D142, D143, D144, D145): Repetitionsläget. A drill (prov) and its questions are stored per account; the audio
-- is generated once per text, voice and model and shared by every account (the file name is a hash, D144), so the same
-- text is never paid for twice. The material (photos, documents) is never stored (B4).
-- Writes go through /functions/v1/drill (service role, which computes the hashes and queues the audio); the owner
-- may also read and delete their own rows directly (RLS). drill_audio_files is service role only.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('drill_audio', 'drill_audio', false, 5242880, array['audio/mpeg'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.drills (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  title        text not null default '' check (char_length(title) <= 120),
  subject      text not null default '' check (char_length(subject) <= 60),
  grade        text not null default '' check (char_length(grade) <= 60),
  covers       text not null default '' check (char_length(covers) <= 400),
  long_words   integer not null default 90 check (long_words between 40 and 200),
  shared_from  uuid,                       -- K47: the original drill when this is an imported copy
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists drills_user_idx on public.drills (user_id, updated_at desc);

create table if not exists public.drill_items (
  id            uuid primary key default gen_random_uuid(),
  drill_id      uuid not null references public.drills(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  position      integer not null check (position >= 0),
  question      text not null check (char_length(question) between 1 and 300),
  short         text not null default '' check (char_length(short) <= 600),
  long          text not null default '' check (char_length(long) <= 3000),
  question_hash text check (question_hash ~ '^[0-9a-f]{64}$'),
  long_hash     text check (long_hash ~ '^[0-9a-f]{64}$'),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists drill_items_drill_idx on public.drill_items (drill_id, position);

-- one row per audio file, shared by all accounts
create table if not exists public.drill_audio_files (
  hash         text primary key check (hash ~ '^[0-9a-f]{64}$'),
  kind         text not null check (kind in ('question', 'long')),
  text         text not null check (char_length(text) between 1 and 4000),  -- exactly what is sent to the voice
  short_chars  integer,                     -- long: the short answer is text[0, short_chars) (D145)
  model        text not null check (char_length(model) <= 60),
  voice_id     text not null check (char_length(voice_id) <= 60),
  status       text not null default 'pending' check (status in ('pending', 'working', 'done', 'failed')),
  attempts     integer not null default 0,
  error        text check (char_length(error) <= 300),
  chars        integer,                     -- characters billed (the text's length)
  bytes        integer,
  duration_ms  integer,
  short_end_ms integer,                     -- long: where the short answer ends in the file
  words        jsonb,                       -- [[start_ms, end_ms], ...] per word, from ElevenLabs' timestamps
  queued_at    timestamptz not null default now(),
  seq          integer not null default 0,  -- play order within one save (position * 2 + kind)
  claimed_at   timestamptz,
  done_at      timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists drill_audio_queue_idx on public.drill_audio_files (status, queued_at, seq);

alter table public.drills enable row level security;
alter table public.drill_items enable row level security;
alter table public.drill_audio_files enable row level security;
revoke all on public.drills, public.drill_items, public.drill_audio_files from public, anon, authenticated;
grant select, delete on public.drills, public.drill_items to authenticated;
grant all on public.drills, public.drill_items, public.drill_audio_files to service_role;

drop policy if exists drills_owner_read on public.drills;
create policy drills_owner_read on public.drills for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists drills_owner_delete on public.drills;
create policy drills_owner_delete on public.drills for delete to authenticated using (user_id = (select auth.uid()));
drop policy if exists drill_items_owner_read on public.drill_items;
create policy drill_items_owner_read on public.drill_items for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists drill_items_owner_delete on public.drill_items;
create policy drill_items_owner_delete on public.drill_items for delete to authenticated using (user_id = (select auth.uid()));

-- the generator takes the next files in play order; a file stuck in 'working' for 3 minutes is taken again
create or replace function public.claim_drill_audio(n integer) returns setof public.drill_audio_files
language sql security invoker set search_path = public as $$
  update public.drill_audio_files f
     set status = 'working', claimed_at = now(), attempts = f.attempts + 1
   where f.hash in (
     select hash from public.drill_audio_files
      where (status = 'pending' or (status = 'working' and claimed_at < now() - interval '3 minutes'))
        and attempts < 3
      order by queued_at, seq
      limit greatest(1, least(n, 10))
      for update skip locked)
  returning f.*;
$$;
revoke all on function public.claim_drill_audio(integer) from public, anon, authenticated;
grant execute on function public.claim_drill_audio(integer) to service_role;
