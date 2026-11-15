-- K74: the voice text's rules version per drill (1 = before K74: old drills keep their hashes, so editing or
-- starting them makes nothing again; /drill writes 2 for new drills). eleven_v4 is allowed by the table only when
-- drill_settings.allow_eleven_v4 = 1 (0 now: no call until Aron says yes, D180); v4_pause_tag = 1 puts one short
-- pause tag in front of the long answer for v4 drills.
alter table public.drills add column if not exists voice_rules integer not null default 1 check (voice_rules between 1 and 9);
alter table public.drills drop constraint if exists drills_voice_model_check;
alter table public.drills add constraint drills_voice_model_check
  check (voice_model in ('eleven_multilingual_v2', 'eleven_v3', 'eleven_flash_v2_5', 'eleven_v4'));
insert into public.drill_settings (key, value) values ('allow_eleven_v4', 0), ('v4_pause_tag', 1) on conflict (key) do nothing;
