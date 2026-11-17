-- K95/K96 (D220): a drill's style ("Hur ska det låta?") and its own voice.
alter table public.drills add column if not exists style text;
alter table public.drills add column if not exists voice_id text;
