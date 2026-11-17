-- K88 (D211): the app's own id for an exam. The same client_id from the same account is one exam:
-- a save sent twice answers with the exam already saved (the unique index also stops two saves at once).
alter table public.drills add column if not exists client_id uuid;
create unique index if not exists drills_user_client_id on public.drills (user_id, client_id) where client_id is not null;
