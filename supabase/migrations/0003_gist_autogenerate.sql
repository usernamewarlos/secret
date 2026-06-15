-- 0003_gist_autogenerate.sql — OPTIONAL instant gist generation at graduation.
--
-- Fires the generate-gist Edge Function the moment a post flips to 'graduated', via pg_net.
-- This is the low-latency path (the "your gist is ready" dopamine moment). The
-- regenerate-gists cron remains the reliable fallback for first-generation + accretion,
-- so this trigger is purely additive and is a safe no-op until you configure it.
--
-- To enable, set (once, e.g. in the SQL editor or via Vault):
--   alter database postgres set app.functions_base_url = 'https://<project-ref>.functions.supabase.co';
--   alter database postgres set app.service_role_key  = '<service_role_key>';
-- If either setting is absent, the trigger does nothing.

create extension if not exists pg_net;

create or replace function public.on_post_graduated()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_base text := current_setting('app.functions_base_url', true);
  v_key  text := current_setting('app.service_role_key', true);
begin
  if new.status = 'graduated'
     and coalesce(old.status, '') <> 'graduated'
     and v_base is not null and v_key is not null then
    perform net.http_post(
      url     := v_base || '/generate-gist',
      headers := jsonb_build_object('Content-Type', 'application/json',
                                    'Authorization', 'Bearer ' || v_key),
      body    := jsonb_build_object('post_id', new.id)
    );
  end if;
  return new;
end; $$;

drop trigger if exists posts_graduated_trg on public.posts;
create trigger posts_graduated_trg
  after update of status on public.posts
  for each row execute function public.on_post_graduated();
