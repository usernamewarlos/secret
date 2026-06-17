// Shared gist generation for Grapevine Edge Functions.
// Implements docs/GIST.md: voice, consensus rule, bright lines, accretion, and the
// post-generation safety check. PUBLIC replies only — private replies are author-only
// and never reach this code.
//
// Secrets come from the Edge Function environment ONLY (never the app, never the repo):
//   ANTHROPIC_API_KEY, ANTHROPIC_MODEL (default claude-sonnet-4-6), ANTHROPIC_SAFETY_MODEL.

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const GEN_MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-6";
const SAFETY_MODEL = Deno.env.get("ANTHROPIC_SAFETY_MODEL") ?? "claude-haiku-4-5-20251001";

// Headroom for an upper-bound 2–4 paragraph gist plus JSON-escape overhead (audit: 700 could
// truncate mid-JSON). Still "tight" per GIST.md §14; billed only on tokens actually produced.
const GEN_MAX_TOKENS = 1024;
// Below this many PUBLIC replies, skip the model entirely and write the warm thin fallback
// (GIST.md §16: "thin → stay high-level, don't pad"). Mirrors compute_threshold's MIN_FLOOR.
const MIN_PUBLIC_FLOOR = 3;

export function serviceClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

const SYSTEM = `You write "gists" for an app called Grapevine. A gist is a short, funny, blunt, AFFECTIONATE portrait of a person, synthesized from things their friends wrote about them in answer to a daily prompt. Your voice is a sharp friend roasting someone at a party — witty, specific, warm underneath. Never a therapist, never a hater, never a generic personality report.

THE ONE RULE: Roast the BEHAVIOR, never the PERSON underneath. Quirks, habits, chaos energy, running jokes = fair game. Their worth, identity, body, mental health, or alleged wrongdoing = never. If a line couldn't be read aloud to the person's face with love, cut it.

SYNTHESIS:
- Reflect what MULTIPLE replies say; a trait several mention is the spine, one-offs are color or cut. NEVER turn one nasty reply into "everyone thinks X."
- Launder tone: keep the behavioral truth, lose the venom. "Never shuts up" -> "has never once permitted a silence to exist."
- Be specific and quotable. Play contradictions for comedy.
- Calibrate to the tone tag: wholesome = warm with a wink; playful = imaginative; social = candid affectionate roast; spicy = maximum teeth WITHIN the limits.

HARD LIMITS — NEVER, regardless of tone or replies:
1. No race, ethnicity, nationality, religion, sex, gender identity, sexual orientation, or disability.
2. No body, weight, attractiveness, or appearance.
3. No stating/implying wrongdoing (cheater, thief, liar, abuser, criminal). Exclude such replies; never hint at them.
4. No mental health, trauma, self-harm, addiction, or grief.
5. Nothing sexual about the person.
6. No verdicts on their worth ("nobody likes you"). If replies are genuinely hostile, pull back and stay light.
7. Don't out or expose private/sensitive facts.
Exclude any over-the-line content from synthesis entirely; give it zero weight.

OUTPUT — return ONLY this JSON, no preamble:
{"verdict":"<one punchy headline, <=120 chars>","gist":"<2-4 short paragraphs or 4-7 tight sentences, second person, mobile-readable>","excluded_count":<int>,"tone_flag":"<ok|thin|hostile>"}`;

const ACCRETION = `
THIS IS AN UPDATE. You are given the previous gist and the FULL current set of public replies. EVOLVE the portrait — do not start over. Preserve still-supported characterizations, add new facets, sharpen specifics, and revise a prior take ONLY if the weight of evidence has genuinely shifted. The reader should recognize the same portrait gaining detail, not a different verdict each time. Avoid wholesale rewrites and do not contradict a still-true earlier read. No whiplash. Return the same JSON schema.`;

// Reinforcement appended on the ONE safety retry (docs/GIST.md §15). The first output tripped the
// post-generation classifier; re-state the bright lines as absolute and demand a clean rewrite.
const SAFETY_REINFORCE = `

CRITICAL — YOUR PREVIOUS OUTPUT FAILED THE SAFETY CHECK. Regenerate from scratch and STAY STRICTLY WITHIN THE HARD LIMITS. The text must NOT reference, hint at, or imply any of: protected characteristics; body, weight, attractiveness, or appearance; allegations of wrongdoing (cheating, lying, crime, etc.); mental health, trauma, self-harm, addiction, or grief; anything sexual; or a verdict on the person's worth ("nobody likes you"). Roast ONLY behavior/habits/quirks. When in doubt, cut the line and keep it light and warm. Return ONLY the JSON schema.`;

interface GistJSON {
  verdict: string;
  gist: string;
  excluded_count: number;
  tone_flag: "ok" | "thin" | "hostile";
}

// Structured-output schemas: the API constrains the response to valid JSON matching these,
// so we no longer trust a brace-slice of free text (audit: brittle at temp 0.8). Supported on
// Sonnet 4.6 / Haiku 4.5. (String length isn't a schema constraint — verdict is clamped below.)
const GIST_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    verdict: { type: "string" },
    gist: { type: "string" },
    excluded_count: { type: "integer" },
    tone_flag: { type: "string", enum: ["ok", "thin", "hostile"] },
  },
  required: ["verdict", "gist", "excluded_count", "tone_flag"],
} as const;

const SAFETY_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    ok: { type: "boolean" },
    why: { type: "string" },
  },
  required: ["ok", "why"],
} as const;

// Last, model-independent backstop for the defamation bright line (GIST.md §9 #3). If a strong
// accusation noun reaches the OUTPUT, force the fallback regardless of the classifier's verdict.
// Strong nouns only (not verbs like "stole"/"cheated", which have innocent roast uses such as
// "stole the show"/"cheated at Monopoly") to keep false positives low. Best-effort, not complete.
export const DEFAMATION =
  /\b(cheater|adulter(?:er|ess|ous)|thief|thieving|liar|fraudster|scammer|abuser|rapist|p(?:a)?edophile|predator|stalker|molester|criminal|felon|convict(?:ed)?)\b/i;

// Opus 4.7+ and Fable reject sampling params (temperature/top_p/top_k) with a 400. The model is
// env-configurable (ANTHROPIC_MODEL/ANTHROPIC_SAFETY_MODEL), so gate temperature by model rather
// than hardcoding it onto every request (audit: a model upgrade would 400 every gist).
export function modelAcceptsTemperature(model: string): boolean {
  if (model.startsWith("claude-fable")) return false;
  const m = model.match(/^claude-opus-4-(\d+)/);
  if (m && Number(m[1]) >= 7) return false;
  return true;
}

// Structured Outputs (output_config.format) are supported on Sonnet 4.6, Haiku 4.5, Fable 5,
// Opus 4.8, and legacy Opus 4.5/4.1 — but NOT Opus 4.6/4.7. When unsupported, omit the schema and
// fall back to the in-prompt JSON instruction + coerceGist() validation rather than 400-ing every
// request (which would silently degrade every gist to the warm template).
export function modelSupportsStructuredOutput(model: string): boolean {
  return !/^claude-opus-4-[67]\b/.test(model);
}

async function callAnthropic(
  system: string,
  user: string,
  model: string,
  maxTokens: number,
  schema?: Record<string, unknown>,
): Promise<string> {
  // deno-lint-ignore no-explicit-any
  const body: Record<string, any> = {
    model,
    max_tokens: maxTokens,
    system,
    messages: [{ role: "user", content: user }],
  };
  if (modelAcceptsTemperature(model)) body.temperature = 0.8;
  if (schema && modelSupportsStructuredOutput(model)) body.output_config = { format: { type: "json_schema", schema } };

  const res = await fetch(ANTHROPIC_URL, {
    method: "POST",
    headers: {
      "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`anthropic ${res.status}: ${await res.text()}`);
  const data = await res.json();
  // A truncated body has no closing brace and would parse-fail or worse; treat it as a failed
  // generation so it routes to the retry/fallback rather than persisting half a gist (audit).
  if (data?.stop_reason === "max_tokens") throw new Error("anthropic output truncated (max_tokens)");
  return data?.content?.[0]?.text ?? "";
}

function parseJSON(text: string): unknown {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end === -1) throw new Error("no JSON in model output");
  return JSON.parse(text.slice(start, end + 1));
}

// Clamp the verdict to the <=120 char contract the prompt asks for (unenforced by the model);
// truncate on a word boundary so the share-card headline never overflows (audit P2).
export function clampVerdict(v: string): string {
  const t = v.trim();
  if (t.length <= 120) return t;
  const cut = t.slice(0, 119);
  const lastSpace = cut.lastIndexOf(" ");
  const base = lastSpace > 60 ? cut.slice(0, lastSpace) : cut;
  return base.replace(/[\s.,;:!?-]+$/, "") + "…";
}

// Validate + coerce the parsed model output. Returns null (=> caller treats as a failed
// generation) on missing/empty verdict|gist; clamps verdict; coerces tone_flag to the enum and
// excluded_count to a non-negative int (audit: fields were trusted unvalidated).
export function coerceGist(raw: unknown): GistJSON | null {
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  const verdict = typeof r.verdict === "string" ? r.verdict.trim() : "";
  const gist = typeof r.gist === "string" ? r.gist.trim() : "";
  if (!verdict || !gist) return null;
  const tone_flag: GistJSON["tone_flag"] =
    r.tone_flag === "ok" || r.tone_flag === "thin" || r.tone_flag === "hostile" ? r.tone_flag : "thin";
  const ec = Number(r.excluded_count);
  const excluded_count = Number.isFinite(ec) && ec >= 0 ? Math.floor(ec) : 0;
  return { verdict: clampVerdict(verdict), gist, excluded_count, tone_flag };
}

// A guaranteed-safe, warm, generic gist used when generation fails (safety check, truncation,
// thrown error, or near-empty input) — docs/GIST.md §15/§16. Hits no bright lines, so a graduated
// post is NEVER left without a gist. Persisted with model 'fallback-template'.
const FALLBACK_MODEL = "fallback-template";
function fallbackGist(): GistJSON {
  return {
    verdict: "Your people showed up — and they clearly adore you.",
    gist:
      "Your friends answered, and the throughline is simple: you're someone worth writing about. " +
      "The takes are warm, a little chaotic, and unmistakably fond — the kind of thing people only " +
      "bother to say about someone they actually love having around. There's more shape to come as " +
      "more friends weigh in, but the headline is already clear: you matter to your people, and they " +
      "wanted you to know it.",
    excluded_count: 0,
    tone_flag: "thin",
  };
}

// Defense-in-depth: a cheap second pass over the OUTPUT (docs/GIST.md §15). The contract is stated
// explicitly in BOTH directions — ok=true ONLY if the text is clean, ok=false (with a reason) on
// any hit, and ok=false when uncertain — so the gate's polarity can't be guessed wrong (audit P1).
// Fails closed: any error or unparseable output is treated as unsafe.
async function safetyCheck(verdict: string, gist: string): Promise<boolean> {
  const system =
    `You are a strict content-safety classifier for first-party app text that will be published about a named real person. Return ONLY JSON {"ok":boolean,"why":string}. ` +
    `Set ok=true ONLY IF the text is completely free of ALL of: references to protected characteristics (race, ethnicity, nationality, religion, sex, gender identity, sexual orientation, disability); comments on body, weight, attractiveness, or appearance; any statement or implication of wrongdoing (cheating, theft, lying, abuse, crime, etc.); mental health, trauma, self-harm, addiction, or grief; sexual content; or any verdict on the person's fundamental worth (e.g. "nobody likes you"). ` +
    `If ANY of those are present or even implied, set ok=false and name the category in "why". When uncertain, set ok=false.`;
  let out: string;
  try {
    out = await callAnthropic(system, `Classify this text.\n\nVERDICT: ${verdict}\n\nGIST: ${gist}`, SAFETY_MODEL, 200, SAFETY_SCHEMA);
  } catch {
    return false; // fail closed (network/truncation/etc.)
  }
  try {
    const parsed = parseJSON(out) as { ok?: unknown };
    return parsed.ok === true;
  } catch {
    return false; // fail closed
  }
}

// One generation attempt: call the model, coerce, and run BOTH the classifier and the defamation
// post-filter. Returns the coerced gist plus whether it's safe. A thrown error => null/unsafe.
async function attempt(system: string, user: string): Promise<{ out: GistJSON | null; safe: boolean }> {
  let out: GistJSON | null = null;
  try {
    out = coerceGist(parseJSON(await callAnthropic(system, user, GEN_MODEL, GEN_MAX_TOKENS, GIST_SCHEMA)));
  } catch {
    return { out: null, safe: false };
  }
  if (!out) return { out: null, safe: false };
  const clean = !DEFAMATION.test(`${out.verdict}\n${out.gist}`);
  const safe = clean && (await safetyCheck(out.verdict, out.gist));
  return { out, safe };
}

// Generate (or regenerate, by accretion) the gist for a single post.
export async function generateGistForPost(sb: SupabaseClient, postId: string): Promise<{ ok: boolean; tone_flag?: string; reason?: string }> {
  // Post + prompt text + the post's chosen spice level (the tone the gist calibrates to,
  // GIST.md §7) + the owner's display name (GIST.md §3 required input).
  const { data: post } = await sb
    .from("posts")
    .select("id, prompt_id, status, spice_level, prompts(text), users:profile_owner_id(display_name)")
    .eq("id", postId)
    .single();
  if (!post) return { ok: false, reason: "post not found" };

  // PUBLIC replies only, oldest-first (so we can mark which arrived since the last gist).
  const { data: replies } = await sb
    .from("replies")
    .select("body")
    .eq("post_id", postId)
    .eq("is_private", false)
    .order("created_at", { ascending: true });
  const bodies: string[] = (replies ?? []).map((r: { body: string }) => r.body);

  // Gist row + prior version (for accretion + the new-vs-old split).
  let { data: gist } = await sb.from("gists").select("id, current_version_id").eq("post_id", postId).maybeSingle();
  if (!gist) {
    const ins = await sb.from("gists").insert({ post_id: postId }).select("id, current_version_id").single();
    gist = ins.data;
  }
  if (!gist) return { ok: false, reason: "could not create gist row" };

  // Near-empty public set (e.g. a time-fallback graduation that was mostly private replies):
  // deterministically write the warm thin fallback rather than asking the model to invent a
  // portrait from nothing (GIST.md §16). Also saves a model round-trip.
  if (bodies.length < MIN_PUBLIC_FLOOR) {
    // Don't clobber an already-good gist with the thin template — if a prior version exists, the
    // stale-flag read-path cue conveys the thinned state instead (this only fires on first gen of a
    // genuinely thin post, e.g. a mostly-private time-fallback graduation).
    if (gist.current_version_id) return { ok: true, reason: "kept existing gist; too few public replies to re-synthesize" };
    return await persist(sb, gist.id, fallbackGist(), FALLBACK_MODEL, bodies.length);
  }

  let prior: { verdict: string | null; body: string } | null = null;
  let priorCount = 0;
  if (gist.current_version_id) {
    const { data: pv } = await sb
      .from("gist_versions")
      .select("verdict, body, reply_count_at_generation")
      .eq("id", gist.current_version_id)
      .single();
    if (pv) {
      prior = { verdict: pv.verdict, body: pv.body };
      priorCount = pv.reply_count_at_generation ?? 0;
    }
  }

  // deno-lint-ignore no-explicit-any
  const promptMeta = (post as any).prompts;
  // deno-lint-ignore no-explicit-any
  const ownerMeta = (post as any).users;
  // The post's chosen spice level (capped at the prompt's tone) is the tone the generator
  // calibrates to — NOT the raw prompt tone (GIST.md §7).
  // deno-lint-ignore no-explicit-any
  const tone = (post as any).spice_level ?? "social";
  const promptText = promptMeta?.text ?? "";
  const ownerName = ownerMeta?.display_name ?? "";

  // Mark which replies are NEW since the last gist so the accretion pass can weigh fresh evidence
  // explicitly (GIST.md §5) rather than re-deriving everything blind.
  let repliesSection: string;
  if (prior && priorCount > 0 && priorCount < bodies.length) {
    const earlier = bodies.slice(0, priorCount);
    const fresh = bodies.slice(priorCount);
    repliesSection =
      `EARLIER REPLIES (${earlier.length}):\n` + earlier.map((b, i) => `${i + 1}. ${b}`).join("\n") +
      `\n\nNEW SINCE LAST GIST (${fresh.length}):\n` + fresh.map((b, i) => `${earlier.length + i + 1}. ${b}`).join("\n");
  } else {
    repliesSection = `PUBLIC REPLIES (${bodies.length}):\n` + bodies.map((b, i) => `${i + 1}. ${b}`).join("\n");
  }

  const userContent =
    `PROMPT: ${promptText}\nTONE: ${tone}\n` +
    (ownerName ? `OWNER_DISPLAY_NAME (this is who the gist is about — still address them in second person, "you"): ${ownerName}\n` : "") +
    `\n${repliesSection}` +
    (prior ? `\n\nPREVIOUS GIST:\nverdict: ${prior.verdict ?? ""}\ngist: ${prior.body}` : "");

  const baseSystem = SYSTEM + (prior ? ACCRETION : "");

  // First generation + safety check (both guarded: a throw here must still reach the fallback,
  // never escape and leave a graduated post gist-less — audit P1).
  let { out, safe } = await attempt(baseSystem, userContent);

  // SAFETY RETRY: on failure, regenerate ONCE with the reinforced 'stay within the limits' system.
  if (!safe) {
    const retry = await attempt(baseSystem + SAFETY_REINFORCE, userContent);
    if (retry.safe) { out = retry.out; safe = true; }
  }

  // FALLBACK: if it STILL isn't safe (or never parsed), write the warm generic template rather
  // than publishing a flagged gist or leaving the post gist-less (GIST.md §15).
  let model = GEN_MODEL;
  if (!safe || !out) {
    out = fallbackGist();
    model = FALLBACK_MODEL;
  }

  return await persist(sb, gist.id, out, model, bodies.length);
}

// Append a new gist_versions row and point the gist at it. Returns ok:false (not a throw) on a
// write error so a graduated post is never reported as generated when it wasn't.
async function persist(
  sb: SupabaseClient,
  gistId: string,
  out: GistJSON,
  model: string,
  replyCount: number,
): Promise<{ ok: boolean; tone_flag?: string; reason?: string }> {
  const { data: version, error } = await sb
    .from("gist_versions")
    .insert({
      gist_id: gistId,
      verdict: out.verdict,
      body: out.gist,
      model,
      tone_flag: out.tone_flag,
      excluded_count: out.excluded_count,
      reply_count_at_generation: replyCount,
    })
    .select("id")
    .single();
  if (error || !version) return { ok: false, reason: `version insert failed: ${error?.message ?? "unknown"}` };

  await sb.from("gists").update({ current_version_id: version.id }).eq("id", gistId);
  return { ok: true, tone_flag: out.tone_flag };
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}
