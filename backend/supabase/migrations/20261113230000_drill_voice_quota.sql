-- K50 (D151): the voice model is chosen per drill before the audio is made and locked after; the credits ElevenLabs
-- charged per file are kept (character-cost); at most N generated questions per account (drill_settings, default
-- 30), drills downloaded from others never count. Applied as migration drill_voice_quota.
alter table public.drills add column if not exists voice_model text not null default 'eleven_multilingual_v2'
  check (voice_model in ('eleven_multilingual_v2', 'eleven_v3', 'eleven_flash_v2_5'));
alter table public.drill_audio_files add column if not exists credits integer;

create table if not exists public.drill_settings (
  key   text primary key check (char_length(key) <= 60),
  value integer not null
);
insert into public.drill_settings (key, value) values ('free_generated_questions', 30) on conflict (key) do nothing;

create table if not exists public.drill_quota (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  generated  integer not null default 0,
  extra      integer not null default 0,   -- later: a subscription adds questions here
  updated_at timestamptz not null default now()
);
alter table public.drill_settings enable row level security;
alter table public.drill_quota enable row level security;
revoke all on public.drill_settings, public.drill_quota from public, anon, authenticated;
grant all on public.drill_settings, public.drill_quota to service_role;

create or replace function public.use_drill_quota(p_user uuid, p_n integer)
returns table (ok boolean, used integer, lim integer)
language plpgsql security invoker set search_path = public as $$
declare l integer; u integer; e integer;
begin
  select value into l from public.drill_settings where key = 'free_generated_questions';
  l := coalesce(l, 30);
  insert into public.drill_quota (user_id) values (p_user) on conflict (user_id) do nothing;
  select generated, extra into u, e from public.drill_quota where user_id = p_user for update;
  if p_n <= 0 then
    return query select true, u, l + e;
  elsif u + p_n <= l + e then
    update public.drill_quota set generated = generated + p_n, updated_at = now() where user_id = p_user;
    return query select true, u + p_n, l + e;
  else
    return query select false, u, l + e;
  end if;
end $$;
revoke all on function public.use_drill_quota(uuid, integer) from public, anon, authenticated;
grant execute on function public.use_drill_quota(uuid, integer) to service_role;
