// generate-gist — invoked when a post graduates (docs/GIST.md §4, §12, §15).
// Body: { "post_id": "<uuid>" }. Generates the first gist (or regenerates by accretion).
import { serviceClient, generateGistForPost, json } from "../_shared/gist.ts";

Deno.serve(async (req) => {
  let postId: string | undefined;
  try {
    ({ post_id: postId } = await req.json());
  } catch {
    return json({ ok: false, error: "expected JSON body { post_id }" }, 400);
  }
  if (!postId) return json({ ok: false, error: "post_id required" }, 400);

  try {
    const result = await generateGistForPost(serviceClient(), postId);
    return json(result, result.ok ? 200 : 422);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});
