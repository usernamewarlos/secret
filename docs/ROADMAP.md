# Who Am I — Remediation & Launch Plan

> Derived from the PRD-vs-implementation gap analysis (`docs/research/prd-gap-analysis.md`) and the market/regulatory research (`docs/research/market-research.md`). Sequenced so the items that are **both** a code gap **and** a market/legal risk come first.

---

## 0. Design decision — per-prompt spice/tone level (replaces the binary "spicy opt-in")

**Decision:** the profile owner controls the spice/tone level **per prompt**, on a graded scale, instead of a one-time all-or-nothing "I'm down for spicy" switch.

**The scale** reuses the existing prompt tone tags as an ordered intensity dial:
`wholesome (0) < playful (1) < social (2) < spicy (3)`.

**Model (global default + per-day override + skip):**
- `users.default_spice_level` — the owner's standing comfort ceiling, chosen in onboarding/settings (recommended default: `social`).
- Each day's prompt carries its deck `tone`. When it drops:
  - If `prompt.tone ≤ default_spice_level` → the post **auto-opens** at `spice_level = prompt.tone`.
  - If `prompt.tone > default_spice_level` (e.g. a `spicy` prompt for a `social` owner) → the post stays **closed** until the owner explicitly opts in for that day (this preserves the active-consent requirement for spicy content).
  - The owner can always **override per day**: dial down (gentler), dial up to the prompt's inherent tone, or **skip** (post never opens, prompt doesn't appear on their profile).
- `posts.spice_level` stores the effective level for that post.

**What the level drives:**
1. **Consent gate** — whether the prompt opens on this profile and how hard.
2. **Gist calibration** — the generator reads `posts.spice_level` (not just `prompts.tone`) as its tone input (`GIST.md` §7). The bright lines (§9) are unchanged at every level.
3. **Replier guidance** — repliers see the owner's chosen level ("Olivia set this to 🌶️ Spicy — go for it" / "keep it playful"), shaping input quality.

**Why this is the right call:** it gives owners graduated, per-prompt control over how they're portrayed — which is exactly the consent/safety lever the market research says these apps need (the spicy/roast framing is the highest-harm surface), and it resolves PRD open decision §11.2 and the missing-opt-in gap in one move.

**Touches:** `users` + `posts` schema; `submit_reply` (reject replies to unopened/over-ceiling posts); a new `open_post(prompt, level)` / `set_post_spice(post, level)` RPC; `_shared/gist.ts` input; `Today` UI (a per-prompt level control); `AnswerView` (show the level to repliers); spec updates to `PRODUCT.md §6.3/§11.2` and `GIST.md §7`.

---

## Milestone A — Safety & legal launch-blockers
*These are where a market/legal risk and a code gap are the same thing. Do first.*

| # | Item | Concern it closes | Where |
|---|---|---|---|
| A1 | **Fix age attestation.** Persist DOB through `AgeGateViewModel → ProfileSetupViewModel → ProfileService.upsert` (add `dob` param); set `age_verified` from the actual gate result, not hardcoded `true`. | Gap D2/D3 + market "weak age gate = NGL/FTC vector" (the #1 legal risk) | `Features/Onboarding/*`, `Core/Services/ProfileService.swift:38-50` |
| A2 | **Real age-assurance + state config.** Move beyond a neutral DOB gate toward actual verification friction; make it configurable for the state-by-state patchwork (Mississippi enforceable now). Server-side enforcement, not client-only. | Market regulatory map | new; auth/onboarding + a config table |
| A3 | **Per-prompt spice/tone level** (section 0). | Gap P0-5 + market consent/safety | schema, `submit_reply`, `Today`/`AnswerView`, gist |
| A4 | **AI-gist defamation fail-safe.** On safety-check failure: regenerate once with reinforced constraints, then fall back to a safe warm template — never publish a flagged gist or leave a graduated post gist-less. Add opinion/disclaimer framing ("in your friends' eyes") on the gist + share card. Verify the bright-line block on assertable facts (crimes/infidelity/health) holds. | Gap P0-6 + market "gist = first-party speech, likely not §230-shielded" (gravest novel risk) | `_shared/gist.ts:84-99,144-146`; `PostDetailView`, `GistShareCard` |
| A5 | **Trust & safety surface.** In-app **report** (block exists; add report), a 24h takedown SLA, support contact, and **abuse scanning on private replies** that flags content for review without exposing it to the owner (reconciles author-only-private with Apple 1.2 / Play mandatory-reporting). | Market app-store delisting + private-reply-vs-reporting tension | new Edge Function + tables; `Connections`/`PostDetail` UI |
| A6 | **Conservative moderation copy + crisis-comms playbook.** Every public safety/AI claim literally true and modest (NGL was fined for over-claiming); a pre-written T&S response. | Market PR / *Bride v. YOLO* | copy + ops doc |

---

## Milestone B — Turn the loop on
*The backend exists but nothing runs.*

| # | Item | Concern | Where |
|---|---|---|---|
| B1 | **Wire phone OTP into onboarding** (`AgeGate → PhoneVerify → ProfileSetup`); set `verified_phone=true` on success; keep email auth behind a dev flag. | Gap P0-1 (Phase 1 completion) | `Features/Onboarding/OnboardingView.swift`, `Core/Auth/AuthService.swift:45-46` |
| B2 | **Schedule cron** via `pg_cron`: `publish-daily-prompt` (one fixed UTC time — pins §11 #4), `regenerate-gists`, `graduate_stale_posts(48h,3)`. Commit as a migration. | Gap P0-3 | new migration; `supabase/config.toml` |
| B3 | **Guarantee gist generation fires.** Set `app.functions_base_url` + `app.service_role_key` so the `0003` trigger isn't a no-op, or rely on the scheduled `regenerate-gists` first-gen path; verify end-to-end on a graduated post. | Gap P0-4 / divergence D4 | `0003_gist_autogenerate.sql`, Edge env |
| B4 | **Reply character cap (280–500):** `AnswerView` maxLength + `AnswerViewModel` + a DB `CHECK` on `replies.body`. | Gap P1-3 | `Features/Today/Answer*`, migration |
| B5 | **Pass `owner_display_name` to the generator** (GIST.md §3 required input). | Gap P1-7 | `_shared/gist.ts:136-139` |
| B6 | **24h regeneration rate cap** (gate growth-driven regens on `gist_versions.created_at`; revoke bypasses). | Gap P1-6 / §14 | `regenerate-gists/index.ts` |
| B7 | **Revoke-stale integrity:** `stale` flag on `gist_versions`; mark when revoke drops a graduated post below `MIN_FLOOR`. | Gap P2-1 / §10 | migration + `revoke_connection` + UI |

---

## Milestone C — Retention engine
*Per the market research, this is where every comparable app died. It's also our least-built layer (Phase 5 ~20%).*

| # | Item | Concern | Where |
|---|---|---|---|
| C1 | **Notification infrastructure:** `notifications` + `user_notification_preferences` tables, APNs capability in `project.yml`, a fan-out Edge Function, and batching that honors "never per-reply." | Gap P1-2 / §6.9 | new; `Core/Notifications/*` |
| C2 | **"Your gist is ready 👀" + "gist evolved"** wired to graduation/regen (client Realtime subscription on `posts.status` as a minimum; server fan-out as the target). | Gap P1-1 / §6.5 | `NotificationService.swift:19-26` (currently never called) |
| C3 | **Participation nudges:** "X friends are waiting on your answer" (rank `Today` targets by threshold proximity) + "be the one to unlock it" CTA on near-graduation posts. | Gap P1-4 / §6.4 | `Features/Today/*`, `PostRowView` |
| C4 | **Reciprocity + deep links:** `onOpenURL` for `whoami://` in `WhoAmIApp`, attach a deep link to `ShareLink`, and a "see what they said about you" hook when viewing a profile you've answered. | Gap P1-5 / §6.10 (core viral loop) | `WhoAmIApp.swift`, `Features/Share/*`, profile |

---

## Milestone D — Growth surfaces & polish
| # | Item | Concern |
|---|---|---|
| D1 | Reveal cards + "then vs now" evolution share cards (build on `GistEvolutionView` + `GistShareCard`). | Gap P2-5 / §6.10 |
| D2 | Expand prompt deck 19 → 30–50, balanced tones; add weekday/weekend cadence (`publish_day_of_week`). | Gap P2-3/P2-6 |
| D3 | Drift monitoring — dashboard `excluded_count` / `tone_flag` distributions to catch prompts pulling toward the bright lines. | Gap P2-4 / §15 |
| D4 | Block-on-add (block should prevent being added as a connection, not just replying). | Gap P2-2 / §10 |
| D5 | Move `MIN_FLOOR/MAX_CEIL/factor/window/GROWTH_*` into a config table. | Gap P2-7 |
| D6 | Optional profile photo upload (Supabase Storage; schema already has `photo_url`). | Gap P2-8 |

---

## Milestone E — Validate before spend (don't skip)
- **E1** Honest cohort-retention instrumentation from day one: D1/D7/D30, DAU/MAU, daily-loop-completion, time-to-first-graduation. (Market: headline MAU is unreliable; instrument your own.)
- **E2** Seed-school launch into one dense 18+ cluster (Greek life / team / club). Gate paid acquisition on **D30 holding ~25–30% / DAU-MAU ~40%+**; if it plateaus near the social median (~5–7%), the loop isn't sticky enough and UA would just rent a BeReal-style spike.

*(Monetization — premium gist depth/history, then compatibility/group features — is a separate workstream after retention is proven; see the market doc's ranked options. Avoid ads and never pay-to-unmask.)*

---

## Spec updates to capture along the way
- `PRODUCT.md` §6.3 + §11.2 → the per-prompt spice-level model (section 0).
- `GIST.md` §3/§7 → generator reads `posts.spice_level` + receives `owner_display_name`.
- `README.md` → tighten age-gate language; add the T&S/report/takedown surface.

## Open decisions to confirm before building
1. **Spice default + dial-up:** default comfort = `social`? And may an owner dial a post *above* their standing comfort per day, or only down/skip?
2. **Age verification depth:** real third-party age-assurance (cost/friction) vs. a hardened neutral gate only — how far to go for launch given the state patchwork.
3. **Private-reply abuse scanning:** acceptable approach to flag harmful private replies for review without breaking the author-only guarantee (this is sensitive — needs a deliberate design).
4. **Auth at launch:** phone-only, or keep email as a permanent alternative.

## Suggested order of execution
**A (safety/legal) → B (turn the loop on) → C (retention) → D/E (growth + validate).** A and B together get to a defensible, actually-running product; C is what makes it survive; D/E is scale. The spice-level feature (A3) is the natural first build since it's small, self-contained, and you just decided it.
