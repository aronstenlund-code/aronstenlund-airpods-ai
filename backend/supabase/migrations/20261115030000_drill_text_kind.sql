-- K70 (D185): Läsläget. A drill is either questions (as before) or a running text read aloud. A text drill's items are
-- its parts in order (a heading or a paragraph, `part`); each part has ONE audio file (kind 'text', question_hash =
-- long_hash) with times per sentence, so the app can pause at, skip to and mark a sentence. The file is shared by hash
-- (D144) like every other file. Quota: every started N characters of new audio count as one question
-- (drill_settings.text_chars_per_question, 800 until Aron says otherwise).
alter table public.drills add column if not exists kind text not null default 'questions' check (kind in ('questions', 'text'));
alter table public.drill_items add column if not exists part text check (part is null or part in ('heading', 'para'));
-- a text part has no question; a question item still needs one (checked in /drill)
alter table public.drill_items drop constraint if exists drill_items_question_check;
alter table public.drill_items add constraint drill_items_question_check check (char_length(question) <= 300);
-- K60 keeps a long answer up to 4 000 characters in /drill (the table still said 3 000)
alter table public.drill_items drop constraint if exists drill_items_long_check;
alter table public.drill_items add constraint drill_items_long_check check (char_length(long) <= 4000);
alter table public.drill_audio_files drop constraint if exists drill_audio_files_kind_check;
alter table public.drill_audio_files add constraint drill_audio_files_kind_check check (kind in ('question', 'long', 'text'));
-- the character where each sentence of the spoken text ends (set when queued), and [[start_ms, end_ms], ...] per
-- sentence (set when made, from ElevenLabs' character times)
alter table public.drill_audio_files add column if not exists sentence_ends integer[];
alter table public.drill_audio_files add column if not exists sentences jsonb;
insert into public.drill_settings (key, value) values ('text_chars_per_question', 800) on conflict (key) do nothing;
