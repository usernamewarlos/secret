-- 0010_dev_seed.sql — DEV / TEST ONLY.  ⚠️ Remove (or guard) before production.
--
-- A fixed pool of 10 fake users + three authenticated-callable helper RPCs that the
-- in-app dev buttons use:
--   • dev_seed_friends()        — connect the caller ↔ the fake pool (both directions)
--   • dev_generate_responses()  — fill the caller's + each friend's today-prompt post
--                                 with fake replies until it graduates, then fake a gist
--                                 (placeholder mode has no AI gist otherwise)
--   • dev_publish_next_prompt() — rotate today's daily prompt to a fresh deck entry
--
-- All RPCs are SECURITY DEFINER and key off auth.uid(); they only touch public tables.

-- =====================================================================
-- 1) Fake user pool — auth.users (FK target) then public.users profile.
--    Deterministic UUIDs (dddddddd-dddd-4ddd-8ddd-0000000000NN) → idempotent.
-- =====================================================================
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data)
select '00000000-0000-0000-0000-000000000000',
       ('dddddddd-dddd-4ddd-8ddd-'||lpad(idx::text,12,'0'))::uuid,
       'authenticated','authenticated',
       'grapevine.seed+'||idx||'@example.com',
       extensions.crypt('grapevine-seed', extensions.gen_salt('bf')),
       now(), now(), now(),
       '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb
from (values (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) as t(idx)
on conflict (id) do nothing;

insert into public.users (id, display_name, bio, ig_handle, age_verified, default_spice_level)
select ('dddddddd-dddd-4ddd-8ddd-'||lpad(idx::text,12,'0'))::uuid, name, bio, handle, true, spice
from (values
  (1,'Jordan Lee','jlee','social','Always two minutes late, never sorry.'),
  (2,'Priya Nair','priya','playful','Will fight you over board games.'),
  (3,'Sam Okafor','sokafor','social','Group chat historian.'),
  (4,'Tess Bloom','tessb','wholesome','Brings snacks unprompted.'),
  (5,'Devon Wu','devonw','spicy','Opinions: many. Filter: none.'),
  (6,'Alex Romano','alexr','playful','Plan-derailer extraordinaire.'),
  (7,'Cleo Mart','cleom','social','Knows a guy for everything.'),
  (8,'Marcus Vale','marcusv','wholesome','Texts back in 3-5 business days.'),
  (9,'Nadia Khan','nadiak','spicy','Brutally honest, lovingly.'),
  (10,'Theo Park','theop','playful','Main character energy.')
) as t(idx, name, handle, spice, bio)
on conflict (id) do update
  set display_name = excluded.display_name,
      bio          = excluded.bio,
      ig_handle    = excluded.ig_handle;

-- =====================================================================
-- 2) dev_seed_friends — wire the caller ↔ the fake pool (both as repliers).
-- =====================================================================
create or replace function public.dev_seed_friends()
returns int language plpgsql security definer set search_path = '' as $$
declare v_me uuid := auth.uid(); v_id uuid; v_n int := 0;
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  for v_id in
    select id from public.users
     where id <> v_me and id::text like 'dddddddd-dddd-4ddd-8ddd-%'
  loop
    -- the fake user becomes a REPLIER on me (can write about me)
    if not exists (select 1 from public.connections where owner_id = v_me and connected_user_id = v_id) then
      insert into public.connections(owner_id, connected_user_id, role) values (v_me, v_id, 'replier');
    end if;
    -- I become a REPLIER on the fake user (so I can answer about them)
    if not exists (select 1 from public.connections where owner_id = v_id and connected_user_id = v_me) then
      insert into public.connections(owner_id, connected_user_id, role) values (v_id, v_me, 'replier');
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end; $$;

-- =====================================================================
-- 3) dev_generate_responses — graduate the caller's + each fake friend's
--    today-prompt post with fake replies, then fake a gist for each.
-- =====================================================================
create or replace function public.dev_generate_responses()
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_prompt uuid; v_tone text;
  v_owner uuid; v_owner_idx int := 0;
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
  select id, tone into v_prompt, v_tone from public.prompts where publish_date = current_date limit 1;
  if v_prompt is null then raise exception 'No prompt published today — tap "Generate new prompt" first.'; end if;

  -- Owners to populate: the caller, then the whole fake pool (so friends' profiles show gists too).
  for v_owner in
    select v_me
    union all
    select id from public.users where id::text like 'dddddddd-dddd-4ddd-8ddd-%'
  loop
    v_owner_idx := v_owner_idx + 1;

    -- ensure an open post for today's prompt
    select id, threshold into v_post, v_threshold
      from public.posts where profile_owner_id = v_owner and prompt_id = v_prompt;
    if v_post is null then
      insert into public.posts(profile_owner_id, prompt_id, threshold, spice_level)
        values (v_owner, v_prompt, public.compute_threshold(v_owner), v_tone)
        returning id, threshold into v_post, v_threshold;
    end if;

    -- fill with fake replies (authored by OTHER fake users) until comfortably graduated
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
                (v_count % 5 = 4),                                   -- ~1 in 5 private
                case when v_count % 5 = 4 then 'author' else null end);
      v_count := v_count + 1;
    end loop;

    -- fake a gist (placeholder mode generates none)
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

  return 'Generated replies + gists on the '||v_tone||' prompt for you and '
         ||(select count(*) from public.users where id::text like 'dddddddd-dddd-4ddd-8ddd-%')||' friends.';
end; $$;

-- =====================================================================
-- 4) dev_publish_next_prompt — rotate today's daily prompt to a fresh deck entry.
-- =====================================================================
create or replace function public.dev_publish_next_prompt()
returns text language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_text text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update public.prompts set publish_date = null where publish_date = current_date;
  select id, text into v_id, v_text
    from public.prompts where publish_date is null order by random() limit 1;
  if v_id is null then raise exception 'No unpublished prompts left in the deck.'; end if;
  update public.prompts set publish_date = current_date where id = v_id;
  return v_text;
end; $$;

-- =====================================================================
-- Grants — dev RPCs callable by signed-in users only (revoke anon/public).
-- =====================================================================
revoke all on function public.dev_seed_friends()        from public, anon;
revoke all on function public.dev_generate_responses()  from public, anon;
revoke all on function public.dev_publish_next_prompt() from public, anon;
grant execute on function
  public.dev_seed_friends(),
  public.dev_generate_responses(),
  public.dev_publish_next_prompt()
to authenticated;
