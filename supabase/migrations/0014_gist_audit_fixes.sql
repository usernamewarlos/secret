-- 0014_gist_audit_fixes.sql — fixes from the 2026-06-17 gist/prompt pipeline audit.
-- All changes are pure SQL (no paid API). The revoke-driven regen enqueue is a harmless no-op
-- until app.functions_base_url + app.service_role_key are set (same as the 0003 trigger / 0008 cron).

-- =====================================================================
-- 1. prompts.display_order — explicit, stable rotation ordering so deck edits don't re-base
--    everyone's daily prompt (audit P3: rotation order was created_at,id, i.e. random uuid order).
-- =====================================================================
alter table public.prompts add column if not exists display_order int;

-- One-time backfill of existing rows by their current frozen order.
with ranked as (
  select id, row_number() over (order by created_at, id) as rn from public.prompts
)
update public.prompts p
   set display_order = ranked.rn
  from ranked
 where ranked.id = p.id and p.display_order is null;

-- =====================================================================
-- 2. prompt_id_for — order the band by display_order (stable across deck edits) and cast the
--    hash to bigint before abs() so hashtext = INT_MIN can't raise 22003 'integer out of range'
--    (audit P2: that would throw today_feed for the owner AND everyone who follows them).
-- =====================================================================
create or replace function public.prompt_id_for(p_owner uuid, p_day date)
returns uuid language sql stable security definer set search_path = '' as $$
  with band as (
    select id,
           row_number() over (order by display_order nulls last, created_at, id) - 1 as rn,
           count(*) over () as n
      from public.prompts
     where public.tone_rank(tone) <= public.tone_rank(
             coalesce((select default_spice_level from public.users where id = p_owner), 'social'))
  )
  select id from band
   where n > 0
     and rn = ((p_day - date '2026-01-01') + (abs(pg_catalog.hashtext(p_owner::text)::bigint) % n)) % n
   limit 1;
$$;

-- =====================================================================
-- 3. today_feed — pin the rotation day to UTC so the daily flip is deterministic regardless of
--    session timezone and aligned with the UTC-anchored cron jobs (audit P3). Otherwise identical.
-- =====================================================================
create or replace function public.today_feed()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_me      uuid := auth.uid();
  v_today   date := (now() at time zone 'UTC')::date;
  v_my_pid  uuid;
  v_my      public.posts;
  v_targets jsonb;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  v_my_pid := public.prompt_id_for(v_me, v_today);
  select * into v_my from public.posts where profile_owner_id = v_me and prompt_id = v_my_pid;

  select coalesce(jsonb_agg(t order by nm), '[]'::jsonb) into v_targets
  from (
    select u.display_name as nm,
      jsonb_build_object(
        'owner_id',    o.owner_id,
        'name',        u.display_name,
        'handle',      u.ig_handle,
        'prompt_id',   pr.id,
        'prompt_text', pr.text,
        'prompt_tone', pr.tone,
        'status',      coalesce(p.status, 'accumulating'),
        'count',       coalesce((select count(*) from public.replies r where r.post_id = p.id), 0),
        'threshold',   coalesce(p.threshold, public.compute_threshold(o.owner_id)),
        'answered',    exists (select 1 from public.replies r where r.post_id = p.id and r.author_id = v_me)
      ) as t
    from (select distinct owner_id from public.connections
           where connected_user_id = v_me and role = 'replier') o
    join public.users u   on u.id = o.owner_id
    join public.prompts pr on pr.id = public.prompt_id_for(o.owner_id, v_today)
    left join public.posts p on p.profile_owner_id = o.owner_id and p.prompt_id = pr.id
  ) sub;

  return jsonb_build_object(
    'my_prompt',    (select jsonb_build_object('id', id, 'text', text, 'tone', tone)
                       from public.prompts where id = v_my_pid),
    'my_count',     coalesce((select count(*) from public.replies where post_id = v_my.id), 0),
    'my_status',    coalesce(v_my.status, 'accumulating'),
    'my_threshold', coalesce(v_my.threshold, public.compute_threshold(v_me)),
    'targets',      v_targets
  );
end; $$;

-- =====================================================================
-- 4. profile_feed — also surface the gist's `stale` + `tone_flag` so the profile grid (the most-
--    viewed surface) can show a "fewer voices now" / soft-tone cue, not just the post detail view
--    (audit P1: the stale flag was set but invisible on the read path).
-- =====================================================================
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
                                     else null end,
               'tone_flag',     case when po.status = 'graduated'
                                     then (select gv.tone_flag from public.gists g
                                             join public.gist_versions gv on gv.id = g.current_version_id
                                            where g.post_id = po.id)
                                     else null end,
               'stale',         case when po.status = 'graduated'
                                     then coalesce((select gv.stale from public.gists g
                                                      join public.gist_versions gv on gv.id = g.current_version_id
                                                     where g.post_id = po.id), false)
                                     else false end
             ) as p
        from public.posts po
        join public.prompts pr on pr.id = po.prompt_id
       where po.profile_owner_id = p_owner
    ) sub;

  return jsonb_build_object('owner', v_owner, 'posts', v_posts);
end; $$;

-- =====================================================================
-- 5. revoke_connection — after removing a revoked person's replies, RE-SPIN the gist for each
--    affected graduated post that still has enough public signal, so the revoked person's
--    influence actually leaves the (first-party) portrait (audit P0; GIST.md §4/§14). Posts that
--    fall below MIN_FLOOR keep the stale flag instead (too thin to re-synthesize, GIST.md §16).
--    The enqueue is a no-op until app.functions_base_url + app.service_role_key are set.
-- =====================================================================
create or replace function public.revoke_connection(p_connected uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_me       uuid := auth.uid();
  v_base     text := current_setting('app.functions_base_url', true);
  v_key      text := current_setting('app.service_role_key', true);
  v_affected uuid[];
  v_post     uuid;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  -- Which of my posts did this person actually reply to? (capture BEFORE deleting)
  select array_agg(distinct r.post_id) into v_affected
    from public.replies r
    join public.posts p on p.id = r.post_id
   where p.profile_owner_id = v_me and r.author_id = p_connected;

  delete from public.replies r using public.posts p
   where r.post_id = p.id and p.profile_owner_id = v_me and r.author_id = p_connected;

  delete from public.connections
   where owner_id = v_me and connected_user_id = p_connected;

  if v_affected is null then return; end if;

  -- Flag stale: affected graduated posts now below MIN_FLOOR (3) public replies. History preserved.
  update public.gist_versions gv
     set stale = true
   from public.gists g
   join public.posts p on p.id = g.post_id
   where gv.id = g.current_version_id
     and p.id = any(v_affected)
     and p.status = 'graduated'
     and (select count(*) from public.replies r where r.post_id = p.id and r.is_private = false) < 3;

  -- Re-spin affected graduated posts that still have >= MIN_FLOOR public replies.
  if v_base is not null and v_key is not null then
    for v_post in
      select p.id
        from public.posts p
       where p.id = any(v_affected)
         and p.profile_owner_id = v_me
         and p.status = 'graduated'
         and exists (select 1 from public.gists g where g.post_id = p.id)
         and (select count(*) from public.replies r where r.post_id = p.id and r.is_private = false) >= 3
    loop
      perform net.http_post(
        url     := v_base || '/generate-gist',
        headers := jsonb_build_object('Content-Type', 'application/json',
                                      'Authorization', 'Bearer ' || v_key),
        body    := jsonb_build_object('post_id', v_post)
      );
    end loop;
  end if;
end; $$;

-- =====================================================================
-- 6. gist_safety_signals — monitoring view for the §15 drift early-warning (excluded_count /
--    tone_flag / fallback rate per prompt). Intentionally spans ALL gist versions (the full time
--    series), not just current, so drift is visible over time. Admin-only: query it from the SQL
--    editor; never exposed to clients.
-- =====================================================================
create or replace view public.gist_safety_signals as
  select gv.id   as version_id,
         g.post_id,
         p.prompt_id,
         pr.text  as prompt_text,
         pr.tone  as prompt_tone,
         gv.model,
         gv.tone_flag,
         gv.excluded_count,
         gv.stale,
         gv.reply_count_at_generation,
         gv.created_at
    from public.gist_versions gv
    join public.gists   g  on g.id  = gv.gist_id
    join public.posts   p  on p.id  = g.post_id
    join public.prompts pr on pr.id = p.prompt_id;

revoke all on public.gist_safety_signals from public, anon, authenticated;

-- =====================================================================
-- 7. Deck delta — LIVE ONLY (skipped on a fresh DB, where seed/prompts.sql provides the final
--    deck). Re-aims two spicy prompts off character/worth onto behavior, sharpens one abstract
--    wholesome prompt, and deepens the deck: wholesome 4->8 + competence / one-on-one / aesthetic
--    axes (audit P1/P2/P3). Idempotent by text; new rows get high display_order so they append
--    within their band without shifting existing owners' rotation position.
-- =====================================================================
do $$
begin
  if exists (select 1 from public.prompts) then
    update public.prompts set text = 'What''s the thing they do that drives everyone a little insane?'
      where text = 'What''s their biggest flaw?';
    update public.prompts set text = 'What''s the habit they''ll defend to their grave?'
      where text = 'What do they need to hear but won''t?';
    update public.prompts set text = 'What''s a small thing they do that they think nobody clocks?'
      where text = 'What''s something they''d be quietly proud you noticed?';

    insert into public.prompts (text, tone, display_order)
    select v.text, v.tone, v.ord
      from (values
        ('What do you always end up doing when it''s just the two of you?',                 'wholesome', 101),
        ('What''s a small thing they do that always makes your day better?',                'wholesome', 102),
        ('When did you first realize they were one of your people?',                        'wholesome', 103),
        ('What''s the kindest thing you''ve seen them do when no one was keeping score?',    'wholesome', 104),
        ('What are they weirdly, specifically good at?',                                     'social',    105),
        ('What''s the face they make that always gives them away?',                         'social',    106),
        ('What''s their signature order, outfit, or detail — the most "them" thing?',        'playful',   107),
        ('If their life had a theme song right now, what''s playing?',                       'playful',   108)
      ) as v(text, tone, ord)
     where not exists (select 1 from public.prompts p where p.text = v.text);
  end if;
end $$;

-- =====================================================================
-- Grants — CREATE OR REPLACE preserves a function's existing ACL, so these restate least-privilege
-- explicitly (idempotent, and keeps it correct if a function is ever dropped + recreated fresh).
-- =====================================================================
revoke all on function public.prompt_id_for(uuid, date) from public, anon;  -- internal helper
revoke all on function public.today_feed()              from public, anon;
revoke all on function public.profile_feed(uuid)        from public, anon;
revoke all on function public.revoke_connection(uuid)   from public, anon;
grant execute on function public.today_feed()           to authenticated;
grant execute on function public.profile_feed(uuid)     to authenticated;
grant execute on function public.revoke_connection(uuid) to authenticated;
