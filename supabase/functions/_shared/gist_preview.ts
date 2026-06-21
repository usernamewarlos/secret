#!/usr/bin/env -S deno run --allow-net --allow-env --allow-read
// gist_preview.ts — preview a Grapevine gist for FREE, with no Anthropic credits.
//
// It runs the EXACT production gist prompt (imported from gist_prompt.ts, the same module the
// deployed generator uses) through a FREE model, so you're testing what production actually ships
// — just with a free engine swapped in for Claude. Use it to iterate the deck, the prompt, and the
// bright-line safety layer on real + adversarial answer sets. (A small free model won't match
// Claude's polish; this is a quality/behaviour preview, not production output.)
//
// ── Backends (auto-detected) ─────────────────────────────────────────────────
//   default  Ollama (fully local, $0, nothing leaves your Mac):
//              brew install ollama && ollama pull llama3.1      # then it just works
//              override: OLLAMA_URL (default http://localhost:11434), OLLAMA_MODEL (default llama3.1)
//   Groq     a free key (no credit card), good quality, no-training/no-retention terms:
//              export GROQ_API_KEY=gsk_...                       # uses GROQ_MODEL or llama-3.3-70b-versatile
//   Any OpenAI-compatible endpoint (LM Studio, llama.cpp server, vLLM, paid OpenAI, …):
//              export OPENAI_COMPAT_URL=... OPENAI_COMPAT_KEY=... OPENAI_COMPAT_MODEL=...
//   ⚠️  Do NOT use Gemini-free or OpenRouter-free with REAL reply text — they train on / retain it.
//       For real answers use Ollama (local) or Groq (no-training). Synthetic text only otherwise.
//
// ── Usage ────────────────────────────────────────────────────────────────────
//   deno run --allow-net --allow-env --allow-read \
//     supabase/functions/_shared/gist_preview.ts \
//     --prompt "How are they socially?" --tone social --owner Jordan \
//     --answers "talks nonstop;always 20 min late;the planner;cancels then shows up most invested;loud and loyal"
//
//   # one answer per line in a file instead of --answers:
//   deno run ... gist_preview.ts --prompt "..." --tone social --answers-file answers.txt
//
//   flags: --prompt (required) --tone wholesome|playful|social|spicy (default social)
//          --owner <name>  --answers "a;b;c"  --answers-file <path>  --no-safety

import { parseArgs } from "https://deno.land/std@0.224.0/cli/parse_args.ts";
import {
  SYSTEM,
  SAFETY_SYSTEM,
  DEFAMATION,
  coerceGist,
  sliceJSON,
  buildUserContent,
  type GistJSON,
} from "./gist_prompt.ts";

interface Backend { name: string; call(system: string, user: string): Promise<string>; }

function resolveBackend(): Backend {
  const groqKey = Deno.env.get("GROQ_API_KEY");
  const compatUrl = Deno.env.get("OPENAI_COMPAT_URL");
  if (compatUrl) {
    const model = Deno.env.get("OPENAI_COMPAT_MODEL") ?? "local-model";
    return { name: `openai-compatible (${model} @ ${compatUrl})`, call: (s, u) => callOpenAI(compatUrl, Deno.env.get("OPENAI_COMPAT_KEY") ?? "", model, s, u) };
  }
  if (groqKey) {
    const model = Deno.env.get("GROQ_MODEL") ?? "llama-3.3-70b-versatile";
    return { name: `groq (${model})`, call: (s, u) => callOpenAI("https://api.groq.com/openai/v1", groqKey, model, s, u) };
  }
  const base = Deno.env.get("OLLAMA_URL") ?? "http://localhost:11434";
  const model = Deno.env.get("OLLAMA_MODEL") ?? "llama3.1";
  return { name: `ollama (${model} @ ${base})`, call: (s, u) => callOllama(base, model, s, u) };
}

async function callOpenAI(base: string, key: string, model: string, system: string, user: string): Promise<string> {
  const res = await fetch(`${base.replace(/\/$/, "")}/chat/completions`, {
    method: "POST",
    headers: { "content-type": "application/json", ...(key ? { authorization: `Bearer ${key}` } : {}) },
    body: JSON.stringify({
      model,
      temperature: 0.8,
      messages: [{ role: "system", content: system }, { role: "user", content: user }],
      response_format: { type: "json_object" },
    }),
  });
  if (!res.ok) throw new Error(`${res.status}: ${await res.text()}`);
  const d = await res.json();
  return d?.choices?.[0]?.message?.content ?? "";
}

async function callOllama(base: string, model: string, system: string, user: string): Promise<string> {
  const res = await fetch(`${base.replace(/\/$/, "")}/api/chat`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      model,
      stream: false,
      format: "json",
      options: { temperature: 0.8 },
      messages: [{ role: "system", content: system }, { role: "user", content: user }],
    }),
  });
  if (!res.ok) {
    if (res.status === 404) throw new Error(`Ollama model "${model}" not found — run: ollama pull ${model}`);
    throw new Error(`${res.status}: ${await res.text()}`);
  }
  const d = await res.json();
  return d?.message?.content ?? "";
}

function readAnswers(args: Record<string, unknown>): string[] {
  if (typeof args["answers-file"] === "string") {
    return Deno.readTextFileSync(args["answers-file"] as string).split("\n").map((s) => s.trim()).filter(Boolean);
  }
  if (typeof args.answers === "string") {
    return (args.answers as string).split(";").map((s) => s.trim()).filter(Boolean);
  }
  return [];
}

function printGist(g: GistJSON) {
  console.log("\n┌─ VERDICT " + "─".repeat(58));
  console.log("  " + g.verdict + `   (${g.verdict.length} chars)`);
  console.log("├─ GIST " + "─".repeat(61));
  for (const para of g.gist.split("\n")) console.log("  " + para);
  console.log("├─ META " + "─".repeat(61));
  console.log(`  tone_flag: ${g.tone_flag}   excluded_count: ${g.excluded_count}`);
  console.log("└" + "─".repeat(68));
}

async function main() {
  const args = parseArgs(Deno.args, {
    string: ["prompt", "tone", "owner", "answers", "answers-file"],
    boolean: ["no-safety", "help"],
    default: { tone: "social" },
  });

  if (args.help || !args.prompt) {
    console.log("Preview a gist for free. Required: --prompt. See the header of this file for full usage.");
    console.log('Example: --prompt "How are they socially?" --tone social --owner Jordan --answers "a;b;c;d;e"');
    Deno.exit(args.prompt ? 0 : 1);
  }

  const bodies = readAnswers(args);
  if (bodies.length === 0) {
    console.error("No answers given. Pass --answers \"a;b;c\" or --answers-file <path>.");
    Deno.exit(1);
  }

  const backend = resolveBackend();
  const user = buildUserContent({ promptText: args.prompt!, tone: args.tone!, ownerName: args.owner ?? "", bodies });

  console.log(`\nbackend: ${backend.name}`);
  console.log(`prompt:  ${args.prompt}  [tone: ${args.tone}]`);
  console.log(`answers: ${bodies.length}`);

  let raw: string;
  try {
    raw = await backend.call(SYSTEM, user);
  } catch (e) {
    console.error(`\n✗ generation failed: ${e instanceof Error ? e.message : e}`);
    if (backend.name.startsWith("ollama")) console.error("  (is Ollama running? `ollama serve`, and `ollama pull <model>`)");
    Deno.exit(1);
  }

  const gist = coerceGist((() => { try { return sliceJSON(raw); } catch { return null; } })());
  if (!gist) {
    console.error("\n✗ model did not return a valid gist JSON. Raw output:\n" + raw.slice(0, 800));
    Deno.exit(1);
  }
  printGist(gist);

  // Deterministic defamation backstop (the same one production applies).
  const defamation = DEFAMATION.test(`${gist.verdict}\n${gist.gist}`);
  console.log(`\ndefamation regex backstop: ${defamation ? "⚠️  HIT — production would force the safe fallback" : "clean"}`);

  // Second-pass safety classifier (same SAFETY_SYSTEM production uses), via the same free backend.
  if (!args["no-safety"]) {
    try {
      const sraw = await backend.call(SAFETY_SYSTEM, `Classify this text.\n\nVERDICT: ${gist.verdict}\n\nGIST: ${gist.gist}`);
      const parsed = sliceJSON(sraw) as { ok?: unknown; why?: unknown };
      const ok = parsed.ok === true;
      console.log(`safety classifier: ${ok ? "PASS (ok=true)" : "FAIL (ok=false)"}${parsed.why ? ` — ${parsed.why}` : ""}`);
      if (!ok) console.log("  → production would retry once, then fall back to the safe template.");
    } catch (e) {
      console.log(`safety classifier: (skipped — ${e instanceof Error ? e.message : e})`);
    }
  }
  console.log("");
}

if (import.meta.main) await main();
