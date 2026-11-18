-- T28 (Angela Fable): a Säg text is marked on the server, so a new phone tells it from an exam.
alter table public.drills add column if not exists said boolean not null default false;
