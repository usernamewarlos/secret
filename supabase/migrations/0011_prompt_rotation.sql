-- 0011_prompt_rotation.sql — per-profile prompt rotation, shaped by spice level.
--
-- Replaces "one global prompt/day for everyone" with a deterministic per-profile
-- rotation: each profile's prompt for a day is drawn ONLY from the band at/below
-- its default_spice_level, offset by a per-profile hash so friends land on
-- different prompts the same day and each profile cycles its eligible deck over
-- time. No cron / no daily writes — it's a pure function of (profile, day).

-- =====================================================================
-- prompt_id_for — the prompt assigned to a profile on a given day.
--   eligible band = prompts with tone_rank(tone) <= the owner's ceiling
--   index = (day_number + hash(owner)) mod band_size   → stable, staggered
-- =====================================================================
create or replace function public.prompt_id_for(p_owner uuid, p_day date)
returns uuid language sql stable security definer set search_path = '' as $$
  with band as (
    select id,
           row_number() over (order by created_at, id) - 1 as rn,
           count(*) over () as n
      from public.prompts
     where public.tone_rank(tone) <= public.tone_rank(
             coalesce((select default_spice_level from public.users where id = p_owner), 'social'))
  )
  select id from band
   where n > 0
     and rn = ((p_day - date '2026-01-01') + (abs(pg_catalog.hashtext(p_owner::text)) % n)) % n
   limit 1;
$$;

-- =====================================================================
-- today_feed — everything the Today screen needs in one call:
--   • the caller's own prompt-of-the-day + their post's aggregate state
--   • each person the caller can answer about, with THAT person's prompt-of-the-day
-- Aggregate only (count/status) — never reply bodies/authors (blind accumulation).
-- =====================================================================
create or replace function public.today_feed()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_me     uuid := auth.uid();
  v_my_pid uuid;
  v_my     public.posts;
  v_targets jsonb;
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  v_my_pid := public.prompt_id_for(v_me, current_date);
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
    join public.prompts pr on pr.id = public.prompt_id_for(o.owner_id, current_date)
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
-- dev_generate_responses — re-pointed at rotation: each owner's post uses THEIR
-- rotated prompt (prompt_id_for), not a single global published prompt.
-- =====================================================================
create or replace function public.dev_generate_responses()
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_owner uuid; v_owner_idx int := 0;
  v_pid uuid; v_tone text;
  v_post uuid; v_threshold int; v_count int; v_author uuid; v_target int;
  v_gist uuid; v_ver uuid;
  v_replies text[] := array[
    'Honestly? Spot on and I won''t elaborate.',
    'This is so them it hurts.',
    'I''ve witnessed this firsthand. Multiple times.',
    'No notes. Filing it under undeniable truths.',
    'Okay but make this their entire bio.',
    'The accuracy is genuinely upsetting.',
    'Ask anyone — they''ll say the same thing.',
    'I would testify to this in court.'];
  v_verdicts text[] := array[
    'The chaotic glue of the group.',
    'Quietly runs the whole operation.',
    'A menace, affectionately.',
    'Soft heart, sharp tongue.',
    'Main character, supporting everyone.'];
  v_bodies text[] := array[
    'Loud, loyal, and impossible to plan around — but the plan always works out better with them in it.',
    'Says the least, notices the most. The one everyone texts when it actually matters.',
    'Will derail dinner into a three-hour saga and you''ll thank them for it. Zero chill, maximum heart.',
    'Roasts you to your face and defends you behind your back. The realest kind of friend.',
    'Big presence, bigger loyalty. Shows up — every time, no scorekeeping.'];
begin
  if v_me is null then raise exception 'not authenticated'; end if;

  for v_owner in
    select v_me
    union all
    select id from public.users where id::text like 'dddddddd-dddd-4ddd-8ddd-%'
  loop
    v_owner_idx := v_owner_idx + 1;
    v_pid := public.prompt_id_for(v_owner, current_date);
    select tone into v_tone from public.prompts where id = v_pid;

    select id, threshold into v_post, v_threshold
      from public.posts where profile_owner_id = v_owner and prompt_id = v_pid;
    if v_post is null then
      insert into public.posts(profile_owner_id, prompt_id, threshold, spice_level)
        values (v_owner, v_pid, public.compute_threshold(v_owner), v_tone)
        returning id, threshold into v_post, v_threshold;
    end if;

    select count(*) into v_count from public.replies where post_id = v_post;
    v_target := greatest(v_threshold, 5);
    for v_author in
      select id from public.users
       where id <> v_owner and id::text like 'dddddddd-dddd-4ddd-8ddd-%'
         and not exists (select 1 from public.replies r where r.post_id = v_post and r.author_id = id)
       order by id
    loop
      exit when v_count >= v_target;
      insert into public.replies(post_id, author_id, body, is_private, privatized_by)
        values (v_post, v_author,
                v_replies[1 + (v_count % array_length(v_replies,1))],
                (v_count % 5 = 4),
                case when v_count % 5 = 4 then 'author' else null end);
      v_count := v_count + 1;
    end loop;

    if not exists (select 1 from public.gists where post_id = v_post) then
      insert into public.gists(post_id) values (v_post) returning id into v_gist;
      insert into public.gist_versions(gist_id, verdict, body, model, tone_flag, reply_count_at_generation)
        values (v_gist,
                v_verdicts[1 + (v_owner_idx % array_length(v_verdicts,1))],
                v_bodies[1 + (v_owner_idx % array_length(v_bodies,1))],
                'dev-seed', v_tone, v_count)
        returning id into v_ver;
      update public.gists set current_version_id = v_ver where id = v_gist;
    end if;
  end loop;

  return 'Filled rotated prompts for you + '
         ||(select count(*) from public.users where id::text like 'dddddddd-dddd-4ddd-8ddd-%')
         ||' friends (replies + gists).';
end; $$;

-- Rotation makes a manual "publish" obsolete.
drop function if exists public.dev_publish_next_prompt();

-- =====================================================================
-- Grants
-- =====================================================================
revoke all on function public.prompt_id_for(uuid, date) from public, anon;  -- internal helper
revoke all on function public.today_feed()              from public, anon;
grant  execute on function public.today_feed()          to authenticated;
