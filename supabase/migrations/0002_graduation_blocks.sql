-- 0002_graduation_blocks.sql — graduation mechanics + blocking.
-- (docs/PRODUCT.md §6.5 graduation, §10 blocking.)

-- ---------- blocks ----------
create table if not exists public.blocks (
  id         uuid primary key default gen_random_uuid(),
  blocker_id uuid not null references public.users(id) on delete cascade,
  blocked_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table public.blocks enable row level security;
create policy "blocks read"   on public.blocks for select to authenticated using (blocker_id = auth.uid());
create policy "blocks insert" on public.blocks for insert to authenticated with check (blocker_id = auth.uid());
create policy "blocks delete" on public.blocks for delete to authenticated using (blocker_id = auth.uid());

-- ---------- auto-graduation on reply insert ----------
-- A post graduates the moment its reply count reaches its threshold.
create or replace function public.maybe_graduate_post()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_count int; v_threshold int; v_status text;
begin
  select threshold, status into v_threshold, v_status from public.posts where id = new.post_id;
  if v_status = 'accumulating' then
    select count(*) into v_count from public.replies where post_id = new.post_id;
    if v_count >= v_threshold then
      update public.posts set status = 'graduated', graduated_at = now() where id = new.post_id;
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists replies_graduate_trg on public.replies;
create trigger replies_graduate_trg
  after insert on public.replies
  for each row execute function public.maybe_graduate_post();

-- ---------- time fallback (cron-callable) ----------
-- Graduate posts past the window with >= floor replies; expire those that never reached it.
create or replace function public.graduate_stale_posts(p_window interval default '48 hours', p_floor int default 3)
returns int language plpgsql security definer set search_path = '' as $$
declare v_n int;
begin
  with done as (
    update public.posts p set status = 'graduated', graduated_at = now()
     where p.status = 'accumulating'
       and p.created_at < now() - p_window
       and (select count(*) from public.replies r where r.post_id = p.id) >= p_floor
    returning 1
  )
  select count(*) into v_n from done;

  update public.posts p set status = 'expired'
   where p.status = 'accumulating'
     and p.created_at < now() - p_window
     and (select count(*) from public.replies r where r.post_id = p.id) < p_floor;

  return v_n;
end; $$;

-- ---------- submit_reply: add a block check ----------
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
  if exists (
    select 1 from public.blocks b
     where (b.blocker_id = p_owner and b.blocked_id = v_uid)
        or (b.blocker_id = v_uid   and b.blocked_id = p_owner)
  ) then raise exception 'blocked'; end if;

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
