-- 0006_spice_level.sql — per-prompt spice/tone level (docs/ROADMAP.md §0, A3; PRODUCT.md §6.3).
--
-- Replaces the binary "spicy opt-in" with a graded, per-prompt comfort dial that reuses the
-- prompt tone tags as an ordered intensity scale:
--   wholesome (0) < playful (1) < social (2) < spicy (3).
--
--   * users.default_spice_level — the owner's standing comfort CEILING (onboarding/settings).
--   * posts.spice_level         — the EFFECTIVE level for that post (caps the prompt's tone).
--
-- Consent rule (active opt-in for over-ceiling prompts):
--   * If prompt.tone <= default_spice_level, the post auto-opens at spice_level = prompt.tone.
--   * If prompt.tone >  default_spice_level (e.g. a spicy prompt for a social owner), the post
--     stays CLOSED until the owner explicitly opens it via open_post (preserves active consent).
-- The owner may always dial a post DOWN (gentler) or UP to the prompt's inherent tone, never above.
-- The chosen level is what the gist generator reads as its tone input (GIST.md §7).

-- =====================================================================
-- Columns
-- =====================================================================
alter table public.users
  add column if not exists default_spice_level text not null default 'social'
    check (default_spice_level in ('wholesome','playful','social','spicy'));

alter table public.posts
  add column if not exists spice_level text not null default 'social'
    check (spice_level in ('wholesome','playful','social','spicy'));

-- =====================================================================
-- Tone ordering helper: wholesome 0 < playful 1 < social 2 < spicy 3.
-- Unknown/null tones default to 'social' (2) to match the column defaults.
-- =====================================================================
create or replace function public.tone_rank(t text)
returns int language sql immutable set search_path = '' as $$
  select case t
           when 'wholesome' then 0
           when 'playful'   then 1
           when 'social'    then 2
           when 'spicy'     then 3
           else 2
         end;
$$;

-- Inverse of tone_rank: the label for a given rank (used to cap a chosen level at the prompt's tone).
create or replace function public.tone_label(r int)
returns text language sql immutable set search_path = '' as $$
  select case r
           when 0 then 'wholesome'
           when 1 then 'playful'
           when 2 then 'social'
           when 3 then 'spicy'
           else 'social'
         end;
$$;

-- =====================================================================
-- open_post — the owner opens a prompt on their own profile at a chosen level.
-- Effective level = least(requested, prompt.tone) so it can be dialed DOWN (gentler) or set to
-- the prompt's inherent tone, never above it. Creates the post if absent (with the computed
-- threshold), otherwise updates its spice_level. Returns the post id.
-- =====================================================================
create or replace function public.open_post(p_owner uuid, p_prompt uuid, p_level text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid       uuid := auth.uid();
  v_tone      text;
  v_effective text;
  v_post_id   uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if v_uid <> p_owner then raise exception 'you can only open prompts on your own profile'; end if;

  select tone into v_tone from public.prompts where id = p_prompt;
  if v_tone is null then raise exception 'prompt not found'; end if;

  -- cap the requested level at the prompt's inherent tone (least rank wins)
  v_effective := public.tone_label(least(public.tone_rank(p_level), public.tone_rank(v_tone)));

  insert into public.posts (profile_owner_id, prompt_id, threshold, spice_level)
    values (p_owner, p_prompt, public.compute_threshold(p_owner), v_effective)
  on conflict (profile_owner_id, prompt_id)
    do update set spice_level = excluded.spice_level
  returning id into v_post_id;

  return v_post_id;
end; $$;

-- =====================================================================
-- set_post_spice — adjust an already-open post's level, capped at the prompt's tone.
-- =====================================================================
create or replace function public.set_post_spice(p_post uuid, p_level text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_owner     uuid;
  v_tone      text;
  v_effective text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;

  select p.profile_owner_id, pr.tone
    into v_owner, v_tone
    from public.posts p join public.prompts pr on pr.id = p.prompt_id
   where p.id = p_post;
  if v_owner is null then raise exception 'post not found'; end if;
  if v_owner <> auth.uid() then raise exception 'only the profile owner can set the spice level'; end if;

  v_effective := public.tone_label(least(public.tone_rank(p_level), public.tone_rank(v_tone)));

  update public.posts set spice_level = v_effective where id = p_post;
end; $$;

-- =====================================================================
-- submit_reply — recreate with the same signature, enforcing spicy opt-in.
-- When the post does not yet exist, only auto-create it if the prompt's tone is within the
-- owner's standing comfort (tone_rank(prompt.tone) <= tone_rank(owner.default_spice_level)),
-- setting spice_level = prompt.tone. Otherwise the owner must have opened it first via open_post;
-- raise 'owner has not opened this prompt'. All prior checks (auth, replier, block, status,
-- uniqueness) are preserved.
-- =====================================================================
create or replace function public.submit_reply(
  p_owner uuid, p_prompt uuid, p_body text, p_is_private boolean default false
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_post_id uuid;
  v_status  text;
  v_tone    text;
  v_reply_id uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not public.is_replier(p_owner) then raise exception 'not a replier on this profile'; end if;
  if exists (
    select 1 from public.blocks b
     where (b.blocker_id = p_owner and b.blocked_id = v_uid)
        or (b.blocker_id = v_uid   and b.blocked_id = p_owner)
  ) then raise exception 'blocked'; end if;

  select id, status into v_post_id, v_status
    from public.posts where profile_owner_id = p_owner and prompt_id = p_prompt;

  if v_post_id is null then
    -- The post hasn't been opened. Only auto-open it if the prompt is within the owner's
    -- standing comfort; over-ceiling (e.g. spicy) prompts require an explicit open_post.
    select tone into v_tone from public.prompts where id = p_prompt;
    if v_tone is null then raise exception 'prompt not found'; end if;
    if public.tone_rank(v_tone)
       > public.tone_rank((select default_spice_level from public.users where id = p_owner)) then
      raise exception 'owner has not opened this prompt';
    end if;

    insert into public.posts (profile_owner_id, prompt_id, threshold, spice_level)
      values (p_owner, p_prompt, public.compute_threshold(p_owner), v_tone)
      returning id, status into v_post_id, v_status;
  end if;

  if v_status not in ('accumulating','graduated') then
    raise exception 'post is not accepting replies';
  end if;

  insert into public.replies (post_id, author_id, body, is_private, privatized_by)
    values (v_post_id, v_uid, p_body, coalesce(p_is_private,false),
            case when coalesce(p_is_private,false) then 'author' else null end)
    returning id into v_reply_id;

  return v_reply_id;
exception when unique_violation then
  raise exception 'you have already replied to this prompt for this person';
end; $$;

-- =====================================================================
-- Grants (follow the 0004/0005 least-privilege pattern).
--   * The two new client RPCs go to `authenticated`; revoked from `anon`.
--   * The new immutable helpers tone_rank/tone_label are evaluated inside SECURITY DEFINER RPCs;
--     drop their PUBLIC/anon defaults too.
-- =====================================================================
revoke all on function public.tone_rank(text)               from public;
revoke all on function public.tone_rank(text)               from anon;
revoke all on function public.tone_label(integer)           from public;
revoke all on function public.tone_label(integer)           from anon;
revoke all on function public.open_post(uuid, uuid, text)   from public;
revoke all on function public.open_post(uuid, uuid, text)   from anon;
revoke all on function public.set_post_spice(uuid, text)    from public;
revoke all on function public.set_post_spice(uuid, text)    from anon;

grant execute on function
  public.open_post(uuid, uuid, text),
  public.set_post_spice(uuid, text)
to authenticated;
