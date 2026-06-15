# Who Am I — PRD-vs-Implementation Gap Report

*Staff engineering audit · 2026-06-15 · repo `/Users/jackgagnon/who-am-i`*

The backend (Postgres schema, RLS, RPCs, gist generation) is genuinely strong and faithfully implements the hardest, highest-risk parts of the spec. The gaps cluster in three places: **production auth/verification is unbuilt**, **the daily-loop and growth surfaces are thin or absent**, and **nothing is actually scheduled** (cron exists in code, not in the deployed project). Below, percentages are rough engineering estimates, not precise line counts.

---

## 1. Scorecard

| Scope | Implemented | One-line justification |
|---|---:|---|
| **Overall PRD** | **~68%** | Data model, RLS, privacy/safety, graduation math, and gist synthesis are excellent; verification, growth loops, notifications, and scheduling are missing or scaffold-only. |
| **Phase 1 — Identity** | **~55%** | Age gate + email auth + profile work, but phone OTP is dead code, DOB is discarded, and `age_verified` is hardcoded `true` — the *completion criterion* (phone SMS verification) is unmet. |
| **Phase 2 — Daily loop** | **~75%** | Prompt-of-the-day, reply submission, blind accumulation, graduation, and curation all work; missing char cap, participation nudges, weekday cadence, and a live cron. |
| **Phase 3 — Gist AI** | **~85%** | Voice, bright lines, consensus rule, accretion, versioning, tone calibration, and a safety check are all in. Gaps: no safety retry/fallback, no 24h rate cap, `owner_display_name` not passed, no drift monitoring. |
| **Phase 4 — Curation** | **~90%** | Privacy model (privatize-not-reveal, named private markers, author-only bodies, immutability) is fully RLS-enforced and faithful — the strongest area in the codebase. |
| **Phase 5 — Growth** | **~20%** | Share-card exists; reciprocity hook, deep links, reveal/evolution share cards, all nudges, and the entire notification system (incl. APNs, batching, prefs, schema) are missing. |

---

## 2. Gap Matrix

Counts are item-level from the audit (an item appearing in two areas, e.g. char cap, is counted in each).

| Area | Implemented | Partial | Missing | Divergent | Notable items |
|---|---:|---:|---:|---:|---|
| Onboarding (§6.1 / P1) | 4 | 4 | 3 | 1 | **Phone OTP missing** (dead code); DOB discarded; `age_verified` hardcoded true (divergent); no backend age enforcement |
| Connections (§6.2/§10) | 9 | 4 | 1 | 2 | Roles/asymmetry/block/immutability solid; **spicy opt-in missing**, **char cap missing**; revoke→gist regen deferred to cron; no stale flag (divergent) |
| Prompts | 14 | 3 | 4 | 0 | One-per-day + deck solid; **weekday cadence, spicy opt-in, char cap missing**; cron not scheduled; safety retry partial |
| Replies (§6.4) | 11 | 0 | 3 | 0 | Who-can-reply, blind accumulation, immutability, privacy flip solid; **char cap + both participation nudges missing** |
| Graduation | 13 | 1 | 3 | 1 | Threshold math, time-fallback, accretion solid; **"gist ready" notification never fired**, **cron not scheduled**; revoke-stale flag divergent |
| Gist (GIST.md) | 41 | 9 | 5 | 0 | Voice/bright-lines/consensus/accretion/versioning solid; **safety retry+fallback, 24h cap, owner_display_name, drift monitoring missing** |
| Privacy | 26 | 0 | 1 | 0 | Fully RLS-enforced; only **char cap missing** |
| Profile screens (§9) | 14 | 9 | 3 | 0 | Profile/curate/connections/gist-detail/evolution solid; onboarding+today partial; **nudges, spicy opt-in, char cap missing**; block-on-add gap |
| Notifications (§6.9/P5) | 0 | 3 | 9 | 0 | **Entire system missing**: no schema, no APNs, no batching, no fan-out; `notifyGistReady` defined but never called |
| Sharing/Growth | 5 | 1 | 5 | 0 | Share-card solid; **reciprocity hook, deep links, reveal/evolution cards, nudges missing** — growth loop is broken |
| Data model + RLS | 22 | 2 | 0 | 0 | Schema and write-path enforcement near-complete; revoke→regen partial; block-on-add partial |

---

## 3. What's Solid (faithful to spec)

These match the spec well and are the foundation to build on:

- **Privacy & safety model (Phase 4) — the crown jewel.** Author-only private bodies, owner-can-privatize-but-never-reveal (`owner_privatize_reply` checks `is_private=false`, `0001_init.sql:175-186`), named private markers exposed only post-graduation (`post_private_markers`, `:217-229`), reply body immutability via trigger (`replies_guard_immutable`, `:236-247`), and no individual-delete path. All enforced at the **data layer via RLS** (`:300-312`), not the UI — exactly as §10 demands.
- **Blind accumulation** is symmetric and RLS-enforced: pre-graduation only an aggregate counter is exposed (`post_reply_count`, `:205-213`); no rows leak to owner or visitors. This neutralizes the "friend screenshots and sends" anti-pattern.
- **Graduation math.** `compute_threshold` = `greatest(3, least(10, ceil(0.5*count)))` matches the spec formula exactly (`0001_init.sql:117-121`); auto-graduate trigger and 48h time-fallback with `MIN_FLOOR=3` (`0002_graduation_blocks.sql:20-60`) are correct.
- **Gist generation engine (Phase 3).** System prompt encodes the golden rule, consensus rule, tone-laundering, all seven bright lines, and per-tone calibration (`_shared/gist.ts:23-44`); private replies and author identities are excluded from the generator (`:111-116`); append-only `gist_versions` with accretion (`:46-47, 126-141`); Sonnet @ temp 0.8, `max_tokens 700`, JSON structured output; a Haiku second-pass safety check that **fails closed** (`:84-99`).
- **Write-path architecture.** Replies have no direct insert/update/delete RLS policies — every write routes through `SECURITY DEFINER` RPCs that check `is_replier`, block status, and uniqueness. Robust against policy bugs.
- **Connections model.** Owner-controlled viewer/replier roles, default viewer, asymmetry, and symmetric block (in `submit_reply`, `0002:74-78`) all work.
- **Gist share-card.** `GistShareCard.swift` / `GistShareView.swift` render a screenshot-ready 360×480 card via `ImageRenderer` + system `ShareLink`.

---

## 4. Gaps That Matter (ranked by product impact)

Flagged: **[SAFETY]** privacy/safety bright line · **[LOOP]** daily loop · **[GRAD]** graduation · **[GROWTH]** growth.

1. **Phone (SMS OTP) verification is unbuilt — Phase 1 cannot be called complete. [LOOP]**
   `PhoneVerifyView`/`PhoneVerifyViewModel` exist but are **dead code**; `OnboardingView.swift:10-14` routes age-gate → `EmailAuthView` → profile. Phone OTP is the spec's *recommended primary verification* (§6.1) and the literal Phase 1 completion criterion (PRODUCT.md:230). `verified_phone` is never set true (`AuthService.verifyOTP` doesn't touch it). **This blocks any real launch.**

2. **`age_verified` is hardcoded `true` for every profile + DOB is discarded. [SAFETY]**
   `ProfileService.upsert()` writes `age_verified: true` unconditionally (`ProfileService.swift:50`), with no connection to `AgeGateViewModel.isEligible()`. DOB is validated then thrown away — never passed to `upsert`, schema column `dob` (`0001_init.sql:24`) always null. This **directly undercuts hard constraint #1** ("do not knowingly admit under-18 users"): no audit trail, no re-verification, and the flag is a stub. The gate is also client-side only (no RLS/trigger enforcement).

3. **Nothing is actually scheduled — the daily loop and graduation fallback don't run in production. [LOOP][GRAD]**
   `publish-daily-prompt` and `regenerate-gists` exist and `graduate_stale_posts` is callable, but **no `cron.schedule` SQL is committed** (grep finds none in migrations) and `config.toml` defines functions without a schedule. Without an external trigger, the daily prompt never publishes and stale posts never graduate/expire. The "one fixed global time" (§11 decision #4) is also not pinned anywhere.

4. **The entire notification system is missing. [LOOP][GROWTH]**
   No notifications table, no APNs capability in `project.yml`, no fan-out Edge Function, no batching/rate-limit infra, no preferences. `notifyGistReady` is defined (`NotificationService.swift:19-26`) but **never called** — graduation fires no notification, breaking the §6.5 "Your gist is ready 👀" dopamine moment and all §6.9 retention drivers. The spec's hard rule "never notify per individual reply" has no infrastructure to honor.

5. **Reciprocity hook + deep links missing — the growth loop is broken. [GROWTH]**
   No "you answered Jack's — see what Jack said about you" surface; `ShareLink` shares an *image only*, not a deep link, despite the `whoami://` scheme being declared (`Info.plist:27-29`) and `WhoAmIApp.swift` having no `onOpenURL` handler. §6.10's reciprocity-capturing deep-link is the core viral mechanic and it's absent.

6. **Both participation nudges missing. [LOOP][GROWTH]**
   No "3 friends are waiting on your answer" (§6.4 mitigation 1) and no "be the one to unlock it" visitor prompt on near-graduation posts (mitigation 2). `TodayView` shows a flat target list with no proximity ranking; `PostRowView` shows "needs X more" with no CTA. These are the spec's primary defense against the participation cold-start.

7. **Spicy prompt opt-in entirely absent. [SAFETY]**
   §6.3 requires owner opt-in for spicy prompts. Grep finds **zero** opt-in fields/RPCs/UI across `.sql/.swift/.ts`. Spicy prompts are served to everyone implicitly — a consent/trust gap, especially given spicy = "maximum teeth."

8. **Gist safety check has no retry/fallback. [SAFETY]**
   On safety failure the function returns early "failed safety check — not published" (`_shared/gist.ts:144-146`). §15 requires: regenerate once with reinforced instruction, then fall back to a safe warm template. Current behavior leaves a graduated post with **no gist at all** if the classifier is over-conservative — a broken dopamine moment.

9. **No reply character cap anywhere. [LOOP]**
   §6.4 recommends 280–500 chars. `AnswerView.swift:44` has only `lineLimit(3...8)` (visual), `submit_reply` accepts any length, no DB CHECK. Unbounded replies risk gist-synthesis and share-card quality.

10. **Revoke-after-graduation: no staleness flag. [GRAD][SAFETY]**
    §10 says drop a post below `MIN_FLOOR` → keep the version but flag it stale / stop it claiming more than it supports. No `stale` field on `gist_versions`; the gist silently regenerates (or persists) and can keep growing. Integrity gap requiring a schema change.

11. **No 24h regeneration rate cap.** §14 specifies ≤1 growth-driven regen per post per ~24h (revoke bypasses). No timestamp gate in `regenerate-gists/index.ts` — a viral post can regenerate repeatedly in a day, driving cost.

12. **Block doesn't prevent being added as a connection.** `ConnectionsService.add()` / connections insert policy (`0001:280`) check only `owner_id=auth.uid()`, no block check. §10 requires blocking to prevent adding "in either direction"; only *replying* is blocked.

---

## 5. Divergences From Spec

| # | Divergence | Intentional? | Notes |
|---|---|---|---|
| D1 | **Email auth instead of phone OTP** in the live flow | Intentional (dev) | Acknowledged in `EmailAuthViewModel.swift:4-5` as the testable substitute; phone "remains the production plan." Acceptable *only* until launch — see P0. |
| D2 | **`age_verified` hardcoded `true`** regardless of gate pass | Likely unintentional | `ProfileService.swift:50`. Treats the flag as a stub; not tied to `isEligible()`. Safety-relevant. |
| D3 | **DOB collected then discarded** (never persisted) | Unintentional | Defeats re-verification/audit; schema `dob` column unused. |
| D4 | **AI gist not deployed / placeholder-mode triggers** | Environmental | `0003` instant-generation trigger is a **no-op** unless `app.functions_base_url` + `app.service_role_key` are set in Postgres config; relies on the (unscheduled) `regenerate-gists` cron as fallback. So in the repo state, gists may not generate at all. |
| D5 | **Cron not scheduled** (publish/regenerate/graduate-stale) | Environmental/incomplete | Functions ready; no committed `cron.schedule`. Must be configured in the remote project. |
| D6 | **Revoke → gist regen is batched, not immediate** | Borderline | `revoke_connection` hard-deletes replies but only the daily cron regenerates; §6.2 language implies promptness. Acceptable per GIST.md §14 *if documented*, but revoked influence can linger up to a cron cycle. |
| D7 | **No staleness flag on revoke-below-floor** | Unintentional | §10 integrity feature unbuilt (schema gap). |
| D8 | **Missing reply char cap** | Unintentional | Recommendation in §6.4 not implemented at any layer. |
| D9 | **Missing participation nudges** | Deferred (P5) | Both §6.4 mitigations absent. |
| D10 | **Missing prompt weekday/weekend cadence** | Unintentional | `publish-daily-prompt:15` orders strictly by `created_at`, ignoring day-of-week; no `publish_day_of_week` column. |
| D11 | **Missing spicy opt-in** | Unintentional | No consent surface; §6.3 violated. |
| D12 | **`owner_display_name` not passed to generator** | Unintentional | GIST.md §3 lists it as a required input; only the system-prompt "use second person" instruction stands in. |
| D13 | **Safety failure ≠ regenerate/fallback** | Unintentional | §15 retry+template path unbuilt. |

---

## 6. Prioritized Backlog to Full PRD Compliance

### P0 — Blocks a real launch

- **P0-1 Wire phone OTP into onboarding.** Route `AgeGateView → PhoneVerifyView → ProfileSetupView` in `OnboardingView.swift:10-14`; have `AuthService.verifyOTP` set `verified_phone=true` (`AuthService.swift:45-46`). Keep email auth behind a dev flag. *(§6.1, Phase 1 completion)*
- **P0-2 Persist age attestation correctly.** Pass DOB from `AgeGateViewModel` → `ProfileSetupViewModel` → `ProfileService.upsert` (add `dob` to signature + Payload, `ProfileService.swift:38-50`); set `age_verified` from the actual gate result, not hardcoded `true`. Backfill the unused `dob`/`age_verified` columns. *(hard constraint #1)*
- **P0-3 Schedule the cron jobs.** Commit `cron.schedule` for `publish-daily-prompt` (one fixed UTC time), `regenerate-gists`, and `graduate_stale_posts(48h, 3)`. Add a migration or documented deploy step; pin the canonical publish time. *(§11 #4, §6.5)*
- **P0-4 Ensure gist generation actually fires.** Set `app.functions_base_url` + `app.service_role_key` so the `0003` trigger isn't a no-op, OR guarantee the scheduled `regenerate-gists` covers first-generation. Verify end-to-end on a graduated post. *(GIST.md §4)*
- **P0-5 Spicy opt-in + consent.** Add `users.spicy_opted_in` (or per-prompt opt-in), gate spicy prompts in `submit_reply`/`TodayView`, and add the opt-in UI. *(§6.3, safety)*
- **P0-6 Gist safety retry + fallback template.** In `_shared/gist.ts:144`, on failure regenerate once with reinforced constraints; if still failing, publish a safe warm template and log. Never leave a graduated post gist-less. *(§15)*

### P1 — Core experience / retention

- **P1-1 "Your gist is ready" notification.** Minimum: wire `notifyGistReady` to fire on graduation (client poll or Realtime subscription on `posts.status`). Target: server-side fan-out Edge Function. *(§6.5)*
- **P1-2 Notification infrastructure foundation.** Add `notifications` + `user_notification_preferences` tables, a batching job (reuse `regenerate-gists` cadence/thresholds), and the "never per-reply" guarantee. *(§6.9)*
- **P1-3 Reply character cap (280–500).** Enforce in `AnswerView.swift:44` (maxLength), `AnswerViewModel.submit`, **and** a DB CHECK on `replies.body`. *(§6.4)*
- **P1-4 Participation nudges.** "X friends waiting" in `TodayView` (rank targets by threshold proximity) and "be the one to unlock it" CTA in `PostRowView`/profile for near-graduation posts. *(§6.4 mitigations)*
- **P1-5 Reciprocity hook + deep links.** Add `onOpenURL` for `whoami://` in `WhoAmIApp.swift`, attach a deep link to `ShareLink`, and surface "see what they said about you" when viewing a profile you've answered. *(§6.10, growth loop)*
- **P1-6 24h regeneration rate cap.** Gate growth-driven regens in `regenerate-gists/index.ts` on `gist_versions.created_at < now()-24h`; bypass for revoke-driven. *(§14)*
- **P1-7 Pass `owner_display_name` to the generator.** Fetch from `users` and include in the generator input in `_shared/gist.ts:136-139`. *(GIST.md §3)*

### P2 — Polish / completeness

- **P2-1 Revoke-stale integrity.** Add a `stale` flag (and/or `max_reply_count`) to `gist_versions`; mark stale when revoke drops a graduated post below `MIN_FLOOR`; render accordingly. *(§10, §16)*
- **P2-2 Block-on-add.** Add a block check to `ConnectionsService.add()` and the connections insert policy (`0001:280`). *(§10)*
- **P2-3 Weekday/weekend prompt cadence.** Add `publish_day_of_week` (or tone filtering by DOW) to `publish-daily-prompt`. *(§6.3)*
- **P2-4 Drift monitoring.** Log/dashboard `excluded_count` and `tone_flag` distributions to catch prompts pulling toward the bright lines. *(§15)*
- **P2-5 Reveal cards + evolution share cards.** Generate shareable artifacts on reveal and "then vs now" evolution (build on existing `GistEvolutionView` + `GistShareCard`). *(§6.10, §7)*
- **P2-6 Expand prompt deck** from 19 → 30–50 with balanced tones. *(Phase 2 recommendation)*
- **P2-7 Tunable constants.** Move hardcoded `MIN_FLOOR/MAX_CEIL/factor/window/GROWTH_*` into a config table for runtime tuning. *(§6.5, §14)*
- **P2-8 Optional photo in profile setup** UI (schema already supports `photo_url`). *(§6.1)*

---

**Bottom line:** The risky, irreversible parts (privacy enforcement, safety bright lines, graduation integrity, gist synthesis) are built well and at the data layer. What stands between this and a launchable product is mostly *plumbing and growth surface*: turn on verification, wire and schedule the loop, fire notifications, and close the reciprocity/nudge gaps. The two items that are both easy to miss and genuinely unsafe are **D2/D3 (age attestation hardcoded + DOB discarded)** and **the missing spicy opt-in** — treat those as launch blockers alongside phone verification.

Key file pointers: `/Users/jackgagnon/who-am-i/WhoAmI/WhoAmI/Features/Onboarding/OnboardingView.swift`, `/Users/jackgagnon/who-am-i/WhoAmI/WhoAmI/Core/Services/ProfileService.swift` (lines 38-50), `/Users/jackgagnon/who-am-i/WhoAmI/WhoAmI/Core/Services/AuthService.swift` (lines 45-46), `/Users/jackgagnon/who-am-i/supabase/functions/_shared/gist.ts` (lines 84-99, 136-146), `/Users/jackgagnon/who-am-i/supabase/functions/regenerate-gists/index.ts` (lines 8-9, 46-49), `/Users/jackgagnon/who-am-i/supabase/migrations/0001_init.sql` (lines 25, 175-186, 300-312), `/Users/jackgagnon/who-am-i/supabase/migrations/0003_gist_autogenerate.sql` (lines 15-37), `/Users/jackgagnon/who-am-i/WhoAmI/WhoAmI/Core/Notifications/NotificationService.swift` (lines 19-26), `/Users/jackgagnon/who-am-i/supabase/config.toml`.
