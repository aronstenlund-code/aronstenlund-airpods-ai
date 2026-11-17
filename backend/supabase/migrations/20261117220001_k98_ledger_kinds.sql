-- K98 (D224): welcome and invitation credits in the ledger.
alter table public.credit_ledger drop constraint if exists credit_ledger_kind_check;
alter table public.credit_ledger add constraint credit_ledger_kind_check
  check (kind in ('purchase', 'refund', 'use', 'welcome', 'invite'));
