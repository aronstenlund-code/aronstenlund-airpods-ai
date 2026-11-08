-- D82 (owner, Angela's row): the app now sends a `client_id` per history item; a second upload of the same item
-- is ignored. The 2 exact duplicates already in the table (same install, question and answer) were removed,
-- keeping the earliest row.
alter table public.shared_history
  add column if not exists client_id text check (client_id is null or char_length(client_id) <= 64);

delete from public.shared_history s
 using public.shared_history k
 where s.install_id = k.install_id and s.fragment = k.fragment and s.answer = k.answer
   and (k.created_at, k.id) < (s.created_at, s.id);

alter table public.shared_history drop constraint if exists shared_history_install_client_key;
alter table public.shared_history add constraint shared_history_install_client_key unique (install_id, client_id);
