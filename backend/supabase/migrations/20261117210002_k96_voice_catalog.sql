-- K96 (D220): the curated voices the app may offer (service_role only).
create table if not exists public.voice_catalog (
  voice_id text primary key, name text not null, gender text, age text, accent text,
  language text, preview_url text, description text, sort integer not null default 100,
  enabled boolean not null default true
);
alter table public.voice_catalog enable row level security;
revoke all on public.voice_catalog from public, anon, authenticated;
