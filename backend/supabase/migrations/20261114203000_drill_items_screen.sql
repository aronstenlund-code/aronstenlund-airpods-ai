-- K66 (Oscar O63 punkt 4): what the app SHOWS where it differs from the spoken text.
-- The voice reads question/short/long ("arton hundrafemtio", "a i kvadrat plus b i kvadrat");
-- the screen shows {"question","short","long"} ("1850", "a² + b²"). Only the fields that differ; null = same text.
alter table public.drill_items
  add column if not exists screen jsonb
  check (screen is null or (jsonb_typeof(screen) = 'object' and pg_column_size(screen) <= 12000));
