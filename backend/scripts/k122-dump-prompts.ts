/**
 * K122 (D265): write exactly what the server would send to the model, case by case, without any network.
 *
 *   deno run --allow-read --allow-write --allow-env scripts/k122-dump-prompts.ts [--only F01,E02] [--cat fakta]
 *        [--replies ../reports/qa/k122-replies] [--out ../reports/qa/k122-prompts]
 *
 * (No --allow-net: Deno refuses every connection, so nothing can reach Anthropic or ElevenLabs.)
 * Cases: scripts/qa/cases.json (the /answer bank) + backend/scripts/k122-cases.json (Provläge eval and judge,
 * exam drill/hint/grade/compress, help). Every model call a case reaches is written as <out>/<case>.t<turn>.c<call>.json
 * (anthropic_request = the Messages API body, client_request = what the app sent). Without replies each case stops
 * at its first call; with replies in --replies (same stem, .txt or .json) it goes on, so the next prompt (turn 2,
 * the crisis check, ...) is written too. <out>/index.json lists every case's status and the stem it waits for.
 */
import { parseArgs } from "jsr:@std/cli@1.0.9/parse-args";
import { dirLookup, loadCases, repoPath, runCase } from "./k122-lib.ts";

const a = parseArgs(Deno.args, { string: ["only", "cat", "replies", "out"] });
const out = a.out ?? repoPath("reports/qa/k122-prompts");
const replies = a.replies ?? repoPath("reports/qa/k122-replies");
const only = a.only ? new Set(a.only.split(",")) : null;
const cases = (await loadCases()).filter((c) => (!only || only.has(c.id)) && (!a.cat || c.cat === a.cat));
await Deno.mkdir(out, { recursive: true });
const index: Record<string, unknown>[] = [];
let n = 0;
for (const c of cases) {
  const r = await runCase(c, dirLookup(replies));
  for (const p of r.prompts) {
    await Deno.writeTextFile(`${out}/${p.stem}.json`, JSON.stringify(p, null, 2) + "\n");
    n++;
  }
  index.push({
    id: c.id, cat: c.cat ?? null, endpoint: c.endpoint ?? "answer", status: r.status, needs: r.needs ?? null,
    reason: r.reason ?? null, prompts: r.prompts.map((p) => p.stem), blocked: r.blocked,
    // turns that ended without a model call (e.g. calculations the server answers itself): what the user hears
    said: r.turns.map((t) => t.said ?? null),
  });
}
await Deno.writeTextFile(`${out}/index.json`, JSON.stringify(index, null, 2) + "\n");
const by = (s: string) => index.filter((x) => x.status === s).length;
console.log(`K122 dump: ${cases.length} cases, ${n} prompts -> ${out}`);
console.log(`  waiting for a reply: ${by("needs_reply")}, done: ${by("done")}, refused: ${by("refused")}`);
