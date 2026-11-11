/**
 * K30 (D116, owner): every question and answer goes to Aron for analysis, then deleted (qa-log function, 14 days at
 * most). Built as a wrapper around the /answer handler: it reads the same SSE stream the app gets (a tee), so every
 * answer path (model, code, commands, Rizz suggestions) is covered without touching the answer code.
 *
 * Only when the app sends `qa_log: true` (it does so once the consent with D116's text, version 5, is accepted).
 * Never: the public demo, crisis answers (B1/B5: crisis is never stored), unanswered or retracted turns.
 * Personnummer, card and account numbers (and any long digit run) are masked before anything is written.
 */

/** Luhn check for a card number candidate (digits only). */
function luhn(d: string): boolean {
  let sum = 0;
  for (let i = 0; i < d.length; i++) {
    let n = Number(d[d.length - 1 - i]);
    if (i % 2 === 1) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
  }
  return sum % 10 === 0;
}

export function maskNumbers(text: string): string {
  return (text ?? "")
    // IBAN (Swedish and others)
    .replace(/(?<![\p{L}\d])[A-Z]{2}\d{2}(?:[ ]?[\dA-Z]{4}){3,7}(?:[ ]?[\dA-Z]{1,3})?(?![\p{L}\d])/gu, "[kontonummer]")
    // personnummer / samordningsnummer: (YY)YYMMDD-NNNN, also without the dash
    .replace(/(?<!\d)(?:19|20)?\d{6}[-+ ]?\d{4}(?!\d)/g, "[personnummer]")
    // card numbers: 13-19 digits with spaces or dashes that pass Luhn
    .replace(/(?<!\d)\d(?:[ -]?\d){12,18}(?!\d)/g, (m) => (luhn(m.replace(/\D/g, "")) ? "[kortnummer]" : m))
    // bank accounts: clearing number + account ("8327-9 123 456 789-0", "1234 567 890 1")
    .replace(/(?<!\d)\d{4}(?:-\d)?[ ,-]+\d(?:[ -]?\d){5,11}(?!\d)/g, "[kontonummer]")
    // anything else with ten or more digits in a row (phone and customer numbers): never needed for analysis
    .replace(/(?<!\d)\d(?:[ -]?\d){9,}(?!\d)/g, "[nummer]");
}

export interface QaRow {
  mode: string | null;
  persona: string | null;
  question: string;
  answer: string;
  /** K42.4: "complaint" when the user complained about the app ("varför upprepar du"). */
  kind?: "complaint";
}

const CRISIS_WORDS = /Självmordslinjen|nittio ett noll ett/u;

/** Reads one SSE stream to the end and returns the answer text, or null when nothing should be logged. */
export async function collectAnswer(stream: ReadableStream<Uint8Array>): Promise<string | null> {
  return (await collectTurn(stream))?.answer ?? null;
}

/** The answer and whether the turn was a complaint (K42.4: done.complaint). */
export async function collectTurn(stream: ReadableStream<Uint8Array>): Promise<{ answer: string; complaint: boolean } | null> {
  let complaint = false;
  const reader = stream.pipeThrough(new TextDecoderStream()).getReader();
  let buf = "";
  let text = "";
  let more = "";
  let suggestions: string[] = [];
  let answered = false;
  let crisis = false;
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    buf += value;
    let i: number;
    while ((i = buf.indexOf("\n\n")) >= 0) {
      const frame = buf.slice(0, i);
      buf = buf.slice(i + 2);
      const ev = /^event: (.*)$/m.exec(frame)?.[1];
      const raw = /^data: (.*)$/m.exec(frame)?.[1];
      if (!ev || raw === undefined) continue;
      let data: Record<string, unknown> = {};
      try {
        data = JSON.parse(raw);
      } catch {
        continue;
      }
      if (ev === "delta") text += String(data.text ?? "");
      else if (ev === "more_delta") more += String(data.text ?? "");
      else if (ev === "suggestions" && Array.isArray(data)) suggestions = (data as unknown[]).map(String);
      else if (ev === "meta" && data.safety === "crisis") crisis = true;
      else if (ev === "done") {
        answered = data.answered === true && data.retract !== true;
        if (data.safety === "crisis") crisis = true;
        if (typeof data.more === "string" && !more) more = data.more;
        if (data.complaint === true) complaint = true;
      }
    }
  }
  const answer = (text.trim() || suggestions.join(" / ")).trim();
  if (!answered || crisis || !answer || CRISIS_WORDS.test(answer)) return null;
  return { answer: more.trim() ? `${answer}\n\n[utvecklat] ${more.trim()}` : answer, complaint };
}

export function withQaLog(
  handler: (req: Request) => Promise<Response>,
  log: (row: QaRow) => Promise<void>,
  waitUntil: (p: Promise<unknown>) => void = (p) => void p,
): (req: Request) => Promise<Response> {
  return async (req) => {
    let body: Record<string, unknown> | null = null;
    if (req.method === "POST") {
      try {
        body = await req.clone().json();
      } catch { /* the handler answers 400 itself */ }
    }
    const res = await handler(req);
    const on = body?.qa_log === true && body.source !== "demo" && typeof body.fragment === "string";
    if (!on || !res.body || !(res.headers.get("content-type") ?? "").includes("text/event-stream")) return res;
    const [toApp, toLog] = res.body.tee();
    const q = maskNumbers(String(body!.fragment)).slice(0, 1000);
    waitUntil(collectTurn(toLog).then(async (turn) => {
      if (turn === null || !q.trim()) return;
      const a = turn.answer;
      await log({
        mode: typeof body!.mode === "string" ? String(body!.mode).slice(0, 32) : null,
        persona: typeof body!.persona === "string" ? String(body!.persona).slice(0, 32) : null,
        question: q,
        answer: maskNumbers(a).slice(0, 6000),
        ...(turn.complaint ? { kind: "complaint" as const } : {}),
      });
    }).catch((e) => console.error("qa_log_failed", e instanceof Error ? e.message.slice(0, 120) : String(e))));
    return new Response(toApp, { status: res.status, statusText: res.statusText, headers: res.headers });
  };
}
