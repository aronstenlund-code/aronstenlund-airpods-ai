-- K59: how much of the Free plan's 1 GB storage the drill audio uses (per day and in total); service role only
create or replace function public.drill_storage_stats()
returns jsonb
language sql
security definer
set search_path = ''
as $$
  with o as (
    select bucket_id, (created_at at time zone 'Europe/Stockholm')::date as day, coalesce((metadata->>'size')::bigint, 0) as bytes
    from storage.objects
  )
  select jsonb_build_object(
    'total_bytes', (select coalesce(sum(bytes), 0) from o),
    'drill_audio_bytes', (select coalesce(sum(bytes), 0) from o where bucket_id = 'drill_audio'),
    'drill_audio_files', (select count(*) from o where bucket_id = 'drill_audio'),
    'per_day', coalesce((select jsonb_agg(jsonb_build_object('day', day, 'files', n, 'bytes', b) order by day)
      from (select day, count(*) n, sum(bytes) b from o where bucket_id = 'drill_audio' group by day) d), '[]'::jsonb),
    'db_bytes', pg_database_size(current_database())
  );
$$;
revoke all on function public.drill_storage_stats() from public, anon, authenticated;
grant execute on function public.drill_storage_stats() to service_role;
