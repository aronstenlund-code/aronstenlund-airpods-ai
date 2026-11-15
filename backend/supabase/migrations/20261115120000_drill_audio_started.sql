-- K71 (D190): the audio is made at Starta prov, not at save. null = text only (editable for free); set when the
-- audio was queued (start, share, publish, or an old app's save). Every drill saved before K71 had its audio queued
-- at save, so it counts as started.
alter table public.drills add column if not exists audio_started_at timestamptz;
update public.drills set audio_started_at = created_at where audio_started_at is null;
-- a row saved by code that does not know the column (until /drill with K71 is deployed) is a started drill
alter table public.drills alter column audio_started_at set default now();
