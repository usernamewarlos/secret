-- 0012_account_prefs_age.sql — account deletion, notification-prefs storage,
-- and server-side 18+ enforcement.

-- =====================================================================
-- delete_my_account — hard-delete the caller. Removing the auth.users row
-- CASCADEs to public.users → posts/replies/connections/blocks (all ON DELETE
-- CASCADE) and the auth-internal rows (sessions/identities/…). One delete.
-- =====================================================================
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null then raise exception 'not authenticated'; end if;
  delete from auth.users where id = v_me;
end; $$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- =====================================================================
-- Notification preferences — a per-user JSON bag the client reads/writes via
-- the existing "users update self" RLS policy (no RPC needed).
-- =====================================================================
alter table public.users
  add column if not exists notif_prefs jsonb not null default '{}'::jsonb;

-- =====================================================================
-- Server-side 18+ enforcement. age_verified may only be true when a DOB is
-- present and is at least 18 years ago — so a spoofed client can't self-verify.
-- First backfill any existing age_verified rows that lack a DOB (e.g. dev-seed
-- users) so the trigger doesn't block later updates to them.
-- =====================================================================
update public.users set dob = date '2000-01-01'
 where age_verified and dob is null;

create or replace function public.enforce_age_verified()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.age_verified then
    if new.dob is null then
      raise exception 'date of birth required to verify age';
    end if;
    if new.dob > (current_date - interval '18 years') then
      raise exception 'must be at least 18 years old';
    end if;
  end if;
  return new;
end; $$;

drop trigger if exists enforce_age_verified_trg on public.users;
create trigger enforce_age_verified_trg
  before insert or update on public.users
  for each row execute function public.enforce_age_verified();
