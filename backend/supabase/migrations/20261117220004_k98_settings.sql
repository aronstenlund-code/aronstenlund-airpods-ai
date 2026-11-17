-- K98 (D224): the numbers, changeable without code.
insert into public.drill_settings (key, value) values
  ('welcome_credits', 5000), ('invite_credits', 2000), ('invite_month_max', 10)
on conflict (key) do nothing;
