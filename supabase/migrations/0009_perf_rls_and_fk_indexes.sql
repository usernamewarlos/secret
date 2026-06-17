-- 0009_perf_rls_and_fk_indexes.sql
-- Performance hardening surfaced by the Supabase database advisors.
-- NO security or semantic change:
--   (1) Covering indexes for the six foreign keys the linter flagged as unindexed.
--   (2) Rewrite RLS policies so auth.uid() is evaluated ONCE per query — (select auth.uid()) —
--       instead of once per row (the auth_rls_initplan warning). Identical predicates,
--       identical roles (authenticated only), identical PERMISSIVE semantics; only the
--       query plan changes. Each policy is dropped+recreated inside this migration's
--       transaction, so there is no window where the table is unprotected.

-- ---------------------------------------------------------------------------
-- (1) Covering indexes for unindexed foreign keys
-- ---------------------------------------------------------------------------
create index if not exists idx_blocks_blocked_id     on public.blocks       (blocked_id);
create index if not exists idx_connections_connected on public.connections  (connected_user_id);
create index if not exists idx_gist_versions_gist_id on public.gist_versions(gist_id);
create index if not exists idx_gists_current_version on public.gists        (current_version_id);
create index if not exists idx_posts_prompt_id       on public.posts        (prompt_id);
create index if not exists idx_replies_author_id     on public.replies      (author_id);

-- ---------------------------------------------------------------------------
-- (2) RLS initplan: wrap auth.uid() in a scalar subquery (evaluated once).
-- ---------------------------------------------------------------------------

-- blocks ---------------------------------------------------------------------
drop policy "blocks read"   on public.blocks;
create policy "blocks read"   on public.blocks for select to authenticated
  using (blocker_id = (select auth.uid()));

drop policy "blocks insert" on public.blocks;
create policy "blocks insert" on public.blocks for insert to authenticated
  with check (blocker_id = (select auth.uid()));

drop policy "blocks delete" on public.blocks;
create policy "blocks delete" on public.blocks for delete to authenticated
  using (blocker_id = (select auth.uid()));

-- connections ----------------------------------------------------------------
drop policy "connections read"   on public.connections;
create policy "connections read"   on public.connections for select to authenticated
  using ((owner_id = (select auth.uid())) or (connected_user_id = (select auth.uid())));

drop policy "connections insert" on public.connections;
create policy "connections insert" on public.connections for insert to authenticated
  with check (owner_id = (select auth.uid()));

drop policy "connections update" on public.connections;
create policy "connections update" on public.connections for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

drop policy "connections delete" on public.connections;
create policy "connections delete" on public.connections for delete to authenticated
  using (owner_id = (select auth.uid()));

-- posts ----------------------------------------------------------------------
drop policy "posts insert by owner" on public.posts;
create policy "posts insert by owner" on public.posts for insert to authenticated
  with check (profile_owner_id = (select auth.uid()));

-- replies --------------------------------------------------------------------
drop policy "replies read" on public.replies;
create policy "replies read" on public.replies for select to authenticated
  using (
    (author_id = (select auth.uid()))
    or (
      (is_private = false)
      and exists (
        select 1 from public.posts p
         where p.id = replies.post_id
           and p.status = 'graduated'
           and public.can_view_profile(p.profile_owner_id)
      )
    )
  );

-- users ----------------------------------------------------------------------
drop policy "users insert self" on public.users;
create policy "users insert self" on public.users for insert to authenticated
  with check (id = (select auth.uid()));

drop policy "users update self" on public.users;
create policy "users update self" on public.users for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
