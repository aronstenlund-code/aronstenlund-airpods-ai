// Runs the 30 Swedish short prompts (testdata/scripts/sv-short-prompts.md) against /answer and
// prints time-to-first-token (first SSE `delta`), time-to-meta and totals, plus answer-style checks.
//
//   deno task ttft -- --url https://<ref>.supabase.co/functions/v1/answer --mode push_to_talk
//   token:  LUMEN_TOKEN=<jwt>    or    SUPABASE_URL + SUPABASE_ANON_KEY (anonymous sign-in is done for you)
//   local:  deno task dev  then  deno task ttft -- --url http://127.0.0.1:8787/functions/v1/answer --token dev-token
import { parseArgs } from "jsr:@std/cli@1.0.9/parse-args";

const args = parseArgs(Deno.args, {
  string: ["url", "token", "mode", "out", "prompts", "language"],
  default: {
    mode: "push_to_talk",
    language: "sv",
    prompts: new URL("../../testdata/scripts/sv-short-prompts.md", import.meta.url).pathname,
  },
});
if (!args.url) {
  console.error("--url is required");
  Deno.exit(2);
}

async function getToken(): Promise<string> {
  if (args.token) return args.token;
  const t = Deno.env.get("LUMEN_TOKEN");
  if (t) return t;
  const base = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!base || !anon) {
    throw new Error("Set LUMEN_TOKEN, or SUPABASE_URL + SUPABASE_ANON_KEY, or pass --token");
  }
  const r = await fetch(`${base}/auth/v1/signup`, {
    method: "POST",
    headers: { apikey: anon, "content-type": "application/json" },
    body: "{}",
  });
  if (!r.ok) throw new Error(`anonymous sign-in failed: ${r.status} ${await r.text()}`);
  return (await r.json()).access_token;
}

function loadPrompts(path: string): { n: number; text: string }[] {
  const out: { n: number; text: string }[] = [];
  for (const line of Deno.readTextFileSync(path).split("\n")) {
    const m = /^\|\s*(\d+)\s*\|[^|]*\|[^|]*\|\s*([^|]+?)\s*\|\s*$/.exec(line);
    if (m) out.push({ n: Number(m[1]), text: m[2] });
  }
  return out;
}

const pct = (xs: number[], p: number) => {
  if (!xs.length) return NaN;
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.ceil((p / 100) * s.length) - 1)];
};

interface Row {
  n: number;
  prompt: string;
  status: number;
  headers_ms: number;
  meta_ms: number | null;
  ttft_ms: number | null;
  total_ms: number;
  server: Record<string, unknown> | null;
  question: string | null;
  confidence: number | null;
  answer: string;
  issues: string[];
  error?: string;
}

async function runOne(token: string, n: number, prompt: string): Promise<Row> {
  for (let attempt = 0; attempt < 4; attempt++) {
    const t0 = performance.now();
    const res = await fetch(args.url!, {
      method: "POST",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
        ...(Deno.env.get("SUPABASE_ANON_KEY")
          ? { apikey: Deno.env.get("SUPABASE_ANON_KEY")! }
          : {}),
      },
      body: JSON.stringify({
        fragment: prompt,
        mode: args.mode,
        language: args.language,
        context: { transcript: "", recent_qa: [], prep_terms: [] },
      }),
    });
    const headers_ms = performance.now() - t0;
    if (res.status === 429) {
      const wait = Number(res.headers.get("retry-after") ?? "10");
      console.error(`  429, waiting ${wait}s`);
      await res.body?.cancel();
      await new Promise((r) => setTimeout(r, (wait + 1) * 1000));
      continue;
    }
    const row: Row = {
      n,
      prompt,
      status: res.status,
      headers_ms,
      meta_ms: null,
      ttft_ms: null,
      total_ms: 0,
      server: null,
      question: null,
      confidence: null,
      answer: "",
      issues: [],
    };
    if (!res.ok || !res.body) {
      row.error = await res.text();
      row.total_ms = performance.now() - t0;
      return row;
    }
    const reader = res.body.pipeThrough(new TextDecoderStream()).getReader();
    let buf = "";
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += value;
      let i;
      while ((i = buf.indexOf("\n\n")) !== -1) {
        const frame = buf.slice(0, i);
        buf = buf.slice(i + 2);
        const ev = /^event: (.*)$/m.exec(frame)?.[1];
        const data = JSON.parse(/^data: (.*)$/m.exec(frame)?.[1] ?? "null");
        const now = performance.now() - t0;
        if (ev === "meta") {
          row.meta_ms = now;
          row.question = data.reconstructed_question;
          row.confidence = data.confidence;
          if (!data.is_question) row.issues.push("is_question=false");
        } else if (ev === "delta") {
          if (row.ttft_ms === null) row.ttft_ms = now;
          row.answer += data.text;
        } else if (ev === "done") row.server = data;
        else if (ev === "error") row.issues.push(`error:${data.code}`);
      }
    }
    row.total_ms = performance.now() - t0;
    const sentences = row.answer.split(/(?<=[.!?])\s+/).filter(Boolean).length;
    if (sentences > 2) row.issues.push(`${sentences} sentences`);
    if (/\d/.test(row.answer)) row.issues.push("digits in answer (TTS)");
    if (/[*#_`()\[\]]/.test(row.answer)) row.issues.push("symbols in answer");
    if (!row.answer) row.issues.push("empty answer");
    return row;
  }
  return {
    n,
    prompt,
    status: 429,
    headers_ms: 0,
    meta_ms: null,
    ttft_ms: null,
    total_ms: 0,
    server: null,
    question: null,
    confidence: null,
    answer: "",
    issues: ["rate_limited"],
  };
}

const token = await getToken();
const prompts = loadPrompts(args.prompts!);
console.log(
  `url=${args.url} mode=${args.mode} language=${args.language} prompts=${prompts.length}\n`,
);
const rows: Row[] = [];
for (const p of prompts) {
  const r = await runOne(token, p.n, p.text);
  rows.push(r);
  const f = (x: number | null) => (x === null ? "   -  " : x.toFixed(0).padStart(6));
  console.log(
    `${String(p.n).padStart(2)} meta${f(r.meta_ms)} ttft${f(r.ttft_ms)} total${
      f(r.total_ms)
    } ms | ${p.text} -> ${r.answer || r.error || "(none)"}${
      r.issues.length ? "  !! " + r.issues.join(", ") : ""
    }`,
  );
}
const ok = rows.filter((r) => r.status === 200 && r.ttft_ms !== null);
const ttft = ok.map((r) => r.ttft_ms!),
  meta = ok.filter((r) => r.meta_ms !== null).map((r) => r.meta_ms!),
  tot = ok.map((r) => r.total_ms);
const summary = {
  url: args.url,
  mode: args.mode,
  n: rows.length,
  ok: ok.length,
  with_issues: rows.filter((r) => r.issues.length).length,
  ttft_ms: { p50: pct(ttft, 50), p90: pct(ttft, 90), max: Math.max(...ttft) },
  meta_ms: { p50: pct(meta, 50), p90: pct(meta, 90) },
  total_ms: { p50: pct(tot, 50), p90: pct(tot, 90) },
  tokens: {
    input_avg: avg(
      rows.map((r) => (r.server?.usage as { input_tokens?: number } | undefined)?.input_tokens),
    ),
    output_avg: avg(
      rows.map((r) => (r.server?.usage as { output_tokens?: number } | undefined)?.output_tokens),
    ),
  },
};
function avg(xs: (number | undefined | null)[]): number | null {
  const v = xs.filter((x): x is number => typeof x === "number");
  return v.length ? Math.round(v.reduce((a, b) => a + b, 0) / v.length) : null;
}
console.log("\n" + JSON.stringify(summary, null, 2));
if (args.out) {
  Deno.mkdirSync(args.out.replace(/\/[^/]*$/, "") || ".", { recursive: true });
  Deno.writeTextFileSync(args.out, JSON.stringify({ summary, rows }, null, 2));
  console.log(`saved ${args.out}`);
}
