# Who Am I — Project README

> **Working name:** "Who Am I" (placeholder — rename later)
> **Status:** Spec complete, pre-build
> **Audience for this doc:** the engineer/agent building this (Claude Code). Read this file first, then `docs/PRODUCT.md`, then `docs/GIST.md`; see `docs/SCAFFOLD.md` and `docs/STRUCTURE.md` for build setup and file organization.

---

## What this is, in one line

A social app where **your profile is written by the people who know you.** A single prompt drops every day, the friends you've approved answer it *about you*, and an AI synthesizes their answers into a living, funny-but-blunt portrait of who you are according to your people.

Think: a group chat roast, a yearbook signing, and a personality reading — except the personality is written by your actual friends and it grows for as long as people keep answering.

## Why it works (the thesis)

Three proven mechanics stacked into one product:

1. **Daily ritual** — one shared prompt for everyone at once (the BeReal / Wordle move) kills the blank-box problem and gives a daily reason to return.
2. **Identity through others' eyes** — "who am I according to the people who know me" is a deep, universal pull (the appeal of personality tests, but personalized by real relationships).
3. **Synthesis as payoff** — an AI distills a pile of raw replies into a polished, shareable read. This is the Spotify-Wrapped move: turn accumulated data into an identity object people *have* to share.

The combination — daily prompts + an approved-friends social graph + AI synthesis + an intrigue/curation layer — is the part that's hard to copy. Any one piece alone is weak.

## The core loop

```
Daily prompt drops (same for everyone)
        │
        ▼
Your approved repliers answer it ABOUT YOU   ←─ you can't see answers yet (blind)
        │
        ▼
Post "graduates" once enough people reply     ←─ this is the unlock moment
        │
        ▼
AI generates your GIST (funny, blunt portrait) + you can now "see more" raw replies
        │
        ├──► You curate: privatize replies you'd rather not show (you can't delete them — and once private, only their author can read or reveal them); repliers can also post replies private from the start. See PRODUCT.md
        │
        ├──► Gist keeps GROWING as more people reply (never locked — accretes over time)
        │
        └──► Share your gist card → friends visit → reciprocity pulls them in to answer yours
```

## Document map

All specs live in `docs/`; this README stays at root as the entry point. Detail in `docs/STRUCTURE.md`.

| File | What's in it |
|------|--------------|
| `README.md` | This file. Orientation, stack, build order, hard constraints. Start here. |
| `docs/PRODUCT.md` | The full PRD. Every feature, every flow, the permission model, the data model, edge cases, and the phased build plan. |
| `docs/GIST.md` | The AI generation spec. Voice, the content "bright lines," the consensus rule, the living/accretion model, regeneration cadence, and a ready-to-use system prompt. |
| `docs/SCAFFOLD.md` | Build setup. The tech stack (native iOS / SwiftUI / MVVM + Supabase), the architecture, the Supabase + auth integration, and Xcode project setup. |
| `docs/STRUCTURE.md` | File & folder organization — where every file lives and the rules for adding new ones. |

## Stack

A **native iOS app** (SwiftUI) on a **Supabase** backend. Full setup — MVVM layers, the Supabase/auth integration, Xcode project — is in `docs/SCAFFOLD.md`.

- **Client:** SwiftUI (iOS 17+), **MVVM** + a thin service layer, Swift Concurrency. Phone-first; native gives the best version of the daily-ritual + share-to-stories loop. *(This supersedes an earlier Next.js/web default — see `docs/SCAFFOLD.md` §0; web/Android can follow later on the same backend.)*
- **Backend / DB / auth / storage:** Supabase (Postgres + Row Level Security + Auth + Realtime + Storage). RLS is doing real work here — the privacy guarantees (blind accumulation, private = author-only) are enforced at the database policy level, not just in the client.
- **Server logic / scheduled jobs:** Supabase Edge Functions (Deno/TypeScript) + `pg_cron` — publish the day's prompt, generate gists, run batched regeneration and the safety check.
- **Gist generation:** the Anthropic API (Claude), called **only** from Edge Functions (the key never ships in the app). Use a cheaper/faster model (Sonnet or Haiku tier) for cost — this runs a lot. See `docs/GIST.md`.
- **Auth / OTP:** Supabase Auth (phone SMS OTP primary, email supported) via the supabase-swift SDK.

## Build philosophy

**Phased. Each phase must be fully functional before the next begins.** Don't scaffold the whole thing half-built. Get a working vertical slice, then layer.

High-level phases (full detail in `PRODUCT.md`):

1. **Phase 1 — Skeleton + identity.** Auth, the 18+ age gate, profile creation, the connection/permission model (add people; view-only vs reply). No prompts yet.
2. **Phase 2 — The daily loop (no AI).** Daily prompt publishing, repliers answering, blind accumulation, the graduation threshold, and a *placeholder* gist (e.g., just lists the raw replies once graduated). This proves the core mechanic works without spending a cent on AI.
3. **Phase 3 — The gist.** Wire in real AI generation per `GIST.md`: voice, bright lines, consensus, the living/accretion model, batched regeneration, version history.
4. **Phase 4 — Curation + intrigue.** Privatize/reveal, locked private counts, the public/private archive view.
5. **Phase 5 — Growth surfaces.** Share-cards, reciprocity nudges, notifications, gist-evolution ("you used to be X, now you're Y").

## ⚠️ Hard constraints — read before writing any code

These are not optional and not "nice to haves." They are the difference between a viable product and a lawsuit. Do not design around them.

1. **18+ only, with a real age gate.** This app is in the same genre (peer commentary about named people, often linked to social handles) that drew the first-ever U.S. regulatory order banning a platform from serving minors. An audience that skews young is an existential risk here, not a growth opportunity. Gate hard at signup. Do not market to or knowingly admit under-18 users.

2. **The AI gist is FIRST-PARTY content.** When the app's AI *writes* a characterization of a real, named person, the app authored that — it's not user-generated content the platform merely hosts. That changes the liability posture. The content "bright lines" in `GIST.md` (no protected-class targeting, no body/appearance attacks, no factual accusations of wrongdoing, no mental-health/trauma material) are the legal shield. Implement them as hard constraints in generation, not suggestions.

3. **"Private" must be genuinely private.** A private reply's content is readable by its **author only** — not the public, not viewers, and not even the profile owner. Others see only that a named person left a private reply ("🔒 Sarah left a private reply"). Only the author can ever make it public; there is no mechanism, scheduled or otherwise, that bulk-reveals private content. The product's safety (it's the curation valve) and its intrigue engine both depend on private actually meaning private.

4. **No deletion of individual replies; clean exit via revoke.** Users cannot scrub a single embarrassing reply (that's what keeps it honest rather than a sanitized highlight reel). But revoking a person removes that person's access *and* all of their content. Permanence within a relationship, clean break when it ends. See `PRODUCT.md`.

5. **Be modest about moderation claims.** Whatever filtering/safety the app does, describe it plainly in copy and marketing. Over-promising moderation ("our AI removes all harmful content") is itself a liability — it's what converted a comparable app's normal operations into a multi-million-dollar settlement.

6. **This is not legal advice.** This genre genuinely warrants a real lawyer before launch (defamation, privacy torts, platform liability, age-verification requirements). Build the guardrails in from day one; get counsel before going live.

## The tone, in one note

The entire culture target is **funny, open, social** — affectionate roast, not cruelty. That tone is not a setting you flip; it's engineered by two levers: the **prompt deck** (what you ask shapes what you get) and the **AI gist's voice** (it renders even blunt replies in a warm-roast register). Comparable apps that wanted to be "light and fun" but didn't actively engineer for it all drifted dark. Protect the tone deliberately. Details in `GIST.md`.
