-- Cron job for `scheduled-notifications` Edge Function.
-- 09:00 Saudi Arabia (AST, UTC+3) == 06:00 UTC
--
-- Prerequisites (Dashboard → Database → Extensions):
--   - pg_cron
--   - pg_net
--
-- Set secrets (Vault or replace literals — never commit real keys):
--   - Project URL: https://<PROJECT_REF>.supabase.co
--   - Use Authorization: Bearer <SERVICE_ROLE_KEY> OR header x-cron-secret matching CRON_SECRET
--
-- Example schedule:
/*
SELECT cron.schedule(
  'laundrypro-scheduled-notifications',
  '0 6 * * *',
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/scheduled-notifications',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || 'YOUR_SERVICE_ROLE_KEY'
    ),
    body := '{}'::jsonb
  );
  $$
);
*/

-- Unschedule:
-- SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'laundrypro-scheduled-notifications';
