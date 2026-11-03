-- NOT APPLIED. Awaiting the owner's single approval.
-- pg_net was installed in project Lumen only as a temporary measurement aid (HTTP calls from inside
-- Supabase while the build container cannot reach *.supabase.co). Nothing in production uses it.
drop extension if exists pg_net;
