/**
 * K122 (D265): run saved model replies through the rest of the server's chain and print what the user gets.
 *
 * Bank cases (replies in a directory, named by stem <case>.t<turn>.c<call>.txt|.json):
 *   deno run --allow-read --allow-write --allow-env scripts/k122-replay.ts --case F01,E02 [--replies DIR] [--out DIR]
 *   deno run --allow-read --allow-write --allow-env scripts/k122-replay.ts --all
 * One request of your own (replies in call order):
 *   deno run --allow-read --allow-write --allow-env scripts/k122-replay.ts --endpoint answer
 *        --body '{"fragment":"hur högt är Kebnekaise","mode":"push_to_talk","language":"sv","context":{}}'
 *        --reply svar.txt [--reply check.txt]      (or: --reply-text "Kebnekaise är 2097 meter högt.")
 *        [--header "x-earmind-lang: en"]
 *
 * A reply is the model's raw text (with the JSON meta line where the prompt asks for one), or JSON:
 *   {"text": "..."}  {"error": {"status": 402, "message": "credit balance too low"}}  {"events": [raw stream events]}
 * Printed per turn: what is said (after the spoken format, crisis marker, source line, caps), the meta/done fields,
 * the error code, the cost records and credit calls. The full result: <out>/<case>.json. A case that reaches a call
 * without a reply stops there and writes that prompt to reports/qa/k122-prompts/<stem>.json.
 * No --allow-net: nothing can reach Anthropic or ElevenLabs.
 */
import { parseArgs } from "jsr:@std/cli@1.0.9/parse-args";
import { type CaseResult, dirLookup, loadCases, parseReply, type Reply, repoPath, runCase } from "./k122-lib.ts";

const a = parseArgs(Deno.args, {
  string: ["case", "replies", "out", "endpoint", "body", "reply", "reply-text", "header"],
  boolean: ["all", "json"],
  collect: ["reply", "reply-text", "header"],
});
const out = a.out ?? repoPath("reports/qa/k122-out");
const promptsDir = repoPath("reports/qa/k122-prompts");
await Deno.mkdir(out, { recursive: true });
await Deno.mkdir(promptsDir, { recursive: true });

function show(r: CaseResult) {
  console.log(`\n=== ${r.id}: ${r.status}${r.needs ? ` (waits for ${r.needs})` : ""}${r.reason ? ` – ${r.reason}` : ""}`);
  for (const t of r.turns) {
    console.log(`-- turn ${t.turn} (${t.endpoint}) HTTP ${t.http_status}`);
    if (t.said !== undefined) console.log(`   said: ${t.said || "(nothing)"}`);
    if (t.done) {
      const { usage: _u, ...d } = t.done;
      console.log(`   done: ${JSON.stringify(d)}`);
    }
    if (t.json !== undefined) console.log(`   json: ${JSON.stringify(t.json).slice(0, 1500)}`);
    if (t.error) console.log(`   error: ${JSON.stringify(t.error)}`);
    for (const u of t.usage) {
      console.log(`   usage: ${u.endpoint ?? ""} ${u.model} in=${u.input_tokens} out=${u.output_tokens} $${Number(u.est_cost_usd ?? 0).toFixed(5)} ${u.status ?? ""}`);
    }
    for (const c of t.credits) console.log(`   credits: ${c.fn}(${c.n ?? 0})`);
  }
  if (r.needs) console.log(`   next prompt: reports/qa/k122-prompts/${r.needs}.json`);
  if (r.blocked.length) console.log(`   refused network calls: ${r.blocked.join(", ")}`);
}

async function finish(r: CaseResult) {
  for (const p of r.prompts) await Deno.writeTextFile(`${promptsDir}/${p.stem}.json`, JSON.stringify(p, null, 2) + "\n");
  await Deno.writeTextFile(`${out}/${r.id}.json`, JSON.stringify(r, null, 2) + "\n");
  if (a.json) console.log(JSON.stringify(r));
  else show(r);
}

if (a.endpoint) {
  const replies: Reply[] = [
    ...(a.reply as string[]).map((f) => parseReply(Deno.readTextFileSync(f), f)),
    ...(a["reply-text"] as string[]).map((t) => ({ text: t })),
  ];
  const headers = Object.fromEntries((a.header as string[]).map((h) => [h.split(":")[0].trim(), h.split(":").slice(1).join(":").trim()]));
  const raw = a.body ?? "";
  const body = JSON.parse(raw.trim().startsWith("{") ? raw : Deno.readTextFileSync(raw));
  const r = await runCase({ id: "adhoc", endpoint: a.endpoint, body, headers }, (stem) => replies[Number(/\.c(\d+)$/.exec(stem)![1]) - 1] ?? null);
  await finish(r);
} else {
  const ids = a.case ? new Set(a.case.split(",")) : null;
  if (!ids && !a.all) {
    console.error("give --case F01[,..], --all, or --endpoint with --body and --reply");
    Deno.exit(2);
  }
  const lookup = dirLookup(a.replies ?? repoPath("reports/qa/k122-replies"));
  const cases = (await loadCases()).filter((c) => !ids || ids.has(c.id));
  if (ids && cases.length !== ids.size) console.error(`unknown case: ${[...ids].filter((i) => !cases.some((c) => c.id === i)).join(", ")}`);
  for (const c of cases) await finish(await runCase(c, lookup));
}
