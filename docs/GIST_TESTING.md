# Testing the gist for free (no Anthropic credits)

The gist generator (`supabase/functions/_shared/gist.ts`) runs in **placeholder mode** until a
real key is configured. To preview what the gist *actually compiles* from a set of answers —
without spending any API credits — use the local preview tool. It runs the **exact production
prompt** (both share `gist_prompt.ts`), so you're testing what production ships, just with a free
model swapped in for Claude.

> A small/free model won't match Claude's polish — this is a **quality + behaviour preview**, not
> production output. Use it to iterate the prompt deck, the gist prompt, and the bright-line safety
> layer on real and adversarial answer sets.

## Quick start (local, fully free, nothing leaves your Mac)

```sh
brew install ollama
ollama pull llama3.1          # or llama3.2:3b for a faster/smaller test

deno run --allow-net --allow-env --allow-read \
  supabase/functions/_shared/gist_preview.ts \
  --prompt "How are they socially?" --tone social --owner Jordan \
  --answers "talks nonstop;always 20 min late;the planner;cancels then shows up most invested;loud and loyal"
```

It prints the verdict, the gist body, `tone_flag`/`excluded_count`, the deterministic defamation
backstop result, and the second-pass safety classifier verdict — the full production pipeline.

Flags: `--prompt` (required) · `--tone wholesome|playful|social|spicy` · `--owner <name>` ·
`--answers "a;b;c"` or `--answers-file <path>` (one per line) · `--no-safety`.

## Backends (auto-detected)

| Backend | Setup | Notes |
|---|---|---|
| **Ollama** (default) | `OLLAMA_MODEL` (default `llama3.1`), `OLLAMA_URL` | Fully local, $0, no data leaves your machine. Best for real reply text. |
| **Groq** (free key, no card) | `export GROQ_API_KEY=gsk_...`, `GROQ_MODEL` (default `llama-3.3-70b-versatile`) | Free tier, stronger than a small local model, **contractually no training/retention** — safe for real text. Try `openai/gpt-oss-120b` or a Llama-4 model for best quality. |
| **Any OpenAI-compatible** | `OPENAI_COMPAT_URL`, `OPENAI_COMPAT_KEY`, `OPENAI_COMPAT_MODEL` | LM Studio, llama.cpp server, vLLM, paid OpenAI, etc. |

> ⚠️ **Do not** point this at **Gemini-free** or **OpenRouter-free** with real reply text — both
> train on / retain inputs, which breaks the app's privacy promise on sensitive named-person
> content. Use Ollama (local) or Groq (no-training) for real answers; synthetic text only otherwise.

## Where the gist's AI is going (2026-06 research)

The gist's laundered-specific-funny synthesis is **irreducibly an LLM task** — templates produce the
exact "horoscope filler" the spec forbids. But the cost is **sub-cent per gist** (~$144 to serve
10,000 users their full living gist on Haiku 4.5). Recommended path:

- **Now:** harden the prompt + safety layer with this free local preview.
- **Launch:** deploy the existing Anthropic Haiku path (best quality + the only one that clears the
  legal bright-line bar; commercial tier doesn't train on your data), **or**, if $0 is absolute,
  wire production to **Groq's free tier** (`gpt-oss-120b` / Llama-4, Zero Data Retention on) — the
  only free *cloud* tier that's both privacy-safe and good enough — with a one-line upgrade to Claude
  later.
- Keep the deterministic DEFAMATION regex + safety classifier + fallback regardless of engine — no
  provider gives you *your* bright lines.
