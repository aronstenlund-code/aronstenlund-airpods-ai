-- K78b (Oscar O71): GitHub's Actions IP ranges for the test check (D180), kept here because api.github.com/meta
-- answers 403 to Supabase's shared IPs at times. Written by the functions whenever GitHub answers; read when it
-- does not. Service role only.
create table if not exists public.ci_ranges (
  id         integer primary key check (id = 1),
  cidrs      text[] not null,
  source     text check (char_length(source) <= 20),
  updated_at timestamptz not null default now()
);
alter table public.ci_ranges enable row level security;
revoke all on public.ci_ranges from public, anon, authenticated;
grant all on public.ci_ranges to service_role;
