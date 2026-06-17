// Offline unit tests for the gist generator's pure, model-independent logic — the validation,
// clamping, sampling-gate, and defamation backstop added in the 2026-06-17 audit pass. These run
// with no network and no paid API: `deno test supabase/functions/_shared/gist.test.ts`.
//
// (The full generateGistForPost flow needs a Supabase client mock and a stubbed Anthropic fetch;
// these cover the highest-risk new branches without that scaffolding.)
import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { clampVerdict, coerceGist, modelAcceptsTemperature, modelSupportsStructuredOutput, DEFAMATION } from "./gist.ts";

Deno.test("clampVerdict keeps short verdicts verbatim", () => {
  const v = "The human aux cord — always running the vibe.";
  assertEquals(clampVerdict(v), v);
});

Deno.test("clampVerdict truncates long verdicts at a word boundary, <=120 chars", () => {
  const long = "You are the single most chaotically over-committed planner this friend group has ever had the misfortune and joy of trying to schedule around";
  const out = clampVerdict(long);
  assert(out.length <= 120, `expected <=120, got ${out.length}`);
  assert(out.endsWith("…"), "expected an ellipsis");
  assert(!out.includes("  "), "no double spaces");
});

Deno.test("coerceGist rejects missing/empty verdict or gist", () => {
  assertEquals(coerceGist(null), null);
  assertEquals(coerceGist({ gist: "x", excluded_count: 0, tone_flag: "ok" }), null);
  assertEquals(coerceGist({ verdict: "v", gist: "", excluded_count: 0, tone_flag: "ok" }), null);
  assertEquals(coerceGist({ verdict: "   ", gist: "g", excluded_count: 0, tone_flag: "ok" }), null);
});

Deno.test("coerceGist coerces a bad tone_flag to 'thin'", () => {
  const out = coerceGist({ verdict: "v", gist: "g", excluded_count: 0, tone_flag: "spicy" });
  assertEquals(out?.tone_flag, "thin");
});

Deno.test("coerceGist clamps a negative/NaN excluded_count to 0 and floors floats", () => {
  assertEquals(coerceGist({ verdict: "v", gist: "g", excluded_count: -3, tone_flag: "ok" })?.excluded_count, 0);
  assertEquals(coerceGist({ verdict: "v", gist: "g", excluded_count: "nope", tone_flag: "ok" })?.excluded_count, 0);
  assertEquals(coerceGist({ verdict: "v", gist: "g", excluded_count: 2.9, tone_flag: "ok" })?.excluded_count, 2);
});

Deno.test("coerceGist passes a valid object through (and trims)", () => {
  const out = coerceGist({ verdict: "  V  ", gist: " G ", excluded_count: 1, tone_flag: "hostile" });
  assertEquals(out, { verdict: "V", gist: "G", excluded_count: 1, tone_flag: "hostile" });
});

Deno.test("modelAcceptsTemperature: sonnet/haiku/opus-4-6 yes; opus-4-7/4-8 + fable no", () => {
  assert(modelAcceptsTemperature("claude-sonnet-4-6"));
  assert(modelAcceptsTemperature("claude-haiku-4-5-20251001"));
  assert(modelAcceptsTemperature("claude-opus-4-6"));
  assert(!modelAcceptsTemperature("claude-opus-4-7"));
  assert(!modelAcceptsTemperature("claude-opus-4-8"));
  assert(!modelAcceptsTemperature("claude-fable-5"));
});

Deno.test("modelSupportsStructuredOutput: sonnet/haiku/opus-4-8 yes; opus-4-6/4-7 no", () => {
  assert(modelSupportsStructuredOutput("claude-sonnet-4-6"));
  assert(modelSupportsStructuredOutput("claude-haiku-4-5-20251001"));
  assert(modelSupportsStructuredOutput("claude-opus-4-8"));
  assert(modelSupportsStructuredOutput("claude-fable-5"));
  assert(!modelSupportsStructuredOutput("claude-opus-4-6"));
  assert(!modelSupportsStructuredOutput("claude-opus-4-7"));
});

Deno.test("DEFAMATION flags strong accusation nouns but not innocent roast verbs", () => {
  assert(DEFAMATION.test("He's a total cheater and a liar"));
  assert(DEFAMATION.test("certified thief of everyone's chargers"));
  assert(!DEFAMATION.test("stole the show at karaoke again"));
  assert(!DEFAMATION.test("cheated at Monopoly and has no shame"));
  assert(!DEFAMATION.test("the human aux cord who never lets a silence exist"));
});
