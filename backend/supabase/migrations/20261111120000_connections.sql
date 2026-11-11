-- K36 (D122, D125): OAuth connections to outside services (first: Spotify). Tokens are encrypted with AES-GCM in the
-- Edge Function (CONNECTIONS_KEY, a function secret) before they reach this table, so a database dump alone does not
-- give access. Service role only: RLS on, no client grants. A user disconnects with DELETE /functions/v1/connect,
-- which deletes the row. No email, no name: the provider's account id is not stored either, only what the tools need.

create table if not exists public.connections (
  user_id       uuid not null,
  provider      text not null check (provider in ('spotify')),
  access_enc    text not null,
  refresh_enc   text,
  expires_at    timestamptz not null,
  scope         text check (char_length(scope) <= 500),
  premium       boolean,                       -- Spotify: playback can be controlled only with Premium
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  primary key (user_id, provider)
);

alter table public.connections enable row level security;
revoke all on public.connections from public, anon, authenticated;
grant all on public.connections to service_role;
