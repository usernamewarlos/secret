-- 0007_gist_integrity.sql — gist integrity + reply length cap (docs/PRODUCT.md §10, ROADMAP B4/B7).
--
--   * gist_versions.stale — set when a revoke drops a graduated post below MIN_FLOOR (3): the
--     existing gist is kept (history is never deleted) but flagged so the product can stop it
--     claiming more than the thinned reply set now supports (PRODUCT.md §10, GIST.md §16).
--   * replies.body length cap — keep replies punchy and gist-friendly (PRODUCT.md §6.4, 1–500 chars).

-- ---------- stale flag on gist versions ----------
alter table public.gist_versions
  add column if not exists stale boolean not null default false;

-- ---------- reply body length cap (1–500 chars) ----------
alter table public.replies
  add constraint replies_body_len check (char_length(body) between 1 and 500);

-- ---------- revoke_connection: mark thinned graduated posts' gists stale ----------
-- After deleting the revoked person's replies, any of the caller's GRADUATED posts whose PUBLIC
-- reply count has fallen below MIN_FLOOR (3) has its CURRENT gist version flagged stale. History
-- is preserved; the flag tells the product/regen path the portrait now rests on too little signal.
-- (MIN_FLOOR mirrors compute_threshold's floor in 0001 and graduate_stale_posts' default.)
create or replace function public.revoke_connection(p_connected uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  delete from public.replies r using public.posts p
   where r.post_id = p.id and p.profile_owner_id = auth.uid() and r.author_id = p_connected;

  delete from public.connections
   where owner_id = auth.uid() and connected_user_id = p_connected;

  -- Flag the current gist version stale on any of the caller's graduated posts now below floor.
  update public.gist_versions gv
     set stale = true
   from public.gists g
   join public.posts p on p.id = g.post_id
   where gv.id = g.current_version_id
     and p.profile_owner_id = auth.uid()
     and p.status = 'graduated'
     and (
       select count(*) from public.replies r
        where r.post_id = p.id and r.is_private = false
     ) < 3;
end; $$;

-- Keep the least-privilege grant intact (recreating the function reset its ACL to defaults).
revoke all on function public.revoke_connection(uuid) from public;
revoke all on function public.revoke_connection(uuid) from anon;
grant execute on function public.revoke_connection(uuid) to authenticated;
