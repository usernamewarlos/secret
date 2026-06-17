// regenerate-gists — cron worker for ALL graduated posts (docs/GIST.md §5, §14).
//   * First generation: a graduated post with no gist version yet.
//   * Accretion regen: public replies grew by >= N OR >= 25% since the last version,
//     capped to at most once per post per ~24h (revoke-driven regens bypass this via the
//     direct /generate-gist enqueue in revoke_connection — migration 0014).
// Never per-reply. Run on the same daily cadence as publish-daily-prompt. This is the
// reliable path even without the optional instant-generation trigger (migration 0003).
import { serviceClient, generateGistForPost, json } from "../_shared/gist.ts";

const GROWTH_ABS = 5;     // +N new replies (recommended N = 5)
const GROWTH_PCT = 0.25;  // or >= 25% growth
const REGEN_MIN_INTERVAL_MS = 24 * 60 * 60 * 1000; // §14 per-post 24h cap for growth-driven regens

Deno.serve(async () => {
  const sb = serviceClient();

  const { data: posts } = await sb.from("posts").select("id").eq("status", "graduated");

  const firstGenerated: string[] = [];
  const regenerated: string[] = [];

  for (const post of posts ?? []) {
    // current public reply count
    const { count } = await sb
      .from("replies")
      .select("id", { count: "exact", head: true })
      .eq("post_id", post.id)
      .eq("is_private", false);
    const current = count ?? 0;

    // gist state: last reply_count_at_generation + when it was generated (or -1 if no version yet)
    const { data: gist } = await sb
      .from("gists").select("current_version_id")
      .eq("post_id", post.id).maybeSingle();

    let last = -1;
    let lastAt = 0;
    if (gist?.current_version_id) {
      const { data: v } = await sb
        .from("gist_versions").select("reply_count_at_generation, created_at")
        .eq("id", gist.current_version_id).single();
      last = v?.reply_count_at_generation ?? 0;
      lastAt = v?.created_at ? Date.parse(v.created_at) : 0;
    }

    if (last < 0) {
      try { await generateGistForPost(sb, post.id); firstGenerated.push(post.id); } catch (_) { /* logged upstream */ }
      continue;
    }

    // Per-post 24h cap: don't regenerate a post whose current gist is younger than the interval.
    // Makes the §14 cap an invariant of the code, not just an emergent property of cron frequency.
    const capOk = lastAt === 0 || Date.now() - lastAt >= REGEN_MIN_INTERVAL_MS;
    if (!capOk) continue;

    const grew = current - last;
    if (grew >= GROWTH_ABS || (last > 0 && grew / last >= GROWTH_PCT)) {
      try { await generateGistForPost(sb, post.id); regenerated.push(post.id); } catch (_) { /* logged upstream */ }
    }
  }

  return json({
    ok: true,
    first_generated: firstGenerated.length,
    regenerated: regenerated.length,
    post_ids: { first: firstGenerated, regen: regenerated },
  });
});
