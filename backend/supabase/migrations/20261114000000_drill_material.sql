-- K53: many photos without one huge request. The app uploads each photo through a signed upload URL into the private
-- bucket drill_material (<user id>/<uuid>.jpg); /exam drill reads them by path and deletes them right after the
-- analysis (B4: the material is never kept). Anything left behind (an upload without a drill) is deleted by
-- /functions/v1/drill-purge after one hour, every 15 minutes. Applied as migration drill_material.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('drill_material', 'drill_material', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

select cron.schedule('purge-drill-material', '*/15 * * * *',
  $$select net.http_post(url := 'https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/drill-purge', body := '{}'::jsonb, headers := '{"content-type": "application/json"}'::jsonb)$$);
