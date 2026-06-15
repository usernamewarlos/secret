// publish-daily-prompt — cron (docs/PRODUCT.md §6.3). Assigns today's date to the next
// undated deck prompt, making it the single global prompt for the day. Idempotent per day.
import { serviceClient, json } from "../_shared/gist.ts";

Deno.serve(async () => {
  const sb = serviceClient();
  const today = new Date().toISOString().slice(0, 10);

  const { data: existing } = await sb.from("prompts").select("id").eq("publish_date", today).maybeSingle();
  if (existing) return json({ ok: true, already_published: true, prompt_id: existing.id, date: today });

  const { data: next } = await sb
    .from("prompts").select("id, text")
    .is("publish_date", null)
    .order("created_at", { ascending: true })
    .limit(1).maybeSingle();
  if (!next) return json({ ok: false, error: "prompt deck is empty" }, 500);

  const { error } = await sb.from("prompts").update({ publish_date: today }).eq("id", next.id);
  if (error) return json({ ok: false, error: error.message }, 500);

  return json({ ok: true, prompt_id: next.id, text: next.text, date: today });
});
