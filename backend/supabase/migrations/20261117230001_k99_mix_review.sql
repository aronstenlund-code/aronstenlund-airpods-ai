-- K99 (D223): "Blanda röster" (a drill's flag, each item's voice) and voices under review (admin only).
alter table public.drills add column if not exists mix_voices boolean not null default false;
alter table public.drill_items add column if not exists voice_id text;
alter table public.voice_catalog add column if not exists review boolean not null default false;
