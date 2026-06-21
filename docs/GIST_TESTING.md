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

## Deploy production for $0 (Groq free tier)

The gist Edge Function (`gist.ts`) is **provider-flexible** — it picks its engine from whichever
secret is set, so switching is a secret change, not a code change:

| Set this Edge-Function secret | Engine |
|---|---|
| `GROQ_API_KEY` (+ optional `GROQ_MODEL`, `GROQ_SAFETY_MODEL`) | **Groq free tier — the $0 path** |
| `OPENAI_COMPAT_URL` / `_KEY` / `_MODEL` | any OpenAI-compatible endpoint |
| `ANTHROPIC_API_KEY` (+ optional `ANTHROPIC_MODEL`) | Anthropic (paid upgrade lane) |

`GIST_PROVIDER=anthropic|groq|openai` forces the choice if more than one is set.

### One-time setup (you do these — they need your key + live DB access)

```sh
# 1. Free Groq key (no credit card): https://console.groq.com → API Keys → Create.
#    In Groq settings, turn ON Zero Data Retention (so your users' replies are never retained).

# 2. Point the gist at Groq (Edge Function secrets):
supabase secrets set GROQ_API_KEY=gsk_xxx \
  GROQ_MODEL=llama-3.3-70b-versatile          # or openai/gpt-oss-120b for best quality

# 3. Apply the audit migration (adds revoke re-spin, profile_feed stale/tone, deck, etc.):
supabase db push                               # or run supabase/migrations/0014_*.sql in the SQL editor

# 4. Deploy the functions:
supabase functions deploy generate-gist regenerate-gists

# 5. Let graduation auto-fire the gist (SQL editor — service_role is a secret, you set it):
#    alter database postgres set app.functions_base_url = 'https://<project-ref>.functions.supabase.co';
#    alter database postgres set app.service_role_key  = '<service_role_key>';

# 6. (optional) schedule the batched regen cron — uncomment the regenerate-gists job in
#    supabase/migrations/0008_cron.sql, or schedule it from the SQL editor.
```

After that, a post graduating (organically, or via the Settings → dev tools) fires a **real Groq
gist**. Pin `GROQ_MODEL` to a current model — Groq deprecates model ids periodically. To upgrade to
Claude later: `supabase secrets set ANTHROPIC_API_KEY=...` and `GIST_PROVIDER=anthropic` (or unset
`GROQ_API_KEY`). No code change.

> Note: the dev "Generate responses" button *fabricates* a canned gist (it predates the real path);
> to exercise the real Groq generator in-app, let a post graduate from real replies.
