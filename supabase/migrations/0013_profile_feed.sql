-- 0013_profile_feed.sql — one RPC for a profile's whole archive (kills the
-- Profile screen's two N+1 client loops). Mirrors today_feed; aggregate-only.

create or replace function public.profile_feed(p_owner uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_owner jsonb; v_posts jsonb;
begin
  if not public.can_view_profile(p_owner) then raise exception 'not authorized'; end if;

  select jsonb_build_object(
           'display_name', u.display_name,
           'ig_handle',    u.ig_handle,
           'photo_url',    u.photo_url,
           'repliers',     (select count(*) from public.connections c
                             where c.owner_id = p_owner and c.role = 'replier')
         ) into v_owner
    from public.users u where u.id = p_owner;

  select coalesce(jsonb_agg(p order by grad desc nulls last, created desc), '[]'::jsonb)
    into v_posts
    from (
      select po.graduated_at as grad, po.created_at as created,
             jsonb_build_object(
               'id',            po.id,
               'status',        po.status,
               'threshold',     po.threshold,
               'spice_level',   po.spice_level,
               'graduated_at',  po.graduated_at,
               'prompt_id',     pr.id,
               'prompt_text',   pr.text,
               'prompt_tone',   pr.tone,
               'count',         (select count(*) from public.replies r where r.post_id = po.id),
               'private_count', case when po.status = 'graduated'
                                     then (select count(*) from public.replies r
                                            where r.post_id = po.id and r.is_private)
                                     else 0 end,
               'verdict',       case when po.status = 'graduated'
                                     then (select gv.verdict from public.gists g
                                             join public.gist_versions gv on gv.id = g.current_version_id
                                            where g.post_id = po.id)
                                     else null end
             ) as p
        from public.posts po
        join public.prompts pr on pr.id = po.prompt_id
       where po.profile_owner_id = p_owner
    ) sub;

  return jsonb_build_object('owner', v_owner, 'posts', v_posts);
end; $$;

revoke all on function public.profile_feed(uuid) from public, anon;
grant execute on function public.profile_feed(uuid) to authenticated;
