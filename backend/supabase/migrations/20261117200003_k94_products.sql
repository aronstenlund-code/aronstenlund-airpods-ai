-- K94 (D218, D214): product ids and what they give, read by the server (not in code). Prices are set in App Store Connect.
create table if not exists public.store_products (
  product_id text primary key, kind text not null check (kind in ('credits', 'subscription')), credits integer not null default 0
);
alter table public.store_products enable row level security;
revoke all on public.store_products from public, anon, authenticated;
insert into public.store_products (product_id, kind, credits) values
  ('com.rsolutions.lumen.credits.100', 'credits', 100), ('com.rsolutions.lumen.credits.500', 'credits', 500),
  ('com.rsolutions.lumen.credits.2000', 'credits', 2000), ('com.rsolutions.lumen.sub.week', 'subscription', 0)
on conflict (product_id) do nothing;
insert into public.drill_settings (key, value) values ('subscription_week_chars', 40000) on conflict (key) do nothing;
