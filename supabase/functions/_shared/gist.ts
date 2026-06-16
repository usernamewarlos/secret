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
THIS IS AN UPDATE. You are given the previous gist and the FULL current set of public replies. EVOLVE the portrait — do not start over. Preserve still-supported characterizations, add new facets, sharpen specifics, and revise a prior take ONLY if the weight of evidence has genuinely shifted. No whiplash. Return the same JSON schema.`;

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

async function callAnthropic(system: string, user: string, model: string, maxTokens: number): Promise<string> {
  const res = await fetch(ANTHROPIC_URL, {
    method: "POST",
    headers: {
      "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model,
      max_tokens: maxTokens,
      temperature: 0.8,
      system,
      messages: [{ role: "user", content: user }],
    }),
  });
  if (!res.ok) throw new Error(`anthropic ${res.status}: ${await res.text()}`);
  const data = await res.json();
  return data?.content?.[0]?.text ?? "";
}

function parseJSON(text: string): GistJSON {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end === -1) throw new Error("no JSON in model output");
  return JSON.parse(text.slice(start, end + 1));
}

// A guaranteed-safe, warm, generic gist used only when generation fails the safety check twice
// (docs/GIST.md §15). Hits no bright lines — pure affection, no behavioral claims to flag — so a
// graduated post is NEVER left without a gist. Persisted with model 'fallback-template'.
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

// Defense-in-depth: a cheap second pass over the OUTPUT (docs/GIST.md §15).
async function safetyCheck(verdict: string, gist: string): Promise<boolean> {
  const out = await callAnthropic(
    `You are a content safety classifier. Answer ONLY with JSON {"ok":boolean,"why":string}.`,
    `Does this text reference protected characteristics, body/appearance, allegations of wrongdoing, mental health/trauma, sexual content, or a verdict on the person's worth?\n\nVERDICT: ${verdict}\n\nGIST: ${gist}`,
    SAFETY_MODEL,
    200,
  );
  try {
    const start = out.indexOf("{");
    const parsed = JSON.parse(out.slice(start, out.lastIndexOf("}") + 1));
    return parsed.ok === true;
  } catch {
    return false; // fail closed
  }
}

// Generate (or regenerate, by accretion) the gist for a single post.
export async function generateGistForPost(sb: SupabaseClient, postId: string): Promise<{ ok: boolean; tone_flag?: string; reason?: string }> {
  // Post + prompt text + the post's chosen spice level (the tone the gist calibrates to,
  // GIST.md §7 / ROADMAP §0) + the owner's display name (GIST.md §3 required input).
  const { data: post } = await sb
    .from("posts")
    .select("id, prompt_id, status, spice_level, prompts(text), users:profile_owner_id(display_name)")
    .eq("id", postId)
    .single();
  if (!post) return { ok: false, reason: "post not found" };

  // PUBLIC replies only.
  const { data: replies } = await sb
    .from("replies")
    .select("body")
    .eq("post_id", postId)
    .eq("is_private", false);
  const bodies: string[] = (replies ?? []).map((r: { body: string }) => r.body);

  // Gist row + prior version (for accretion).
  let { data: gist } = await sb.from("gists").select("id, current_version_id").eq("post_id", postId).maybeSingle();
  if (!gist) {
    const ins = await sb.from("gists").insert({ post_id: postId }).select("id, current_version_id").single();
    gist = ins.data;
  }
  let prior: { verdict: string | null; body: string } | null = null;
  if (gist?.current_version_id) {
    const { data: pv } = await sb.from("gist_versions").select("verdict, body").eq("id", gist.current_version_id).single();
    prior = pv ?? null;
  }

  // deno-lint-ignore no-explicit-any
  const promptMeta = (post as any).prompts;
  // deno-lint-ignore no-explicit-any
  const ownerMeta = (post as any).users;
  // The post's chosen spice level (capped at the prompt's tone by open_post/submit_reply) is the
  // tone the generator calibrates to — NOT the raw prompt tone (ROADMAP §0, GIST.md §7).
  // deno-lint-ignore no-explicit-any
  const tone = (post as any).spice_level ?? "social";
  const promptText = promptMeta?.text ?? "";
  const ownerName = ownerMeta?.display_name ?? "";

  const userContent =
    `PROMPT: ${promptText}\nTONE: ${tone}\n` +
    (ownerName ? `OWNER_DISPLAY_NAME (this is who the gist is about — still address them in second person, "you"): ${ownerName}\n` : "") +
    `\nPUBLIC REPLIES (${bodies.length}):\n` +
    bodies.map((b, i) => `${i + 1}. ${b}`).join("\n") +
    (prior ? `\n\nPREVIOUS GIST:\nverdict: ${prior.verdict ?? ""}\ngist: ${prior.body}` : "");

  const baseSystem = SYSTEM + (prior ? ACCRETION : "");

  // First generation, then the safety check (docs/GIST.md §15).
  let out = parseJSON(await callAnthropic(baseSystem, userContent, GEN_MODEL, 700));
  let model = GEN_MODEL;
  let safe = await safetyCheck(out.verdict, out.gist);

  // SAFETY RETRY: on failure, regenerate ONCE with a reinforced 'stay within the hard limits'
  // instruction. Tolerate a thrown error on the retry so we still reach the fallback below.
  if (!safe) {
    try {
      out = parseJSON(await callAnthropic(baseSystem + SAFETY_REINFORCE, userContent, GEN_MODEL, 700));
      safe = await safetyCheck(out.verdict, out.gist);
    } catch (_) {
      safe = false;
    }
  }

  // FALLBACK: if it STILL fails, write a safe warm generic template gist (model 'fallback-template')
  // rather than leaving a graduated post without a gist. Never publish a flagged gist; never leave
  // a graduated post gist-less (docs/GIST.md §15, ROADMAP A4).
  if (!safe) {
    out = fallbackGist();
    model = FALLBACK_MODEL;
  }

  const { data: version } = await sb
    .from("gist_versions")
    .insert({
      gist_id: gist!.id,
      verdict: out.verdict,
      body: out.gist,
      model,
      tone_flag: out.tone_flag,
      excluded_count: out.excluded_count ?? 0,
      reply_count_at_generation: bodies.length,
    })
    .select("id")
    .single();

  await sb.from("gists").update({ current_version_id: version!.id }).eq("id", gist!.id);
  return { ok: true, tone_flag: out.tone_flag };
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}
