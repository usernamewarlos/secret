# Who Am I — GIST.md (AI Generation Spec)

> Read `README.md` first for orientation and the hard constraints, and `PRODUCT.md` for product behavior. This file is the single source of truth for **how the gist is generated** — voice, the content bright lines, the consensus rule, the living/accretion model, regeneration cadence, output schema, and a ready-to-use system prompt. Everything here is mandatory unless explicitly marked as a tunable knob.

---

## 1. What the gist is

The **gist** is the AI synthesis of a graduated post's replies into a short, funny, blunt, affectionate portrait of the profile owner. It is two things at once, and both matter:

1. **The payoff.** It's the reward for graduating a post — the thing the owner has been waiting (blind) to see. It turns a pile of raw replies into a polished, screenshot-worthy read of "who you are according to your people."
2. **The tone enforcer.** It is the layer that *guarantees the funny-roast register*. Individual replies will be blunt, lazy, harsh, or all over the place. The gist takes that raw signal and renders it in one consistent, warm-but-cutting voice. This is what keeps the product on the "affectionate roast" side of the line instead of drifting into a wall of cruelty. **The gist is the most important tone-control surface in the app after the prompt deck.**

Because the gist is written *by the app's AI* about a real, named person, it is **first-party content the platform authored** — not user content the platform merely hosts. That is the entire reason the bright lines in §9 are hard constraints and not style preferences. (See README hard constraint #2.)

---

## 2. The golden rule (the one sentence that governs everything)

> **Roast the behavior, never the person underneath.**

Quirks, habits, chaos energy, the running jokes of a friend group — fair game, go hard. The person's worth, identity, body, mental health, or alleged wrongdoing — never. A good roast lands on "you reply to texts in 3–5 business days." A bad one lands on who someone *is* or what they look like. The first is funny; the second is bullying and/or defamation. If a generated line couldn't be read aloud at a roast dinner *to the person's face, with love*, it doesn't ship.

Everything below is an elaboration of that rule.

---

## 3. Inputs to the generator

For a given post, the generator receives:

- `prompt_text` — the day's prompt (e.g., "How are they socially?").
- `prompt_tone` — the prompt's tone tag: `wholesome | playful | social | spicy`. Calibrates how hard the gist leans in (see §7).
- `owner_display_name` — the subject's name/first name (the gist refers to them in second person "you" when shown to the owner; see §11 on point-of-view).
- `replies[]` — the current set of **public** replies for this post. **Private replies are excluded** — a private reply's content is readable only by its author (`PRODUCT.md` §6.7), so it never reaches the generator and never shapes the gist. Each reply is just its `body` text. **Author identities are NOT passed to the generator** — the gist is aggregate and should never name or single out who said what.
- `prior_gist` — for regeneration only: the most recent gist version (`verdict` + `body`). Drives the accretion model (§5). Null on first generation.
- `reply_count` — total replies feeding this generation (stored on the version for the evolution feature).

The generator does **not** receive: private replies, author names, user IDs, profile photos, anything about the viewer, or any cross-post/history beyond `prior_gist`. Keep the input surface minimal.

---

## 4. When it generates

- **First generation: at graduation.** The moment a post crosses its adaptive threshold (`PRODUCT.md` §6.5), generate the first gist. This is the dopamine moment; it should be ready when the unlock notification fires.
- **It is never locked.** After graduation the gist is *living* — it keeps growing as more replies arrive. See §5.
- **Regeneration is batched, never per-reply.** See §14 for the exact triggers. Regenerating on every single reply is a cost and stability disaster; do not do it.
- **On revoke:** when a person is revoked, their replies are hard-removed; regenerate any of the owner's affected posts so the revoked person's influence disappears from the portrait (`PRODUCT.md` §6.2).

---

## 5. The living / accretion model (deepen, don't overwrite)

The single most important behavioral rule for regeneration:

> **The gist grows by accretion. It deepens; it does not restart.**

When new replies arrive and the gist regenerates, it must **evolve the existing portrait**, not rewrite it from scratch. Concretely, the model is given the `prior_gist` and instructed to:

- **Preserve** characterizations that are still well-supported. If "certified yapper" was true last week and the new replies don't contradict it, it stays (possibly sharpened). The reader should recognize continuity — their gist should feel like the same portrait gaining detail, not a different verdict every time.
- **Add** new facets the new replies reveal.
- **Sharpen** existing observations with better specifics.
- **Revise** a prior take *only* when the weight of evidence has genuinely shifted (e.g., early replies said "shy," but fifteen later replies all describe them running the function — then the portrait can evolve from "the quiet one" toward "the quiet one who somehow ends up in charge").

Why this matters: overwrite-on-every-reply produces **whiplash** (your verdict flips, "yapper" vanishes overnight) and makes the gist feel arbitrary and untrustworthy. Accretion makes it feel considered and alive. This is the difference between a magnetic living portrait and an unstable random-line generator.

**Versioning powers a feature.** Every generation (first and each regen) is written as an append-only `gist_versions` row (`body`, `verdict`, `model`, `reply_count_at_generation`, `created_at`). This history is not just an audit log — it's the **evolution / "then vs now" feature** (`PRODUCT.md` §6.6): "6 months ago your friends saw you as the quiet one; now you're the chaotic glue of the group." Never delete or mutate old versions.

---

## 6. Voice & register

The target voice is **a friend roasting you at a party** — not a therapist, not a hater, not a corporate personality report.

Characteristics:
- **Funny first.** Wit and specificity over completeness. A great gist is quotable.
- **Blunt, with teeth.** It does not sand off the edges into warm mush. Toothless is boring and dead on arrival; the bluntness *is* the appeal. (See README tone note.)
- **Specific.** It uses the actual material — the recurring jokes, the concrete behaviors — not generic horoscope filler. "Generic and could be about anyone" is a failure mode.
- **Affectionate underneath.** Even the hardest line reads as ribbing, not contempt. The warmth is what earns the bluntness.
- **Confident and economical.** It states the read like it knows the person. No hedging ("some of your friends might think..."), no padding.
- **Second person, to the subject.** "You're the human aux cord," not "Jack is..." (the primary surface is the owner reading their own gist and a share-card; see §11).

### Tone-laundering (the core transformation)

The generator's defining skill is taking blunt/lazy/harsh raw replies and rendering the **signal** in the warm-roast voice — **keep the truth, lose the venom**:

| Raw replies (blunt input) | Gist line (laundered output) |
|---|---|
| "he never shuts the fuck up" / "talks too much" / "exhausting tbh" | "has never once permitted a silence to exist" |
| "flaky" / "always cancels" / "unreliable" | "replies to plans in 3–5 business days" |
| "bad with money" / "always broke" | "treats their bank balance as more of a vibe than a number" |
| "kind of a control freak about plans" | "a benevolent dictator of the group chat itinerary" |
| "messy, never on time" | "operates exclusively on a personal timezone, roughly 20 minutes behind everyone else's" |

The output keeps the behavioral truth (talkative, flaky, bad with money) and converts contempt into comedy. Note that **none** of these touch the person's worth, body, or character — they hit *behavior*.

---

## 7. Tone calibration by prompt tag

The `prompt_tone` controls how hard the gist leans in. Same voice, different dial:

- **`wholesome`** (e.g., "favorite memory of them") → warm, fond, light teasing at most. The gist is mostly heartfelt with a wink. Do not force roast material here.
- **`playful`** (e.g., "describe them as a Sims character," "what would they bring to the apocalypse") → imaginative, character-driven, fun. Roast energy welcome but channeled through the bit.
- **`social`** (e.g., "how are they socially?") → observational and candid; affectionate roast is the default register.
- **`spicy`** (e.g., "biggest flaw?", "roast them") → maximum teeth, full roast — *within* the bright lines. The owner explicitly opted into spicy prompts (`PRODUCT.md` §6.3), so go for it, but §9 still binds absolutely.

The bright lines (§9) are identical across all tones. `spicy` raises the heat, never the targets.

---

## 8. The consensus rule

> **The gist reflects what multiple people said — not whatever single reply was nastiest (or kindest).**

- **Weight by recurrence.** A trait three people independently mention is the spine of the gist. A one-off is color at most, or omitted.
- **Never let an outlier become a verdict.** One cruel reply must **not** be rendered as "everyone thinks you're X." This is both a fairness rule and a harm rule — it's the reason graduation requires a real sample (`PRODUCT.md` §6.5) before any gist generates.
- **Contradictions are comedy, not problems.** When friends disagree, play it: "half your friends swear you're the calm, responsible one; the other half are still recovering from the road trip." Don't average contradictions into mush.
- **Thin or uniformly hostile sets → pull back.** If the replies are sparse, or are genuinely hostile rather than playfully roasting (real contempt, pile-on energy, not affectionate ribbing), the gist must **render lighter** — go gentler, stay high-level, do not amplify. Signal this to the product via `tone_flag` (§11) so the product can choose to render softly or hold. The generator never escalates a hostile set into a savage verdict.

---

## 9. The bright lines (HARD content constraints)

These are non-negotiable, identical across all prompt tones, and apply to **both** the synthesized gist output **and** any reasoning the model does over replies. They are the product's legal shield (the gist is first-party content) and the line between affectionate roast and bullying. **Implement them as hard generation constraints and verify them with a post-generation check (§15).**

The gist must **NEVER**:

1. **Target protected characteristics.** No roasting or referencing race, ethnicity, nationality, religion, sex, gender identity, sexual orientation, or disability — even if replies bring them up. These are never material for a roast.
2. **Attack the body or appearance.** No comments on weight, attractiveness, body, face, height, etc. This is where real harm and eating-disorder-adjacent damage lives. Roast behavior, not bodies — full stop.
3. **State or imply factual wrongdoing.** No claims (or winking implications) that the person is a cheater, thief, liar, abuser, criminal, etc. This is the **defamation zone**, and because the app authored the gist, it is the app's liability. A reply alleging wrongdoing is **excluded from synthesis** and never reproduced or alluded to. (Traits like "perpetually late" are fine; accusations of bad acts are not.)
4. **Touch mental health, trauma, self-harm, addiction, or grief.** Not as a roast, not as "insight," not at all. If replies raise it, exclude it.
5. **Sexualize the person** or include sexual content about them.
6. **Punch at the person's fundamental worth.** No "nobody actually likes you," "your friends secretly can't stand you," "you're a bad person." Even if a cluster of replies is hostile, the gist does not render a verdict on whether the person deserves to be liked. (See §8 hostile-set handling.)
7. **Out or expose private/sensitive facts** (relationship status changes, medical info, family situations, anything a reply discloses that isn't theirs to broadcast).

Anything not on this list, and that hits *behavior/quirks*, is fair game — and on `spicy` prompts, should be hit with full force. The bright lines don't make the gist toothless; they **aim** the teeth.

---

## 10. Handling over-the-line content inside replies

Replies are free text and some will cross the lines above. The generator's job:

- **Exclude** the offending content from synthesis entirely. Do not soften-and-include; omit.
- **Never reproduce or quote it**, not even partially, and not in the raw "see more" path that the gist controls.
- **Count it.** Return `excluded_count` (§11) so the product can observe how much is being dropped.
- **Do not let it shape the verdict.** Excluded content gets zero weight.

Note the riskiest surface is the **raw "see more" reply view**, not the gist itself — the gist filters, but raw public replies are shown as written (and **attributed** — `PRODUCT.md` §6.7/§11). That view is governed by `PRODUCT.md` §10 (the product should additionally flag/queue over-the-line replies for review, and `revoke`/`block`/`report` are the user-facing remedies). The gist generator is responsible only for never *synthesizing* over-the-line material into its output.

---

## 11. Output format / schema

Generate **structured output** (JSON) for reliability. Recommended schema:

```json
{
  "verdict": "string — one punchy headline line, the share-card hook. <= ~120 chars.",
  "gist": "string — the portrait. 2–4 short, punchy paragraphs OR a tight set of 4–7 sentences. Mobile-readable. Second person.",
  "excluded_count": 0,
  "tone_flag": "ok | thin | hostile"
}
```

Field notes:
- **`verdict`** — the quotable one-liner (e.g., *"The human aux cord — somehow always in charge of the vibe, never asked to be."*). This is what headlines the profile card and the share-card. Make it land.
- **`gist`** — the body. Keep it mobile-sized; this is a phone product. Lead with the strongest read.
- **`excluded_count`** — number of replies dropped for bright-line reasons (§10). Product-side signal; not shown to users by default.
- **`tone_flag`** — `ok` normally; `thin` if too little usable signal; `hostile` if the set was genuinely contemptuous (§8). The product decides what to do with `thin`/`hostile` (render softly, hold, or nudge for more replies).

**Point of view:** generate in **second person** ("you"), since the owner is the primary reader and the share-card speaks to/about them. If a third-person variant is ever needed (e.g., a viewer-facing surface), derive it product-side or pass a `pov` parameter — but default and canonical is second person.

---

## 12. The system prompt (first generation — ready to use)

> Drop-in starting point for the first-generation call. Tune wording, but preserve the golden rule, the consensus rule, the bright lines, and the structured output contract.

```
You write "gists" for an app called Who Am I. A gist is a short, funny, blunt, AFFECTIONATE portrait of a person, synthesized from things their friends wrote about them in answer to a daily prompt. Your voice is a sharp friend roasting someone at a party — witty, specific, warm underneath. Never a therapist, never a hater, never a generic personality report.

THE ONE RULE THAT GOVERNS EVERYTHING:
Roast the BEHAVIOR, never the PERSON underneath. Quirks, habits, chaos energy, running jokes = fair game, go hard. Their worth, identity, body, mental health, or alleged wrongdoing = never. If a line couldn't be read aloud to the person's face with love, cut it.

YOU WILL RECEIVE:
- The prompt the replies answer, and its tone tag (wholesome | playful | social | spicy).
- A set of short replies friends wrote about the person. (You do NOT know who wrote which — never name or single out a source.)

HOW TO SYNTHESIZE:
- Reflect what MULTIPLE replies say. A trait several people mention is the spine; one-offs are color or cut. NEVER turn a single nasty reply into "everyone thinks X."
- Launder the tone: keep the behavioral truth, lose the venom. "Never shuts up" -> "has never once permitted a silence to exist." "Flaky" -> "replies to plans in 3-5 business days."
- Be specific and quotable. Generic filler that could describe anyone is a failure.
- Play contradictions for comedy instead of averaging them out.
- Calibrate to the tone tag: wholesome = warm with a wink; playful = imaginative/character-driven; social = candid affectionate roast; spicy = maximum teeth — WITHIN the hard limits below.

HARD LIMITS — NEVER, regardless of tone or what the replies say:
1. No race, ethnicity, nationality, religion, sex, gender identity, sexual orientation, or disability.
2. No comments on body, weight, attractiveness, or appearance.
3. No stating or implying wrongdoing (cheater, thief, liar, abuser, criminal, etc.). Exclude any reply alleging it; never reproduce or hint at it.
4. No mental health, trauma, self-harm, addiction, or grief.
5. Nothing sexual about the person.
6. No verdicts on their fundamental worth ("nobody likes you," "your friends can't stand you"). If the replies are genuinely hostile rather than playful, pull back and stay light.
7. Don't out or expose private/sensitive facts a reply discloses.
Exclude any over-the-line content from your synthesis entirely and give it zero weight.

OUTPUT — return ONLY this JSON, no preamble:
{
  "verdict": "<one punchy headline line, the share-card hook, <=120 chars>",
  "gist": "<2-4 short punchy paragraphs or 4-7 tight sentences, second person ('you'), mobile-readable>",
  "excluded_count": <number of replies you dropped for hard-limit reasons>,
  "tone_flag": "<ok | thin | hostile>"
}
```

---

## 13. The regeneration prompt (accretion — for living updates)

> Used for every regeneration after the first. Identical voice/rules as §12, plus the accretion instruction and the prior gist. Append this block to the §12 system prompt (or send the prior gist as additional context with these instructions).

```
THIS IS AN UPDATE TO AN EXISTING GIST. You are given the previous gist (verdict + body) and the person's FULL current set of replies.

EVOLVE the portrait — do not start over:
- Preserve characterizations that are still well-supported by the replies. The reader should recognize their gist as the same portrait gaining detail, not a different verdict each time.
- Add new facets the newer replies reveal.
- Sharpen existing observations with better specifics.
- Revise a previous take ONLY if the weight of evidence has genuinely shifted (e.g., many new replies contradict an early read). Otherwise keep it.
- Avoid wholesale rewrites and avoid contradicting a still-true earlier read. No whiplash.

PREVIOUS GIST:
verdict: "<prior verdict>"
gist: "<prior body>"

Return the same JSON schema as before.
```

---

## 14. Regeneration cadence & cost

This runs across many posts; cost and latency are real. Rules:

- **Never regenerate per reply.** Batch.
- **Trigger regeneration when ANY of:**
  - the post first graduates (initial generation), or
  - it has accumulated **+N new replies** since the last generation (recommended `N = 5`), or
  - it has grown by **≥25%** in replies since the last generation (whichever of the two thresholds hits first), or
  - a person was **revoked** and this post lost replies.
- **Rate cap:** at most **once per post per ~24h** for growth-driven regens (revoke-driven regens can bypass the cap). Prevents a viral post from regenerating constantly. (Tunable.)
- **Run as a batched job**, not inline on the request path — a scheduled worker that scans posts needing regeneration (e.g., the same daily cron that publishes prompts, plus an event-driven enqueue on revoke).

**Model & sampling:**
- The gist is the product's voice — use a capable but cost-efficient model (Sonnet-tier recommended; evaluate Haiku-tier for the volume if quality holds). Lock the model id per `gist_versions` row for reproducibility.
- Use **structured output** / JSON mode for schema reliability.
- Temperature **~0.7–0.9** — enough wit to be funny, not so loose it goes off the rails or breaks the limits.
- Keep `max_tokens` tight; the gist is short by design.

---

## 15. Post-generation safety check (defense in depth)

Because the gist is first-party content, do **not** trust the generation prompt alone to hold the bright lines. After generation, run a **cheap second-pass check** on the OUTPUT (`verdict` + `gist`):

- A small/fast model (Haiku-tier) or a classifier asked: "Does this text reference protected characteristics, body/appearance, allegations of wrongdoing, mental health/trauma, sexual content, or a verdict on the person's worth? Yes/No + which."
- **On a flagged failure:** regenerate once with a reinforced instruction; if it fails again, fall back to a safe, generic-but-warm template gist and log for review. Never publish a flagged gist.
- Log `excluded_count` and `tone_flag` distributions to monitor whether prompts are pulling toward the lines (a spike means a prompt needs pulling from the deck).

This check is cheap relative to the liability it guards against. Build it in Phase 3 alongside the generator, not later.

---

## 16. Edge cases

- **Too few replies at generation:** shouldn't happen — graduation enforces `MIN_FLOOR` (`PRODUCT.md` §6.5). If a post is forced to generate near the floor (time-fallback), expect `tone_flag: "thin"` and a lighter, higher-level gist.
- **Mostly private replies:** private replies are excluded from synthesis (§3), so a post can graduate yet hand the generator only a few public replies. Treat like a thin set — `tone_flag: "thin"`, stay high-level, don't pad.
- **Replies in another language / emoji-only / gibberish:** synthesize what's usable; if there's no usable signal, `tone_flag: "thin"` and keep it short and safe.
- **All replies are pure praise:** that's fine — render a warm gist (don't manufacture roast material that isn't there). Tone tag still applies.
- **All/mostly hostile replies:** `tone_flag: "hostile"`, pull back hard (§8), never escalate. Product may hold or render softly.
- **Replies that are entirely over-the-line:** exclude all, return `tone_flag: "thin"` (effectively no usable signal) with high `excluded_count`; product treats like a thin set.
- **Regeneration after revoke drops the post below MIN_FLOOR:** keep the existing gist version (don't delete history) but the product may mark it stale and stop it from growing further (`PRODUCT.md` §10).
- **Conflicting prior gist vs new evidence:** evolve, don't snap (§5). Only revise on genuine weight-of-evidence shift.

---

## 17. Quality bar — good vs bad

### ✅ Good (prompt: "How are they socially?", tone: social)

```json
{
  "verdict": "The human aux cord — always running the vibe, never actually asked to.",
  "gist": "Your people are unanimous: you're the social glue. You text the group chat first, you herd everyone to the function, and three separate friends called you 'the planner' — which is friend-speak for lovable control freak who has never met a group decision they didn't quietly hijack. The running bit is that you'll cancel plans twice and then somehow show up the most invested person in the room. Loud, loyal, and physically incapable of letting a silence happen.",
  "excluded_count": 0,
  "tone_flag": "ok"
}
```
Why it works: specific, quotable, blunt, warm underneath. Hits behaviors (planning, talking, flaking-then-overcommitting), never the person's worth, body, or character. Plays the cancel-then-show-up contradiction for comedy.

### ❌ Bad (same inputs) — DO NOT generate

```json
{
  "verdict": "Annoying, kind of a lot, and honestly people just tolerate you.",
  "gist": "Everyone says you talk too much and that you've put on weight lately. A couple people think you're fake and that you cheated on your ex. Most of your friends seem to just put up with you out of obligation..."
}
```
Why it fails, line by line: "people just tolerate you" / "put up with you out of obligation" = verdict on worth (limit 6); "put on weight" = body (limit 2); "you're fake" + "cheated on your ex" = implied character + alleged wrongdoing (limit 3, defamation). Even if replies said all of this, the gist excludes it and never renders it. The correct move is the ✅ version: take the *behavioral* signal ("talks a lot"), launder it, drop everything else.

### Tone-laundering quick reference (keep, don't ship the left column)
- "never shuts up" → "has never once permitted a silence to exist"
- "always late" → "operates on a personal timezone ~20 minutes behind reality"
- "broke / bad with money" → "treats their bank balance as more of a vibe than a number"
- "flaky" → "replies to plans in 3–5 business days"
- "control freak" → "benevolent dictator of the group-chat itinerary"

---

## 18. Implementation checklist (for Phase 3)

- [ ] Generator service with the §12 system prompt + structured output.
- [ ] Regeneration path with the §13 accretion prompt (prior gist + full replies).
- [ ] `prompt_tone` calibration wired (§7).
- [ ] Consensus + hostile/thin handling reflected in prompt and surfaced via `tone_flag` (§8, §11).
- [ ] Bright lines enforced in-prompt (§9) **and** verified by the §15 post-generation check.
- [ ] Over-the-line replies excluded from synthesis; `excluded_count` returned (§10).
- [ ] Batched regeneration triggers + 24h growth cap + revoke-driven enqueue (§14).
- [ ] Append-only `gist_versions` with `model`, `reply_count_at_generation`, timestamps (§5) — powers the evolution feature.
- [ ] Cost-efficient model locked per version; structured output; temp ~0.7–0.9 (§14).
- [ ] Monitoring on `excluded_count` / `tone_flag` to catch prompts drifting toward the lines (§15).

---

*This spec is the contract for the gist. The product can tune knobs (thresholds, cadence, model), but the golden rule (§2), the consensus rule (§8), and the bright lines (§9) are fixed — they are what make this an affectionate roast people love instead of a liability people get hurt by.*
