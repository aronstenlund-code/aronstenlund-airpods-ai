-- K49 (D149, D150): Publicera prov. A published drill is found by school (Skolverket's school unit register, cached
-- in `schools`), subject and exam date. Published data never holds the account, photos or documents; the user's name
-- only when they chose to show it (D150). Downloads and plays are counted (numbers only, no identity) for the future
-- credit system. Three reports hide a drill until Aron looks at it. Service role only (through /functions/v1/drill).

create table if not exists public.schools (
  code              text primary key check (code ~ '^[0-9]{6,10}$'),   -- skolenhetskod
  name              text not null check (char_length(name) between 1 and 200),
  locality          text check (char_length(locality) <= 100),
  municipality_code text check (municipality_code ~ '^[0-9]{4}$'),
  school_types      text[] not null default '{}',
  status            text not null,                                   -- AKTIV, VILANDE, UPPHORT, PLANERAD
  updated_at        timestamptz not null default now()
);
create index if not exists schools_name_idx on public.schools (lower(name) text_pattern_ops);

create table if not exists public.drill_publications (
  id           uuid primary key default gen_random_uuid(),
  drill_id     uuid not null unique references public.drills(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,  -- never returned by search
  school_code  text not null references public.schools(code),
  subject      text not null check (char_length(subject) between 1 and 60),
  exam_date    date not null,
  display_name text check (char_length(display_name) <= 40),            -- only when the user chose to show it
  hidden       boolean not null default false,
  reports      integer not null default 0,
  imports      integer not null default 0,
  plays        integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists drill_publications_school_idx on public.drill_publications (school_code, exam_date desc);

create table if not exists public.drill_reports (
  publication_id uuid not null references public.drill_publications(id) on delete cascade,
  user_id        uuid not null,
  reason         text not null check (reason in ('fel', 'krankande', 'upphovsratt', 'annat')),
  created_at     timestamptz not null default now(),
  primary key (publication_id, user_id)
);

alter table public.schools enable row level security;
alter table public.drill_publications enable row level security;
alter table public.drill_reports enable row level security;
revoke all on public.schools, public.drill_publications, public.drill_reports from public, anon, authenticated;
grant all on public.schools, public.drill_publications, public.drill_reports to service_role;

-- one report per account; three distinct reports hide the drill
create or replace function public.report_publication(p_id uuid, p_user uuid, p_reason text)
returns table (reports integer, hidden boolean)
language plpgsql security invoker set search_path = public as $$
begin
  insert into public.drill_reports (publication_id, user_id, reason) values (p_id, p_user, p_reason)
  on conflict do nothing;
  return query
  update public.drill_publications p
     set reports = (select count(*) from public.drill_reports r where r.publication_id = p_id),
         hidden  = p.hidden or (select count(*) from public.drill_reports r where r.publication_id = p_id) >= 3
   where p.id = p_id
  returning p.reports, p.hidden;
end $$;

create or replace function public.bump_publication(p_id uuid, p_field text) returns void
language plpgsql security invoker set search_path = public as $$
begin
  if p_field = 'imports' then
    update public.drill_publications set imports = imports + 1 where id = p_id;
  elsif p_field = 'plays' then
    update public.drill_publications set plays = plays + 1 where id = p_id;
  end if;
end $$;

revoke all on function public.report_publication(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.bump_publication(uuid, text) from public, anon, authenticated;
grant execute on function public.report_publication(uuid, uuid, text) to service_role;
grant execute on function public.bump_publication(uuid, text) to service_role;

-- live 2026-11-13: a void function answers 204 without a body, which the function's JSON reader cannot read;
-- it returns the new count instead (applied as migration bump_publication_returns_count)
drop function if exists public.bump_publication(uuid, text);
create function public.bump_publication(p_id uuid, p_field text) returns integer
language plpgsql security invoker set search_path = public as $$
declare n integer;
begin
  if p_field = 'imports' then
    update public.drill_publications set imports = imports + 1 where id = p_id returning imports into n;
  elsif p_field = 'plays' then
    update public.drill_publications set plays = plays + 1 where id = p_id returning plays into n;
  end if;
  return coalesce(n, 0);
end $$;
revoke all on function public.bump_publication(uuid, text) from public, anon, authenticated;
grant execute on function public.bump_publication(uuid, text) to service_role;
