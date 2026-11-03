// TEMPORARY benchmark Edge Function (deployed only while measuring, then deleted).
// Runs the 30 Swedish short prompts against /answer from INSIDE Supabase (the build container cannot
// reach *.supabase.co), as a client would: anonymous sign-in, then sequential SSE calls.
//   GET .../bench?mode=push_to_talk&from=0&n=30     header: x-bench-key: <BENCH_KEY secret>
// Costs real (tiny) LLM credits per call. Never leave it deployed.
const PROMPTS = [
  "roten ur hundra", "fem plus två", "tolv gånger åtta", "hundra delat med fyra", "vad är sju i kvadrat",
  "tjugofem procent av tvåhundra", "vad är pi", "derivatan av x i kvadrat", "fotosyntes", "vad är ljusvågor",
  "vad är en atom", "hur många kromosomer har en människa", "vad är ljudets hastighet", "vad är mitokondrier",
  "newtons andra lag", "vad är ph-värde", "när började andra världskriget", "vem var gustav vasa",
  "när föll berlinmuren", "franska revolutionen", "vem var sveriges första statsminister",
  "när blev sverige medlem i eu", "vad betyder ambivalent", "vad är ett adverb", "hur stavas man restaurang",
  "vad är huvudstaden i australien", "hur många invånare har sverige", "vilket är världens längsta flod",
  "förklara växthuseffekten", "kan någon förklara det igen",
];

const pct = (xs: number[], p: number) => {
  if (!xs.length) return null;
  const s = [...xs].sort((a, b) => a - b);
  return Math.round(s[Math.min(s.length - 1, Math.ceil((p / 100) * s.length) - 1)]);
};

Deno.serve(async (req) => {
  const key = Deno.env.get("BENCH_KEY");
  if (!key || req.headers.get("x-bench-key") !== key) return new Response("forbidden", { status: 403 });
  const u = new URL(req.url);
  const mode = u.searchParams.get("mode") ?? "push_to_talk";
  const from = Number(u.searchParams.get("from") ?? 0);
  const n = Number(u.searchParams.get("n") ?? 30);
  const target = u.searchParams.get("target") ?? "answer";
  const base = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;

  const su = await fetch(`${base}/auth/v1/signup`, {
    method: "POST", headers: { apikey: anon, "content-type": "application/json" }, body: "{}",
  });
  if (!su.ok) return Response.json({ error: "signup", status: su.status, body: await su.text() });
  const token = (await su.json()).access_token as string;

  const rows: Record<string, unknown>[] = [];
  for (const prompt of PROMPTS.slice(from, from + n)) {
    const t0 = performance.now();
    const res = await fetch(`${base}/functions/v1/${target}`, {
      method: "POST",
      headers: { authorization: `Bearer ${token}`, apikey: anon, "content-type": "application/json" },
      body: JSON.stringify({ fragment: prompt, mode, language: "sv", context: { transcript: "", recent_qa: [], prep_terms: [] } }),
    });
    const row: Record<string, unknown> = { prompt, status: res.status, headers_ms: Math.round(performance.now() - t0) };
    if (!res.ok || !res.body) { row.error = await res.text(); rows.push(row); continue; }
    const reader = res.body.pipeThrough(new TextDecoderStream()).getReader();
    let buf = "", answer = "";
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += value;
      let i;
      while ((i = buf.indexOf("\n\n")) !== -1) {
        const frame = buf.slice(0, i); buf = buf.slice(i + 2);
        const ev = /^event: (.*)$/m.exec(frame)?.[1];
        const data = JSON.parse(/^data: (.*)$/m.exec(frame)?.[1] ?? "null");
        const now = Math.round(performance.now() - t0);
        if (ev === "meta") { row.meta_ms = now; row.confidence = data.confidence; row.q = data.reconstructed_question; }
        else if (ev === "delta") { if (row.ttft_ms === undefined) row.ttft_ms = now; answer += data.text; }
        else if (ev === "done") { row.server = data.timing; row.usage = data.usage; row.breakdown = data.breakdown; }
        else if (ev === "error") row.error = data;
      }
    }
    row.total_ms = Math.round(performance.now() - t0);
    row.answer = answer;
    rows.push(row);
  }
  const ok = rows.filter((r) => r.status === 200 && typeof r.ttft_ms === "number");
  const col = (k: string) => ok.map((r) => r[k] as number);
  const srv = ok.map((r) => (r.server as { ttft_ms?: number } | undefined)?.ttft_ms).filter((x): x is number => typeof x === "number");
  const inTok = ok.map((r) => (r.usage as { input_tokens?: number } | undefined)?.input_tokens).filter((x): x is number => typeof x === "number");
  const outTok = ok.map((r) => (r.usage as { output_tokens?: number } | undefined)?.output_tokens).filter((x): x is number => typeof x === "number");
  const avg = (xs: number[]) => xs.length ? Math.round(xs.reduce((a, b) => a + b, 0) / xs.length) : null;
  return Response.json({
    summary: {
      mode, target, n: rows.length, ok: ok.length,
      client_ttft_ms: { first: ok[0]?.ttft_ms, p50: pct(col("ttft_ms"), 50), p90: pct(col("ttft_ms"), 90), min: Math.min(...col("ttft_ms")), max: Math.max(...col("ttft_ms")) },
      client_total_ms: { p50: pct(col("total_ms"), 50), p90: pct(col("total_ms"), 90) },
      server_ttft_ms: { p50: pct(srv, 50), p90: pct(srv, 90) },
      tokens: { in_avg: avg(inTok), out_avg: avg(outTok) },
    },
    rows,
  });
});
