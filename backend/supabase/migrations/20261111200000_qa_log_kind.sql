-- K42.4: a turn where the user complained about the app ("varför upprepar du") is marked so it shows on Aron's page.
alter table public.qa_log add column if not exists kind text check (kind is null or kind in ('complaint'));
