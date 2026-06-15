-- 0005_revoke_anon_execute.sql — Supabase's default privileges grant EXECUTE on new public
-- functions directly to anon/authenticated/service_role, so 0004's `revoke from public` was
-- insufficient. Revoke EXECUTE from `anon` on everything, and from `authenticated` on the
-- internal trigger/cron helpers. The client RPCs keep their `authenticated` grant; the RLS
-- helper `can_view_profile` stays granted to `authenticated` (policies evaluate it);
-- `service_role` (cron) is left untouched.

-- anon executes nothing:
revoke all on function public.handle_new_user()                       from anon;
revoke all on function public.maybe_graduate_post()                   from anon;
revoke all on function public.on_post_graduated()                     from anon;
revoke all on function public.replies_guard_immutable()               from anon;
revoke all on function public.graduate_stale_posts(interval, integer) from anon;
revoke all on function public.compute_threshold(uuid)                 from anon;
revoke all on function public.is_replier(uuid)                        from anon;
revoke all on function public.can_view_profile(uuid)                  from anon;
revoke all on function public.submit_reply(uuid, uuid, text, boolean) from anon;
revoke all on function public.set_my_reply_privacy(uuid, boolean)     from anon;
revoke all on function public.owner_privatize_reply(uuid)             from anon;
revoke all on function public.revoke_connection(uuid)                 from anon;
revoke all on function public.post_reply_count(uuid)                  from anon;
revoke all on function public.post_private_markers(uuid)              from anon;

-- internal helpers: authenticated shouldn't call these directly either (they run inside
-- triggers / SECURITY DEFINER RPCs / cron, all as the owner or service_role):
revoke all on function public.handle_new_user()                       from authenticated;
revoke all on function public.maybe_graduate_post()                   from authenticated;
revoke all on function public.on_post_graduated()                     from authenticated;
revoke all on function public.replies_guard_immutable()               from authenticated;
revoke all on function public.graduate_stale_posts(interval, integer) from authenticated;
revoke all on function public.compute_threshold(uuid)                 from authenticated;
revoke all on function public.is_replier(uuid)                        from authenticated;
