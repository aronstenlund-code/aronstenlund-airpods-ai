-- K72 (O67 fynd 1): the language a text drill is read in, from the text itself ("sv", "English", ...); null = by
-- the subject as before (question drills).
alter table public.drills add column if not exists language text check (language is null or char_length(language) <= 20);
