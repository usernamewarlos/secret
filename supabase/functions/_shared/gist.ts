// Shared gist generation for Grapevine Edge Functions (PRODUCTION path). Provider-flexible: runs on
// Groq's free tier ($0) or any OpenAI-compatible endpoint, or Anthropic (the paid upgrade lane) —
// chosen by which secret is set (see resolveProvider below). The prompt text, output schema, and
// validation live in ./gist_prompt.ts (shared with the free local preview tool gist_preview.ts).
// PUBLIC replies only — private replies are author-only and never reach this code.
//
// Secrets come from the Edge Function environment ONLY (never the app, never the repo):
//   GROQ_API_KEY (+ GROQ_MODEL / GROQ_SAFETY_MODEL) — the $0 path; or OPENAI_COMPAT_URL/_KEY/_MODEL;
//   or ANTHROPIC_API_KEY (+ ANTHROPIC_MODEL / ANTHROPIC_SAFETY_MODEL). GIST_PROVIDER forces one.

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  type GistJSON,
  SYSTEM,
  ACCRETION,
  SAFETY_REINFORCE,
  GIST_SCHEMA,
  SAFETY_SCHEMA,
  SAFETY_SYSTEM,
  DEFAMATION,
  FALLBACK_MODEL,
  MIN_PUBLIC_FLOOR,
  coerceGist,
  fallbackGist,
  buildUserContent,
  sliceJSON,
  modelAcceptsTemperature,
  modelSupportsStructuredOutput,
} from "./gist_prompt.ts";

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
// Headroom for an upper-bound 2–4 paragraph gist plus JSON-escape overhead (audit: 700 truncated).
const GEN_MAX_TOKENS = 1024;

// ── Inference provider ───────────────────────────────────────────────────────
// The gist engine is chosen by which secret is set on the Edge Function (priority top-down):
//   OPENAI_COMPAT_URL (+ _KEY / _MODEL / _SAFETY_MODEL)  — any OpenAI-compatible endpoint
//   GROQ_API_KEY                                          — Groq free tier ($0 production path)
//   ANTHROPIC_API_KEY                                     — Anthropic (the paid upgrade lane)
// GIST_PROVIDER (anthropic | groq | openai) forces the choice if more than one key is present.
// Switching provider is therefore a secret change, not a code change. The prompt + safety layer
// are identical across providers.
type Provider = "anthropic" | "openai";
interface ProviderConfig { provider: Provider; base: string; key: string; genModel: string; safetyModel: string; }

function resolveProvider(): ProviderConfig {
  const force = Deno.env.get("GIST_PROVIDER");
  const compatUrl = Deno.env.get("OPENAI_COMPAT_URL");
  const groqKey = Deno.env.get("GROQ_API_KEY");

  const openaiCompat = (): ProviderConfig => ({
    provider: "openai",
    base: (compatUrl ?? "https://api.groq.com/openai/v1").replace(/\/$/, ""),
    key: Deno.env.get("OPENAI_COMPAT_KEY") ?? groqKey ?? "",
    genModel: Deno.env.get("OPENAI_COMPAT_MODEL") ?? Deno.env.get("GROQ_MODEL") ?? "llama-3.3-70b-versatile",
    safetyModel: Deno.env.get("OPENAI_COMPAT_SAFETY_MODEL") ?? Deno.env.get("GROQ_SAFETY_MODEL") ?? "llama-3.1-8b-instant",
  });
  const anthropic = (): ProviderConfig => ({
    provider: "anthropic",
    base: ANTHROPIC_URL,
    key: Deno.env.get("ANTHROPIC_API_KEY") ?? "",
    genModel: Deno.env.get("ANTHROPIC_MODEL") ?? "claude-haiku-4-5-20251001",
    safetyModel: Deno.env.get("ANTHROPIC_SAFETY_MODEL") ?? "claude-haiku-4-5-20251001",
  });

  if (force === "anthropic") return anthropic();
  if (force === "groq" || force === "openai") return openaiCompat();
  if (compatUrl || groqKey) return openaiCompat();
  return anthropic();
}
const P = resolveProvider();

export function serviceClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
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
      "x-api-key": P.key,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`anthropic ${res.status}: ${await res.text()}`);
  const data = await res.json();
  // A truncated body has no closing brace; treat it as a failed generation (route to retry/fallback).
  if (data?.stop_reason === "max_tokens") throw new Error("anthropic output truncated (max_tokens)");
  return data?.content?.[0]?.text ?? "";
}

// OpenAI-compatible transport (Groq free tier, LM Studio, vLLM, OpenAI, …). JSON mode replaces
// Anthropic's structured outputs; coerceGist + the safety classifier still gate the result.
async function callOpenAICompat(
  system: string,
  user: string,
  model: string,
  maxTokens: number,
  jsonMode: boolean,
): Promise<string> {
  const res = await fetch(`${P.base}/chat/completions`, {
    method: "POST",
    headers: { "content-type": "application/json", ...(P.key ? { authorization: `Bearer ${P.key}` } : {}) },
    body: JSON.stringify({
      model,
      max_tokens: maxTokens,
      temperature: 0.8,
      messages: [{ role: "system", content: system }, { role: "user", content: user }],
      ...(jsonMode ? { response_format: { type: "json_object" } } : {}),
    }),
  });
  if (!res.ok) throw new Error(`${P.provider} ${res.status}: ${await res.text()}`);
  const data = await res.json();
  if (data?.choices?.[0]?.finish_reason === "length") throw new Error("model output truncated (length)");
  return data?.choices?.[0]?.message?.content ?? "";
}

// Route to the configured provider (same signature for both; schema => JSON-constrained output).
function callModel(system: string, user: string, model: string, maxTokens: number, schema?: Record<string, unknown>): Promise<string> {
  return P.provider === "anthropic"
    ? callAnthropic(system, user, model, maxTokens, schema)
    : callOpenAICompat(system, user, model, maxTokens, !!schema);
}

// Defense-in-depth: a cheap second pass over the OUTPUT (docs/GIST.md §15). ok=true ONLY when the
// text is clean, ok=false on any hit, ok=false when uncertain — explicit polarity. Fails closed.
async function safetyCheck(verdict: string, gist: string): Promise<boolean> {
  let out: string;
  try {
    out = await callModel(SAFETY_SYSTEM, `Classify this text.\n\nVERDICT: ${verdict}\n\nGIST: ${gist}`, P.safetyModel, 200, SAFETY_SCHEMA);
  } catch {
    return false; // fail closed
  }
  try {
    const parsed = sliceJSON(out) as { ok?: unknown };
    return parsed.ok === true;
  } catch {
    return false; // fail closed
  }
}

// One generation attempt: call the model, coerce, run BOTH the classifier and the defamation
// post-filter. A thrown error => null/unsafe.
async function attempt(system: string, user: string): Promise<{ out: GistJSON | null; safe: boolean }> {
  let out: GistJSON | null = null;
  try {
    out = coerceGist(sliceJSON(await callModel(system, user, P.genModel, GEN_MAX_TOKENS, GIST_SCHEMA)));
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

  let { data: gist } = await sb.from("gists").select("id, current_version_id").eq("post_id", postId).maybeSingle();
  if (!gist) {
    const ins = await sb.from("gists").insert({ post_id: postId }).select("id, current_version_id").single();
    gist = ins.data;
  }
  if (!gist) return { ok: false, reason: "could not create gist row" };

  // Near-empty public set (e.g. a mostly-private time-fallback graduation): write the warm thin
  // fallback rather than asking the model to invent from nothing (GIST.md §16) — but don't clobber
  // an already-good gist (let the stale-flag cue convey the thinned state instead).
  if (bodies.length < MIN_PUBLIC_FLOOR) {
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
  const promptText = (post as any).prompts?.text ?? "";
  // deno-lint-ignore no-explicit-any
  const ownerName = (post as any).users?.display_name ?? "";
  // The post's chosen spice level (capped at the prompt's tone) is the tone we calibrate to (§7).
  // deno-lint-ignore no-explicit-any
  const tone = (post as any).spice_level ?? "social";

  const userContent = buildUserContent({ promptText, tone, ownerName, bodies, prior, priorCount });
  const baseSystem = SYSTEM + (prior ? ACCRETION : "");

  // First generation + safety (guarded: a throw here must reach the fallback, never escape — §15).
  let { out, safe } = await attempt(baseSystem, userContent);

  // SAFETY RETRY: regenerate ONCE with the reinforced system.
  if (!safe) {
    const retry = await attempt(baseSystem + SAFETY_REINFORCE, userContent);
    if (retry.safe) { out = retry.out; safe = true; }
  }

  // FALLBACK: write the warm generic template rather than publishing a flagged gist or leaving the
  // post gist-less (GIST.md §15).
  let model = P.genModel;
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
