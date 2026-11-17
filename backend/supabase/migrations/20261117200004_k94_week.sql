-- K94 (D218): characters used this ISO week under the subscription.
alter table public.drill_quota add column if not exists week_chars integer not null default 0 check (week_chars >= 0);
alter table public.drill_quota add column if not exists week_period text not null default '';
