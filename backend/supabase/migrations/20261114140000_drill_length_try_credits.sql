-- K61 (D176): the length of each question (question + long answer, characters sent to ElevenLabs) and its class;
-- the limits are in drill_settings like D155 (change them there, no new code). No charge yet (D157).
alter table public.drill_items add column if not exists voice_chars integer;
alter table public.drill_items add column if not exists length_class text check (length_class in ('normal', 'longer', 'too_long'));
insert into public.drill_settings (key, value) values ('length_normal_max', 800), ('length_longer_max', 1600) on conflict (key) do nothing;

-- K61 (D177): questions already counted in /help try are not counted again when saved as a drill
create table if not exists public.drill_try_credits (
  user_id uuid not null references auth.users (id) on delete cascade,
  question_key text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, question_key)
);
alter table public.drill_try_credits enable row level security;
revoke all on public.drill_try_credits from public, anon, authenticated;
grant select, insert, update, delete on public.drill_try_credits to service_role;
