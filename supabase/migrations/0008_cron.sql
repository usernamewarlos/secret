-- 0008_cron.sql — turn the loop on (docs/ROADMAP.md B2; PRODUCT.md §6.3/§6.5; GIST.md §14).
--
-- Schedules the recurring server jobs via pg_cron. Only graduate_stale_posts() runs purely
-- in-database, so it is scheduled directly. publish-daily-prompt and regenerate-gists are Edge
-- Functions invoked over HTTP (pg_net) and need the same two settings the 0003 trigger uses:
--   app.functions_base_url + app.service_role_key. Those are commented templates below — enable
-- them once the settings are in place (Supabase scheduled Edge Functions are the alternative).

create extension if not exists pg_cron;

-- =====================================================================
-- In-database daily job: graduate stale posts / expire the ones that never reached MIN_FLOOR.
-- Defaults: 48h window, floor 3 (PRODUCT.md §6.5). Runs once daily at 09:00 UTC.
-- Idempotent to re-run; unschedule first so re-applying this migration doesn't duplicate it.
-- =====================================================================
select cron.unschedule('graduate-stale-posts')
  where exists (select 1 from cron.job where jobname = 'graduate-stale-posts');

select cron.schedule(
  'graduate-stale-posts',
  '0 9 * * *',
  $$ select public.graduate_stale_posts(); $$
);

-- =====================================================================
-- Edge Function jobs (COMMENTED TEMPLATES — enable once configured).
--
-- These two run as Edge Functions, so cron must call them over HTTP with pg_net.http_post,
-- exactly like the 0003 graduation trigger. They read the same two database settings:
--
--   alter database postgres set app.functions_base_url = 'https://<project-ref>.functions.supabase.co';
--   alter database postgres set app.service_role_key  = '<service_role_key>';
--
-- (Set these once in the SQL editor / Vault. They are NOT committed — service_role is a secret.)
-- pg_net is already enabled by migration 0003. Pin ONE canonical publish time (PRODUCT.md §11 #4):
-- publish-daily-prompt at a fixed UTC minute; run regenerate-gists shortly after so first-gen and
-- accretion happen on the same daily cadence (GIST.md §14). Uncomment to activate:
--
-- -- One global prompt per day, published at a fixed UTC time (08:00 UTC here).
-- select cron.schedule(
--   'publish-daily-prompt',
--   '0 8 * * *',
--   $cron$
--     select net.http_post(
--       url     := current_setting('app.functions_base_url', true) || '/publish-daily-prompt',
--       headers := jsonb_build_object('Content-Type', 'application/json',
--                                     'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)),
--       body    := '{}'::jsonb
--     );
--   $cron$
-- );
--
-- -- Batched gist first-generation + accretion regen, 30 min after the prompt drops (GIST.md §14).
-- select cron.schedule(
--   'regenerate-gists',
--   '30 8 * * *',
--   $cron$
--     select net.http_post(
--       url     := current_setting('app.functions_base_url', true) || '/regenerate-gists',
--       headers := jsonb_build_object('Content-Type', 'application/json',
--                                     'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)),
--       body    := '{}'::jsonb
--     );
--   $cron$
-- );
--
-- To remove a job later:  select cron.unschedule('publish-daily-prompt');
-- To inspect schedules:    select jobname, schedule, active from cron.job;
-- =====================================================================
