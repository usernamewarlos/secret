-- 0001_init.sql — Who Am I: full schema + Row Level Security.
--
-- Privacy model (docs/PRODUCT.md §6.7/§8/§10, docs/GIST.md §3):
--   * Blind accumulation: before graduation, ONLY the author can read a reply.
--   * Private = author-only: a private reply's BODY is readable ONLY by its author —
--     not the public, not viewers, NOT even the profile owner.
--   * Post-graduation: public reply bodies are visible to the owner + their connections;
--     private replies expose only (author + flag), surfaced as "🔒 X left a private reply"
--     via SECURITY DEFINER helpers — never the body.
--   * The owner can privatize (public -> private) but only the AUTHOR can reveal.
--   * All writes go through SECURITY DEFINER RPCs that enforce these rules; the base
--     tables expose only a read policy. The service_role (Edge Functions) bypasses RLS.

-- =====================================================================
-- Tables
-- =====================================================================

-- Public profile, keyed 1:1 to auth.users.
create table if not exists public.users (
  id             uuid primary key references auth.users(id) on delete cascade,
  display_name   text,
  photo_url      text,
  bio            text,
  dob            date,
  age_verified   boolean not null default false,
  verified_phone boolean not null default false,
  ig_handle      text,                                  -- display only; never an API data source
  created_at     timestamptz not null default now()
);

-- Owner-controlled relationships. role decides reach (viewer) vs trust (replier).
create table if not exists public.connections (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null references public.users(id) on delete cascade,
  connected_user_id uuid not null references public.users(id) on delete cascade,
  role              text not null default 'viewer' check (role in ('viewer','replier')),
  created_at        timestamptz not null default now(),
  unique (owner_id, connected_user_id),
  check (owner_id <> connected_user_id)
);

-- One global prompt per day. Authored deck rows start with publish_date = null.
create table if not exists public.prompts (
  id           uuid primary key default gen_random_uuid(),
  text         text not null,
  tone         text not null check (tone in ('wholesome','playful','social','spicy')),
  publish_date date unique,
  created_at   timestamptz not null default now()
);

-- A prompt instantiated on a specific profile.
create table if not exists public.posts (
  id               uuid primary key default gen_random_uuid(),
  profile_owner_id uuid not null references public.users(id) on delete cascade,
  prompt_id        uuid not null references public.prompts(id) on delete cascade,
  status           text not null default 'accumulating' check (status in ('accumulating','graduated','expired')),
  threshold        int  not null default 3,
  graduated_at     timestamptz,
  created_at       timestamptz not null default now(),
  unique (profile_owner_id, prompt_id)
);

create table if not exists public.replies (
  id            uuid primary key default gen_random_uuid(),
  post_id       uuid not null references public.posts(id) on delete cascade,
  author_id     uuid not null references public.users(id) on delete cascade,
  body          text not null,
  is_private    boolean not null default false,
  privatized_by text check (privatized_by in ('author','owner')),  -- who set the current private state
  created_at    timestamptz not null default now(),
  unique (post_id, author_id)                                      -- one reply per replier per post
);

create table if not exists public.gists (
  id                 uuid primary key default gen_random_uuid(),
  post_id            uuid not null unique references public.posts(id) on delete cascade,
  current_version_id uuid,
  created_at         timestamptz not null default now()
);

create table if not exists public.gist_versions (
  id                        uuid primary key default gen_random_uuid(),
  gist_id                   uuid not null references public.gists(id) on delete cascade,
  verdict                   text,
  body                      text not null,
  model                     text,
  tone_flag                 text,                 -- ok | thin | hostile
  excluded_count            int  not null default 0,
  reply_count_at_generation int  not null default 0,
  created_at                timestamptz not null default now()
);

alter table public.gists
  add constraint gists_current_version_fk
  foreign key (current_version_id) references public.gist_versions(id) on delete set null;

-- =====================================================================
-- Helper functions (SECURITY DEFINER so they can be used inside policies
-- without triggering recursive RLS).
-- =====================================================================

create or replace function public.can_view_profile(p_owner uuid)
returns boolean language sql security definer set search_path = '' stable as $$
  select p_owner = auth.uid()
      or exists (select 1 from public.connections c
                 where c.owner_id = p_owner and c.connected_user_id = auth.uid());
$$;

create or replace function public.is_replier(p_owner uuid)
returns boolean language sql security definer set search_path = '' stable as $$
  select exists (select 1 from public.connections c
                 where c.owner_id = p_owner and c.connected_user_id = auth.uid()
                   and c.role = 'replier');
$$;

-- threshold = clamp(ceil(0.5 * replier_count), 3, 10)   (PRODUCT.md §6.5)
create or replace function public.compute_threshold(p_owner uuid)
returns int language sql security definer set search_path = '' stable as $$
  select greatest(3, least(10, ceil(0.5 * count(*))::int))
  from public.connections where owner_id = p_owner and role = 'replier';
$$;

-- =====================================================================
-- Write RPCs (all SECURITY DEFINER; they ARE the write path).
-- =====================================================================

-- A replier submits one reply; the post is created on first reply.
create or replace function public.submit_reply(
  p_owner uuid, p_prompt uuid, p_body text, p_is_private boolean default false
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_post_id uuid;
  v_status  text;
  v_reply_id uuid;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  if not public.is_replier(p_owner) then raise exception 'not a replier on this profile'; end if;

  select id, status into v_post_id, v_status
    from public.posts where profile_owner_id = p_owner and prompt_id = p_prompt;

  if v_post_id is null then
    insert into public.posts (profile_owner_id, prompt_id, threshold)
      values (p_owner, p_prompt, public.compute_threshold(p_owner))
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

-- Author flips their OWN reply's privacy, either direction (reveal or privatize).
create or replace function public.set_my_reply_privacy(p_reply_id uuid, p_private boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.replies
     set is_private = p_private,
         privatized_by = case when p_private then 'author' else null end
   where id = p_reply_id and author_id = auth.uid();
  if not found then raise exception 'reply not found or not yours'; end if;
end; $$;

-- Owner buries a PUBLIC reply (public -> private). Owner cannot reveal (no-op if already private).
create or replace function public.owner_privatize_reply(p_reply_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
  select p.profile_owner_id into v_owner
    from public.replies r join public.posts p on p.id = r.post_id
   where r.id = p_reply_id;
  if v_owner is null then raise exception 'reply not found'; end if;
  if v_owner <> auth.uid() then raise exception 'only the profile owner can privatize'; end if;
  update public.replies set is_private = true, privatized_by = 'owner'
   where id = p_reply_id and is_private = false;
end; $$;

-- Revoke a person: delete their replies on the caller's posts AND the connection.
-- (Affected gists are regenerated by the regenerate-gists job.)
create or replace function public.revoke_connection(p_connected uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from public.replies r using public.posts p
   where r.post_id = p.id and p.profile_owner_id = auth.uid() and r.author_id = p_connected;
  delete from public.connections
   where owner_id = auth.uid() and connected_user_id = p_connected;
end; $$;

-- =====================================================================
-- Read RPCs that expose aggregates / markers WITHOUT leaking bodies.
-- =====================================================================

-- The "8 / 10" counter — a number, never the rows.
create or replace function public.post_reply_count(p_post_id uuid)
returns int language plpgsql security definer set search_path = '' stable as $$
declare v_owner uuid; v_count int;
begin
  select profile_owner_id into v_owner from public.posts where id = p_post_id;
  if v_owner is null or not public.can_view_profile(v_owner) then raise exception 'not authorized'; end if;
  select count(*) into v_count from public.replies where post_id = p_post_id;
  return v_count;
end; $$;

-- Named private markers: "🔒 X left a private reply" — author + name only, never the body,
-- and only after graduation.
create or replace function public.post_private_markers(p_post_id uuid)
returns table (author_id uuid, display_name text)
language plpgsql security definer set search_path = '' stable as $$
declare v_owner uuid; v_status text;
begin
  select profile_owner_id, status into v_owner, v_status from public.posts where id = p_post_id;
  if v_owner is null or not public.can_view_profile(v_owner) then raise exception 'not authorized'; end if;
  if v_status <> 'graduated' then return; end if;   -- pre-graduation: expose nothing
  return query
    select r.author_id, u.display_name
      from public.replies r join public.users u on u.id = r.author_id
     where r.post_id = p_post_id and r.is_private = true;
end; $$;

-- =====================================================================
-- Triggers
-- =====================================================================

-- Reply body / author / post are immutable once written (honesty rule).
create or replace function public.replies_guard_immutable()
returns trigger language plpgsql as $$
begin
  if new.body <> old.body then raise exception 'reply body is immutable'; end if;
  if new.author_id <> old.author_id or new.post_id <> old.post_id then
    raise exception 'reply author/post are immutable';
  end if;
  return new;
end; $$;
create trigger replies_guard_immutable_trg
  before update on public.replies
  for each row execute function public.replies_guard_immutable();

-- Auto-create a public.users row when an auth user signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.users (id) values (new.id) on conflict (id) do nothing;
  return new;
end; $$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =====================================================================
-- Row Level Security
-- =====================================================================

alter table public.users         enable row level security;
alter table public.connections   enable row level security;
alter table public.prompts       enable row level security;
alter table public.posts         enable row level security;
alter table public.replies       enable row level security;
alter table public.gists         enable row level security;
alter table public.gist_versions enable row level security;

-- users: profiles are readable by any authenticated user (needed to render names); self-write only.
create policy "users readable" on public.users for select to authenticated using (true);
create policy "users insert self" on public.users for insert to authenticated with check (id = auth.uid());
create policy "users update self" on public.users for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- connections: visible to owner or the connected person; only the owner writes.
create policy "connections read" on public.connections for select to authenticated
  using (owner_id = auth.uid() or connected_user_id = auth.uid());
create policy "connections insert" on public.connections for insert to authenticated
  with check (owner_id = auth.uid());
create policy "connections update" on public.connections for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "connections delete" on public.connections for delete to authenticated
  using (owner_id = auth.uid());

-- prompts: globally readable; writes are service_role only (Edge Function).
create policy "prompts read" on public.prompts for select to authenticated using (true);

-- posts: visible to the profile audience; owner may open (insert). Status changes are service_role.
create policy "posts read" on public.posts for select to authenticated
  using (public.can_view_profile(profile_owner_id));
create policy "posts insert by owner" on public.posts for insert to authenticated
  with check (profile_owner_id = auth.uid());

-- replies: the load-bearing policy.
--   * The author can always read their own reply.
--   * Everyone else sees a reply ONLY if it is public AND the post graduated AND they may view the profile.
--   * Private bodies are therefore author-only. Writes go through the RPCs above (no insert/update/delete policy).
create policy "replies read" on public.replies for select to authenticated
  using (
    author_id = auth.uid()
    or (
      is_private = false
      and exists (
        select 1 from public.posts p
        where p.id = replies.post_id
          and p.status = 'graduated'
          and public.can_view_profile(p.profile_owner_id)
      )
    )
  );

-- gists / versions: readable to the audience once the post graduated; writes are service_role only.
create policy "gists read" on public.gists for select to authenticated
  using (exists (select 1 from public.posts p
                 where p.id = gists.post_id and p.status = 'graduated'
                   and public.can_view_profile(p.profile_owner_id)));
create policy "gist_versions read" on public.gist_versions for select to authenticated
  using (exists (select 1 from public.gists g join public.posts p on p.id = g.post_id
                 where g.id = gist_versions.gist_id and p.status = 'graduated'
                   and public.can_view_profile(p.profile_owner_id)));

-- =====================================================================
-- Grants for client-callable RPCs
-- =====================================================================
grant execute on function
  public.can_view_profile(uuid),
  public.is_replier(uuid),
  public.compute_threshold(uuid),
  public.submit_reply(uuid, uuid, text, boolean),
  public.set_my_reply_privacy(uuid, boolean),
  public.owner_privatize_reply(uuid),
  public.revoke_connection(uuid),
  public.post_reply_count(uuid),
  public.post_private_markers(uuid)
to authenticated;
