// gist_prompt.ts — the provider-agnostic core of the gist generator: the prompt text, the output
// schema + validation, and the model-capability gates. Shared by the PRODUCTION generator
// (gist.ts, which calls Anthropic) and the FREE local preview tool (gist_preview.ts, which runs
// the same prompt through Ollama / any OpenAI-compatible endpoint). One source of truth for the
// prompt means the preview tests EXACTLY what production ships.

export interface GistJSON {
  verdict: string;
  gist: string;
  excluded_count: number;
  tone_flag: "ok" | "thin" | "hostile";
}

export const SYSTEM = `You write "gists" for an app called Grapevine. A gist is a short, funny, blunt, AFFECTIONATE portrait of a person, synthesized from things their friends wrote about them in answer to a daily prompt. Your voice is a sharp friend roasting someone at a party — witty, specific, warm underneath. Never a therapist, never a hater, never a generic personality report.

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

export const ACCRETION = `
THIS IS AN UPDATE. You are given the previous gist and the FULL current set of public replies. EVOLVE the portrait — do not start over. Preserve still-supported characterizations, add new facets, sharpen specifics, and revise a prior take ONLY if the weight of evidence has genuinely shifted. The reader should recognize the same portrait gaining detail, not a different verdict each time. Avoid wholesale rewrites and do not contradict a still-true earlier read. No whiplash. Return the same JSON schema.`;

// Reinforcement appended on the ONE safety retry (docs/GIST.md §15).
export const SAFETY_REINFORCE = `

CRITICAL — YOUR PREVIOUS OUTPUT FAILED THE SAFETY CHECK. Regenerate from scratch and STAY STRICTLY WITHIN THE HARD LIMITS. The text must NOT reference, hint at, or imply any of: protected characteristics; body, weight, attractiveness, or appearance; allegations of wrongdoing (cheating, lying, crime, etc.); mental health, trauma, self-harm, addiction, or grief; anything sexual; or a verdict on the person's worth ("nobody likes you"). Roast ONLY behavior/habits/quirks. When in doubt, cut the line and keep it light and warm. Return ONLY the JSON schema.`;

// Structured-output schemas (Anthropic; Sonnet 4.6 / Haiku 4.5). String length isn't a schema
// constraint — verdict is clamped in code.
export const GIST_SCHEMA = {
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

export const SAFETY_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    ok: { type: "boolean" },
    why: { type: "string" },
  },
  required: ["ok", "why"],
} as const;

// Post-generation safety classifier (docs/GIST.md §15). Explicit polarity: ok=true ONLY when the
// text is clean, ok=false (with a reason) on any hit, ok=false when uncertain.
export const SAFETY_SYSTEM =
  `You are a strict content-safety classifier for first-party app text that will be published about a named real person. Return ONLY JSON {"ok":boolean,"why":string}. ` +
  `Set ok=true ONLY IF the text is completely free of ALL of: references to protected characteristics (race, ethnicity, nationality, religion, sex, gender identity, sexual orientation, disability); comments on body, weight, attractiveness, or appearance; any statement or implication of wrongdoing (cheating, theft, lying, abuse, crime, etc.); mental health, trauma, self-harm, addiction, or grief; sexual content; or any verdict on the person's fundamental worth (e.g. "nobody likes you"). ` +
  `If ANY of those are present or even implied, set ok=false and name the category in "why". When uncertain, set ok=false.`;

// Model-independent backstop for the defamation bright line (GIST.md §9 #3). Strong accusation
// NOUNS only (not verbs like "stole"/"cheated", which have innocent roast uses). Best-effort.
export const DEFAMATION =
  /\b(cheater|adulter(?:er|ess|ous)|thief|thieving|liar|fraudster|scammer|abuser|rapist|p(?:a)?edophile|predator|stalker|molester|criminal|felon|convict(?:ed)?)\b/i;

export const FALLBACK_MODEL = "fallback-template";
// Below this many PUBLIC replies, skip the model and write the warm thin fallback (GIST.md §16).
export const MIN_PUBLIC_FLOOR = 3;

// Opus 4.7+ and Fable reject sampling params (temperature/top_p/top_k) with a 400.
export function modelAcceptsTemperature(model: string): boolean {
  if (model.startsWith("claude-fable")) return false;
  const m = model.match(/^claude-opus-4-(\d+)/);
  if (m && Number(m[1]) >= 7) return false;
  return true;
}

// Structured Outputs (output_config.format) are supported on Sonnet 4.6, Haiku 4.5, Fable 5,
// Opus 4.8, and legacy Opus 4.5/4.1 — but NOT Opus 4.6/4.7.
export function modelSupportsStructuredOutput(model: string): boolean {
  return !/^claude-opus-4-[67]\b/.test(model);
}

// Clamp the verdict to the <=120 char contract on a word boundary (audit P2).
export function clampVerdict(v: string): string {
  const t = v.trim();
  if (t.length <= 120) return t;
  const cut = t.slice(0, 119);
  const lastSpace = cut.lastIndexOf(" ");
  const base = lastSpace > 60 ? cut.slice(0, lastSpace) : cut;
  return base.replace(/[\s.,;:!?-]+$/, "") + "…";
}

// Validate + coerce parsed model output. Returns null (=> failed generation) on missing/empty
// verdict|gist; clamps verdict; coerces tone_flag to the enum and excluded_count to a non-neg int.
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

// A guaranteed-safe, warm, generic gist (GIST.md §15/§16). Hits no bright lines.
export function fallbackGist(): GistJSON {
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

// Pull the JSON object out of a model's text response (handles preamble/fences).
export function sliceJSON(text: string): unknown {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end === -1) throw new Error("no JSON in model output");
  return JSON.parse(text.slice(start, end + 1));
}

// Build the user message: prompt + tone + owner + replies, marking NEW-since-last-gist when
// regenerating (GIST.md §5). Used by BOTH the production generator and the preview tool.
export function buildUserContent(args: {
  promptText: string;
  tone: string;
  ownerName: string;
  bodies: string[];
  prior?: { verdict: string | null; body: string } | null;
  priorCount?: number;
}): string {
  const { promptText, tone, ownerName, bodies, prior = null, priorCount = 0 } = args;
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
  return (
    `PROMPT: ${promptText}\nTONE: ${tone}\n` +
    (ownerName ? `OWNER_DISPLAY_NAME (this is who the gist is about — still address them in second person, "you"): ${ownerName}\n` : "") +
    `\n${repliesSection}` +
    (prior ? `\n\nPREVIOUS GIST:\nverdict: ${prior.verdict ?? ""}\ngist: ${prior.body}` : "")
  );
}
