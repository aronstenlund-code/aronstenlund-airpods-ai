# O100 – RLS-översikt (körd av Deangelo åt Oscar, 2026-11-26 10:15, Oscars egen fråga, bara läsning)

Frågan: pg_class + has_table_privilege för anon/authenticated + pg_policies, schema public.

| Tabell | RLS | anon select | auth sel/ins/upd/del | Policyer |
|---|---|---|---|---|
| answer_usage | på | ja | ja/ja/ja/ja | inga |
| app_attest_challenges, app_attest_keys, ci_ranges, connections, credit_admins, credit_ledger, debug_testers, debug_turns, drill_audio_files, drill_publications, drill_quota, drill_reports, drill_settings, drill_shares, drill_try_credits, invite_claims, invite_codes, logo_votes, provider_status, qa_log, real_user_candidates, schools, store_products, store_subscriptions, test_accounts, voice_catalog, waitlist | på | nej | nej | inga |
| drill_items | på | nej | ja/nej/nej/ja | owner_read (user_id = auth.uid()), owner_delete (samma) |
| drills | på | nej | ja/nej/nej/ja | owner_read, owner_delete (user_id = auth.uid()) |
| feedback | på | nej | nej/ja/nej/nej | insert_own (with check user_id = auth.uid()) |
| shared_history | på | nej | nej/ja/nej/nej | insert_own (with check user_id = auth.uid()) |
| rate_limits | på | ja | ja/ja/ja/ja | inga |
| feedback_admin | **av** | nej | nej | – (vy/tabell utan RLS, inga rättigheter för anon/auth) |
| usage_by_category_day | **av** | nej | nej | – (samma) |

Att kontrollera (Oscar): answer_usage och rate_limits har tabellrättigheter för anon/authenticated men RLS utan policy (alltså nekat) – bekräfta live att de inte går att läsa/skriva; feedback_admin och usage_by_category_day saknar RLS men också rättigheter.
