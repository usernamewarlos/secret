// regenerate-gists — cron (docs/GIST.md §5, §14). Batched accretion: for each graduated
// post, regenerate when it has grown by >= N new replies OR >= 25% since the last version.
// Never per-reply. Run on the same daily cadence as publish-daily-prompt.
import { serviceClient, generateGistForPost, json } from "../_shared/gist.ts";

const GROWTH_ABS = 5;     // +N new replies (recommended N = 5)
const GROWTH_PCT = 0.25;  // or >= 25% growth

Deno.serve(async () => {
  const sb = serviceClient();

  // Graduated posts that already have a gist (first generation is done by generate-gist).
  const { data: gists } = await sb
    .from("gists")
    .select("post_id, current_version_id, posts!inner(status)")
    .eq("posts.status", "graduated");

  const processed: string[] = [];
  for (const g of gists ?? []) {
    // current public reply count
    const { count } = await sb
      .from("replies")
      .select("id", { count: "exact", head: true })
      .eq("post_id", g.post_id)
      .eq("is_private", false);
    const current = count ?? 0;

    let last = 0;
    if (g.current_version_id) {
      const { data: v } = await sb
        .from("gist_versions").select("reply_count_at_generation")
        .eq("id", g.current_version_id).single();
      last = v?.reply_count_at_generation ?? 0;
    }

    const grew = current - last;
    if (grew >= GROWTH_ABS || (last > 0 && grew / last >= GROWTH_PCT)) {
      try {
        await generateGistForPost(sb, g.post_id);
        processed.push(g.post_id);
      } catch (_) { /* keep going; log upstream */ }
    }
  }

  return json({ ok: true, regenerated: processed.length, post_ids: processed });
});
