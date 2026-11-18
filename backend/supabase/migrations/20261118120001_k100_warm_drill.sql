-- K100 (Oscar O84): keep /drill warm, so a user's first press after a quiet while is not a cold start (11 s).
-- {"action":"warm"} needs no token and reads nothing of any account; drill is deployed without the gateway's JWT check.
select cron.schedule('warm-drill', '*/2 * * * *',
  $$select net.http_post(url := 'https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/drill', body := '{"action":"warm"}'::jsonb, headers := '{"content-type": "application/json"}'::jsonb)$$);
