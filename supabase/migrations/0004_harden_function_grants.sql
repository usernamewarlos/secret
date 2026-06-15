-- 0004_harden_function_grants.sql — least-privilege EXECUTE on functions.
--
-- Postgres grants EXECUTE to PUBLIC by default, so every function (including internal
-- trigger/cron functions) was callable by the `anon` role via PostgREST RPC. Revoke the
-- PUBLIC default and grant only the client-facing RPCs + RLS helpers to `authenticated`.
-- (Trigger functions run as the table owner; cron functions use service_role — neither
-- needs a client-facing grant.)

-- Internal (triggers / cron): no client EXECUTE.
revoke all on function public.handle_new_user()                       from public;
revoke all on function public.maybe_graduate_post()                   from public;
revoke all on function public.on_post_graduated()                     from public;
revoke all on function public.replies_guard_immutable()               from public;
revoke all on function public.graduate_stale_posts(interval, integer) from public;
revoke all on function public.compute_threshold(uuid)                 from public;

-- RLS helpers + client RPCs: drop the PUBLIC default…
revoke all on function public.can_view_profile(uuid)                     from public;
revoke all on function public.is_replier(uuid)                           from public;
revoke all on function public.submit_reply(uuid, uuid, text, boolean)    from public;
revoke all on function public.set_my_reply_privacy(uuid, boolean)        from public;
revoke all on function public.owner_privatize_reply(uuid)                from public;
revoke all on function public.revoke_connection(uuid)                    from public;
revoke all on function public.post_reply_count(uuid)                     from public;
revoke all on function public.post_private_markers(uuid)                 from public;

-- …then grant only to signed-in users.
grant execute on function
  public.can_view_profile(uuid),
  public.is_replier(uuid),
  public.submit_reply(uuid, uuid, text, boolean),
  public.set_my_reply_privacy(uuid, boolean),
  public.owner_privatize_reply(uuid),
  public.revoke_connection(uuid),
  public.post_reply_count(uuid),
  public.post_private_markers(uuid)
to authenticated;

-- Pin search_path on the one trigger function that was missing it.
alter function public.replies_guard_immutable() set search_path = '';
