# Who Am I — Product Requirements Document (PRD)

> Read `README.md` first for orientation and the hard constraints. Read `GIST.md` for the AI generation details referenced throughout this doc.

---

## 1. Overview & vision

**Who Am I** is a mobile-first social app where a person's profile is authored not by themselves but by the people who know them. Every day, one prompt is published to the entire app. The people you've approved as "repliers" answer that prompt *about you*. Once enough have answered, an AI synthesizes their answers into a **gist** — a short, funny, blunt, affectionate portrait of who you are in your friends' eyes. The gist is permanent in spirit but living in practice: it keeps growing and deepening as more people answer, for as long as the app exists.

The emotional core is curiosity about the self: *what do the people who actually know me really think?* The social core is the daily shared ritual and the drama/comedy of seeing — and selectively hiding — what's said.

### The one-liner
A profile you don't write — the friends you've approved write it, one shared daily prompt at a time, and what you choose to hide is as magnetic as what you show.

## 2. Target user & positioning

- **Who:** 18+ social users (friend groups, roommates, coworkers, online friend circles) who enjoy roast culture, group-chat dynamics, and identity play. Initial wedge: tight, high-density friend groups where everyone will plausibly join (the graduation threshold needs density — see §6.5).
- **Tone/positioning:** funny, open, social. Affectionate roasting, not anonymous cruelty. The brand voice everywhere should read as "your group chat at its funniest," never as "anonymous confessions" or "rate people."
- **Explicitly NOT:** an anonymous-questions app, a hot-or-not/rating app, or a dating app. Those framings are both off-brand and legally radioactive in this genre.

## 3. Core concept & identity thesis

Your profile is a **living, crowd-authored portrait**, organized by prompt. For each prompt your friends have answered, there's a gist (the AI synthesis) on top and the raw replies beneath (behind "see more"). Over time the collection of gists becomes an evolving record of how you're seen — and how that changes.

Identity here is a *track record built by others*, which is why two design choices are load-bearing:
- **You can't write your own** — only your approved repliers can.
- **You can't delete what's said** — you can only privatize (hide) it, or revoke the person entirely.

## 4. The core loop (detailed)

1. **Prompt drops.** Once per day, a single prompt is published to all users simultaneously. It's the same prompt for everyone (e.g., "How are they socially?", "What's their biggest flaw?", "Describe them as a Sims character", "Roast them").
2. **Repliers answer.** For each person you can reply to, you may answer today's prompt about them. (You are not forced to answer for everyone — see §6.4 participation.)
3. **Blind accumulation.** As answers come in on *your* post, neither you nor anyone visiting your profile can read them. Everyone sees only a counter: "8 / 10 answers" or "needs 2 more replies."
4. **Graduation.** When the post hits its (adaptive) reply threshold, it **graduates**: the AI gist generates and the post unlocks for viewing. This is the dopamine moment ("your gist is ready").
5. **Reveal + curate.** You see the gist; you can "see more" to read the raw **public** replies (private ones show only as "🔒 [name] left a private reply" — you can't read those); you can privatize any public reply you'd rather hide (you cannot delete it).
6. **Living growth.** After graduation, the gist is never locked. As more replies arrive over time, it deepens and evolves (by accretion, not overwrite — see `GIST.md`).
7. **Spread.** You share your gist card; people visit your profile; reciprocity ("you answered Jack's — see what Jack said about you") and the need to get replies to graduate your own posts pull new people in.

## 5. Naming & vocabulary (use consistently in code + UI)

- **Profile owner / "you":** the person a profile is about.
- **Connection:** anyone you've added. Has a **role**: `viewer` or `replier`.
- **Viewer:** can see your (graduated) profile but cannot answer prompts about you. Your reach layer.
- **Replier:** can answer prompts about you. Your trusted layer. (Every replier is also implicitly a viewer.)
- **Prompt:** the daily question, global to all users.
- **Post:** the instance of a given daily prompt *on a specific profile* — i.e., "the 'roast them' post on Jack's profile," which collects replies and produces one gist.
- **Reply:** one person's answer to a post.
- **Gist:** the AI-synthesized portrait for a post. Has versions over time.
- **Graduation:** the moment a post crosses its reply threshold and its gist generates/unlocks.
- **Privatize / private reply:** a reply hidden from public view — set private by its **author** (at write time or later) or buried by the **owner**. Still counts. The **content** is readable by the author alone (not even the owner); the **author's name** is shown publicly ("🔒 Sarah left a private reply").

## 6. Feature specifications

### 6.1 Accounts, onboarding & the age gate

- **Signup:** email or phone. Standard auth (Supabase Auth).
- **Age gate (hard, 18+):** present a neutral age gate at signup (date of birth entry, not a "are you 18?" yes/no). Block under-18 accounts. Store the attestation. Do not allow the rest of onboarding to proceed without passing it. (See README hard constraints — this is non-negotiable.)
- **Identity verification (lightweight):** to reduce impersonation and fake accounts, verify a contact channel:
  - **Phone (SMS OTP)** is the recommended primary verification — simple, effective, and not dependent on third-party platform APIs.
  - **Instagram handle** may be *collected and displayed* as a soft signal ("links their IG"), but note: Instagram's Basic Display API was shut down (Dec 2024) and personal-account access for third parties is gone. Do **not** architect anything that depends on reading a user's Instagram graph, followers, or posts. Treat IG as, at most, a displayed handle the user types in — not a verification or data source.
- **Profile creation:** display name, optional photo, optional bio. The profile starts essentially empty — its content comes from others.
- **Onboarding goal:** get the user to (a) pass the age gate, (b) verify, (c) add their first connections and invite friends. The app is dead without repliers, so the invite/add step is the most important moment of onboarding — make it frictionless and motivating ("your profile fills in once your friends start answering").

### 6.2 The connection & permission model

- **Adding people:** users add connections (by handle/username, contacts, or invite link).
- **Roles set by the owner:** for each connection, the owner decides whether that person is a **viewer** or a **replier** on the owner's profile. This is the reach-vs-trust split:
  - Viewers: wide net, can see your graduated profile, can share it. Drives reach/virality.
  - Repliers: the trusted few who can actually write about you. Drives content quality and safety.
- **Default role:** new connections default to **viewer**; promoting to replier is a deliberate act. (Rationale: you should consciously choose who gets to write about you.)
- **Asymmetry is allowed:** A can be a replier on B's profile while B is only a viewer on A's. Roles are per-profile and owner-controlled.
- **Revoke (the clean exit):** the owner can revoke a connection at any time. **Revoking removes that person's access AND deletes all replies they have ever left on the owner's profile**, and triggers regeneration of affected gists (so the revoked person's influence disappears from the portrait). This is the pressure-release valve that makes the no-individual-delete rule tolerable: you can't cherry-pick away one embarrassing reply, but if a relationship goes bad you can remove the whole person cleanly.
- **No deletion of individual replies by anyone.** A replier cannot delete their own reply after submitting (keeps it honest). The owner cannot delete an individual reply (only privatize it). Removal happens only at the person level, via revoke.

### 6.3 The daily prompt system

- **One global prompt per day**, published on a schedule (e.g., a fixed local-ish time; decide one canonical publish time to start). Same prompt for all users that day.
- **Prompt deck (the editorial core):** prompts are **hand-authored and curated by the team**, not user-submitted (at least at launch — crowdsourced prompts lose tone control and invite abuse). The deck is the single most important tone/virality/risk lever in the product. Treat it like level design.
  - **Range:** wholesome ("favorite memory of them"), playful/character ("describe them as a video-game character", "what would they bring to the apocalypse"), social ("how are they socially?"), and spicy/roast ("biggest flaw?", "roast them"). Mix the register.
  - **Cadence:** establish a rhythm — softer mid-week, spicier on weekends — to manage tone and build anticipation. Store a `tone` tag per prompt (e.g., `wholesome | playful | social | spicy`) so cadence can be scheduled and so the gist generator can calibrate (see `GIST.md`).
  - **Prompts must obey the bright lines too:** never publish a prompt that targets protected classes, bodies/appearance, or solicits factual accusations of wrongdoing. The prompt is upstream of everything; a bad prompt poisons the whole day.
- **Prompt-level opt-in for spicy prompts:** for prompts tagged spicy, the owner opts in at the *prompt* level on their profile. If you open today's spicy prompt, it's all-or-nothing — you can't later cherry-pick which answers are flattering (you can still privatize, but you've accepted the prompt). If you skip it, no one can answer it about you that day, and it simply doesn't appear on your profile. Wholesome/playful prompts can be open by default; spicy ones require the opt-in. (Decision to confirm: whether opt-in is per-prompt each day, or a one-time global "I'm down for spicy prompts" setting. Recommended: a global setting with a per-day skip option, to reduce friction.)

### 6.4 Replies & blind accumulation

- **Who can reply:** only the owner's repliers, and only to prompts the owner has open.
- **Answering:** a replier sees the day's prompt and the list of people they can answer it about; they write a short free-text reply per person, and choose whether it's **public or private** (§6.7). (Consider a character cap to keep replies punchy and gist-friendly, e.g., 280–500 chars.)
- **One reply per replier per post.** No editing or deleting the **body** after submit (honesty) — but the author may flip their reply between **public and private** at any time (§6.7); visibility is theirs to change even though the words are locked. (Decision to confirm: allow a short edit window, e.g., 60 seconds, to fix typos? Recommended: no edit, to keep it clean; or a very short window only.)
- **Blind accumulation (symmetric):** **no one** — not the owner, not visitors — can read replies on a post until it graduates. Pre-graduation, the only thing anyone sees is the counter (e.g., "needs 2 more replies"). This symmetry is essential: if visitors could read pre-graduation replies, the owner's blindness would be meaningless (a friend would just screenshot and send them). Enforce this at the data layer (RLS), not just the UI.
- **Participation (the empty-profile problem):** users are NOT required to answer for all their connections each day (that doesn't scale and won't happen). They answer for whomever they want. But this creates a risk that popular users get flooded while everyone else's posts never graduate. Mitigations (build at least the first two):
  1. **Directed nudges:** "3 friends are waiting on your answer to today's prompt" — surface specific people whose posts are close to graduating.
  2. **"Be the one to unlock it":** when a visitor views a profile with a post at e.g. 8/10, prompt them that their reply could graduate it.
  3. Streaks / light gamification for answering daily.

### 6.5 Graduation (the threshold + the moment)

- **What it is:** a post graduates when it accumulates enough replies; on graduation the gist generates and the post becomes viewable.
- **Adaptive threshold (do NOT hardcode a universal 10):** a fixed high number locks out the median user, whose post would sit forever below the bar and who would then churn. Scale the threshold to the owner's **replier** count. Recommended formula:
  - `threshold = clamp(ceil(0.5 * replier_count), MIN_FLOOR, MAX_CEIL)`
  - with `MIN_FLOOR = 3` and `MAX_CEIL = 10` (tune later).
  - i.e., a user with 4 repliers graduates at 3; a user with 30 graduates at 10. Everyone has a reachable bar.
  - **Public vs private counting (caveat):** private replies count as participation toward the threshold, but they do **not** feed the gist (only public replies do — §6.7, `GIST.md` §3). So a post dominated by private replies can graduate with thin gist material (expect `tone_flag: thin`). Whether the threshold should count *public* replies only is an open decision (§11).
- **Time fallback:** a post should not hang in purgatory forever. If a post has not graduated within a window (recommended 48 hours) **but has at least MIN_FLOOR replies**, graduate it on whatever it has. If it never reaches MIN_FLOOR, it expires without a gist (and the owner is nudged to add/activate more repliers). Tune the window.
- **The moment:** graduation is the product's primary dopamine spike. Fire a notification ("Your '[prompt]' is ready 👀"), animate the reveal. After this moment, the gist is live and will keep growing (never re-locks).

### 6.6 The gist

- **What it is:** the AI synthesis of a post's replies into a short, funny, blunt, affectionate portrait. This is the payoff and the tone enforcer. Full generation spec — voice, bright lines, consensus rule, accretion, regeneration cadence, system prompt — is in **`GIST.md`**. Product-level behavior:
- **Generated at graduation**, then **living** — it grows by accretion as new replies arrive (deepens/sharpens; does not overwrite or whiplash). Batched regeneration for cost (see `GIST.md`).
- **See more:** beneath the gist, the owner (and viewers, post-graduation) can expand to read the raw individual replies. Public replies are shown **attributed** (author's name; see §11). Private replies appear as a named, locked item — "🔒 Sarah left a private reply" — with the content readable by **no one but its author** (§6.7). The gist itself synthesizes **public replies only**.
- **Gist history / evolution:** store every gist version. Surface the evolution as a feature — "6 months ago your friends saw you as the quiet one; now you're the chaotic glue of the group." This is a re-engagement and identity hook. Let users scrub a gist's timeline.
- **Attribution of raw replies — RESOLVED → attributed (see §11):** public raw replies show the author's name, and private replies are shown as "🔒 [author] left a private reply." Since the author of even a *private* reply is visible, public replies are attributed too. The gist itself is aggregate and unaffected by this. (Semi-anonymous replies are off the table given the named-private model.)

### 6.7 Public/private, privatize & reveal (the intrigue layer)

- **The replier chooses public or private when they write.** Every reply is marked public or private by its **author** at write time (default public; tune later). The author can flip their own reply between public and private at any time afterward — the body itself is never editable (§6.4), but its visibility is the author's to control.
- **Private content is author-only.** The *content* of a private reply is readable by **only its author** — not the public, not viewers, and **not even the profile owner**. What everyone else sees post-graduation is the author's name and that they left a private reply: **"🔒 Sarah left a private reply."** (See README hard constraint #3.)
- **The owner can privatize, but not reveal.** After graduation the owner may **privatize** any public reply on their profile — burying it from public view. They cannot delete it, and (because private content is author-only) once it's private the owner can no longer read it either. The owner **cannot** make a private reply public again: reveal is the **author's** call alone (author's choice is final). The owner's durable remedy for a reply they truly want gone is **revoke** (§6.2), which removes the person and all their replies.
- **Privatize is the valve.** It's what makes "no deletion" tolerable — the owner can push the one that stings out of public view while keeping the post honest (it still counts; the author still has it). For a reply the author insists on re-publishing, the owner's real backstop is revoke, not a privatize tug-of-war.
- **Named private replies are the intrigue engine.** On the public profile, a post shows its public replies + gist **plus each private reply as a named, locked item** — "🔒 Sarah left a private reply." Naming the author (not just a count) is sharper curiosity fuel: you know exactly who to ask. Even the owner can't resolve it — only the author knows what they wrote — which drives the "what did you say??" conversations that spread the app off-platform (recruiting non-users).
- **Reveal (author-driven):** an author can later flip their own private reply public — a second content/shareable spike ("Sarah finally showed what she said").
- **Private is private — permanently and absolutely.** There is no scheduled or bulk reveal of private content, ever, and no one but the author can read it. (Auto-revealing, or owner-readable, private content would destroy both the safety valve and the trust the intrigue depends on, and is a serious legal/harm problem.)
- **Private replies do not feed the gist.** Because only the author may read a private reply, it is excluded from gist synthesis entirely — the gist is built from public replies only (see `GIST.md` §3). Private replies still count as participation (and toward the graduation counter; see §6.5 caveat).
- **Enforce at the data layer:** a reply's body must be unreadable by anyone but its author unless the post is graduated **and** the reply is public — via RLS, not merely hidden in the UI.

### 6.8 The profile (the archive)

- A profile is a **browsable archive organized by prompt.** For each prompt the owner has participated in:
  - the current gist (if graduated), 
  - the raw public replies behind "see more" (attributed),
  - each private reply as a named, locked item ("🔒 Sarah left a private reply"; content readable only by its author).
- **Pre-graduation posts** appear with their counter only ("needs 2 more replies").
- Surface the **latest/freshest gist** prominently (e.g., a hero "this is who you are right now" card), with the archive below.
- The profile is the primary shareable surface.

### 6.9 Notifications

Notifications are a core retention driver. At minimum:
- **Daily prompt published** ("Today's prompt is live — go answer it about your friends").
- **Your post graduated / gist ready** (the big one).
- **Your gist evolved** (batched, meaningful — "3 new takes reshaped your gist," not per-reply spam).
- **Directed participation nudges** ("2 friends are waiting on your answer," "you could be the one to unlock Jordan's gist").
- **Someone added you / made you a replier.**

Rate-limit and batch aggressively. Never notify per individual reply.

### 6.10 Sharing & share-cards

- **Gist share-card:** a clean, screenshot-ready / story-ready card rendering the gist (and the prompt it answers). This is the primary growth artifact. Design it to look great in an Instagram/TikTok story.
- **Reveal cards** and **evolution cards** ("then vs now") as secondary shareables.
- Sharing should deep-link back into the app and into the sharer's profile, to capture reciprocity.

## 7. Growth loops (consolidated)

1. **Owner-as-distributor:** to unlock your *own* gist, your posts must graduate, which requires getting your repliers to answer — so you're motivated to recruit and nudge. Your reward is gated behind driving participation.
2. **Reciprocity:** "you answered Jack's — see what Jack said about you?" The universal daily prompt makes this symmetric and natural.
3. **Word-of-mouth via hidden replies:** a named, locked "🔒 Sarah left a private reply" creates a question that *only the author* can answer — not even the profile owner can see it — so resolving it means talking to that specific person, usually off-app. Naming the author makes the curiosity sharper (you know exactly who to ask). Every such conversation exposes the app to a non-user.
4. **Reveals & evolution:** new shareable spikes over time, not just at signup.
5. **Daily share-card:** the gist is built to be posted.

## 8. Data model (high-level)

Entities and key relationships (Postgres/Supabase; enforce visibility via RLS):

- **users** — id, auth fields, display_name, photo, bio, dob/age_verified flag, verified_phone, ig_handle (display only), created_at.
- **connections** — id, owner_id (→users), connected_user_id (→users), role (`viewer` | `replier`), created_at. (Owner-controlled role. Revoking deletes the row and cascades reply removal + gist regeneration on owner's affected posts.)
- **prompts** — id, text, tone (`wholesome|playful|social|spicy`), publish_date (the day it's the global prompt), created_at. One active prompt per day.
- **posts** — id, profile_owner_id (→users), prompt_id (→prompts), status (`accumulating|graduated|expired`), threshold (computed at creation from replier count), graduated_at, created_at. (One post per (owner, prompt). Created when the owner has the prompt open and is eligible.)
- **replies** — id, post_id (→posts), author_id (→users), body, is_private (bool), privatized_by (`author` | `owner` | null), created_at. (Body immutable after insert — no update/delete by author. The **author** sets `is_private` at write time and may flip it **either** direction anytime; the **owner** may privatize a public reply (public→private) but **not** reveal it — reveal (private→public) is the author's alone (§6.7). `privatized_by` records whether the current private state came from the author's own choice or an owner bury (UX/audit). Hard-removed only on revoke of author.)
- **gists** — id, post_id (→posts), current_version_id (→gist_versions). One per post.
- **gist_versions** — id, gist_id (→gists), body, model, reply_count_at_generation, created_at. (Append-only history; powers evolution feature.)
- **(later) reports/flags**, **notifications**, **invites** as needed.

**Critical RLS rules:**
- A reply's **body** is always readable by its **author**. For everyone else (owner + viewers + repliers), the body is readable **only if** the post status is `graduated` AND the reply is `public`. **Private reply bodies are readable by no one but the author — not even the profile owner.** Pre-graduation, no one but the author can read any reply body.
- Post-graduation, each reply's **author identity + public/private flag** are readable by owner + viewers (to render attributed public replies and "🔒 [author] left a private reply" labels). Pre-graduation, only the aggregate counter is exposed — no rows, no authors.
- The gist generator is fed **public replies only**; private bodies are author-only and never reach synthesis.
- Reply counts (the "8/10" counter) must be exposed as aggregates without exposing the underlying rows.
- A user can only create replies on posts belonging to profiles where they have role `replier`.

## 9. Key screens / surfaces

1. **Onboarding** — age gate → verify → profile basics → add/invite friends.
2. **Today** — the day's prompt; the list of people you can answer about; quick-answer flow; nudges ("waiting on you").
3. **My Profile** — hero current gist; archive of posts by prompt; pre-graduation counters; named private replies ("🔒 …"); entry to curate (privatize) graduated posts.
4. **Someone's Profile** — their gists/archive (graduated only); their pre-graduation counters with "be the one to unlock it"; the "see what they said about you" reciprocity hook.
5. **Curate view** (owner, per graduated post) — raw public replies with **privatize** controls (owner can bury a public reply; reveal is author-only — §6.7).
6. **Connections** — manage people; set viewer/replier; revoke.
7. **Gist detail / evolution** — full gist, see-more raw replies, version timeline scrubber.
8. **Share-card generator.**

## 10. Edge cases & rules (consolidated)

- **Post never graduates:** expires after the time-fallback window if under MIN_FLOOR; owner nudged to add repliers. No gist.
- **Revoke after graduation:** remove the person's replies, regenerate affected gists; if removal drops a post below MIN_FLOOR, keep the existing gist version but flag it stale / stop it from claiming more than it now supports (don't delete history).
- **All-negative / pile-on replies:** the gist generator must not amplify a cruel minority into a "everyone thinks X" verdict; if replies are uniformly hostile or thin, it renders lighter or declines to go hard. See `GIST.md`.
- **Over-the-line content inside a reply** (protected-class, body-shaming, accusations of crime, self-harm/trauma): the gist generator excludes it from synthesis and never reproduces it. Consider also flagging such replies for review. The raw "see more" view is where this is riskiest — see §11 and `GIST.md` safety notes.
- **Contradictory replies:** the gist can play the contradiction for comedy ("half your friends say you're the calm one, half are still recovering from the road trip").
- **Owner has zero/one replier:** can't graduate anything; onboarding/nudges must push adding repliers as the core unlock.
- **Gaming the threshold** (begging for throwaway replies): acceptable early; if it degrades quality, add minimum-effort checks on replies later.
- **Blocking/safety:** a user must be able to block another user entirely (prevents adding/replying in either direction). Build alongside revoke.

## 11. Open decisions (resolve before/at build)

These are the genuinely unresolved forks. Everything else is locked.

1. **Raw-reply attribution — RESOLVED → attributed.** Public raw replies show their author; private replies render as "🔒 [author] left a private reply." Because the author of even a private reply is visible, public replies are attributed by definition — semi-anonymous is off the table. Rationale: accountability (people sign their roasts), affectionate-culture fit, and it removes the "someone I approved said something cruel and I don't know who" anxiety. The gist remains aggregate/unattributed regardless.
2. **Spicy opt-in granularity:** per-day per-prompt opt-in vs a one-time global "I'm down for spicy" setting with per-day skip. Recommended: global setting + per-day skip.
3. **Reply edit window:** none vs a very short (~60s) typo-fix window. Recommended: none, or ≤60s.
4. **Canonical daily publish time** and whether it's globally fixed or timezone-localized. Recommended: one fixed global time to start (simpler; one shared moment).
5. **Threshold constants** (`MIN_FLOOR`, `MAX_CEIL`, the 0.5 factor) and the **time-fallback window** — start with the recommended values, tune with real data.
6. **Does the graduation threshold count private replies?** Private replies are participation but don't feed the gist (§6.5, §6.7). Counting them toward graduation is simplest but can graduate a post with thin gist material; counting **public replies only** guarantees the gist has material but makes posts harder to graduate. Recommended: count all replies toward graduation, but surface `tone_flag: thin` when public material is sparse; revisit with data.

## 12. Constraints & guardrails (see README for the full list)

- 18+ hard age gate.
- The gist is first-party content; the `GIST.md` bright lines are mandatory hard constraints.
- Private is genuinely private — a private reply's content is readable by its **author only** (not even the profile owner); only the author can reveal it; no bulk/scheduled reveal mechanism exists.
- No individual-reply deletion; removal only via person-level revoke.
- Modest, plain moderation claims in all copy.
- Block + report capabilities.
- Get legal counsel before launch (defamation, privacy, platform liability, age verification).

## 13. Phased build plan

Each phase ships as a working slice before the next begins.

**Phase 1 — Skeleton + identity**
Auth; 18+ age gate; phone (SMS OTP) verification; profile creation; the connection model with viewer/replier roles; revoke; block. No prompts, no replies yet. *Done when:* a user can sign up (18+ gated), verify, build a profile, add people, set their roles, and revoke/block.

**Phase 2 — The daily loop, no AI**
Daily prompt publishing (cron); the prompt deck (seed ~30–50 hand-written prompts with tone tags); repliers answering today's prompt about people; blind accumulation enforced via RLS; the adaptive graduation threshold + time fallback; a **placeholder gist** (e.g., on graduation, simply list the raw public replies — no AI yet). *Done when:* the full loop works end to end without spending on AI — prompts drop, friends answer blind, posts graduate at the right threshold, content unlocks.

**Phase 3 — The gist (AI)**
Implement `GIST.md`: generation at graduation with the voice + bright lines + consensus rule; the living/accretion model; batched regeneration (cron/threshold-triggered); `gist_versions` history. *Done when:* graduated posts produce real, in-voice, bounded gists that deepen over time, and the team has validated tone/safety on real-ish data.

**Phase 4 — Curation + intrigue**
Replier public/private choice at write time; author-only private content; owner **privatize** (public→private) but author-only **reveal**; named locked private replies ("🔒 Sarah left a private reply") on public profiles; the public/private archive view; **attributed** see-more raw replies (§6.7, §11). *Done when:* repliers can choose public/private, owners can privatize, **private bodies are readable only by their author (RLS-verified — not even the owner)**, and named private replies render publicly.

**Phase 5 — Growth surfaces**
Share-card generator; reciprocity hooks; full notification system (batched); gist evolution / "then vs now"; directed participation nudges. *Done when:* the loops in §7 are live and instrumented.

Throughout: instrument funnel + retention; keep moderation/abuse tooling (block, report, review queue) ahead of growth, not behind it.
