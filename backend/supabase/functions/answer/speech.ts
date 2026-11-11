import { claimsMissing, stripYesNoLead } from "./interviewfacts.ts";
import { numbersToSpeech } from "./svnum.ts";
import { afterNumbers, beforeNumbers } from "./speechsym.ts";

/** Digits, symbols, formulas and abbreviations -> speakable Swedish (D46/D54). */
export const toSpeech = (t: string, ctx = ""): string =>
  afterNumbers(numbersToSpeech(beforeNumbers(t, ctx)));

/**
 * D46 post-processing of the streamed answer text, in code instead of more prompt text:
 *  1. DupGuard      - an answer that starts like an earlier answer for a different fragment is stopped
 *                     (the handler regenerates once).
 *  2. QuestionTrim  - a closing question back to the user ("Vill du att jag ...?") is dropped.
 *  3. NumberStream  - digits -> Swedish words, safe across chunk boundaries.
 * Each stage is `push(text) -> text to pass on` / `finish() -> rest`, so latency stays token-level.
 */

const norm = (s: string) => s.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "");

// ---------- 0. summary trailer (D48) ----------
export const SUMMARY_MARK = "[[SAMMANFATTNING]]";

/**
 * The model ends every answer with a line `[[SAMMANFATTNING]] <1-2 sentence summary>` (same call, no extra
 * request). Everything before the marker is spoken; everything after is the summary and never reaches TTS.
 * D65: the marker is recognised in every variant the model produces - `[[SAMMANFATTNING]]`, `[SAMMANFATTNING]`,
 * `SAMMANFATTNING:`, a line `Sammanfattning:` (any case, optional **bold**) - anywhere in the text, also when
 * no summary follows. A partial marker at the end of a chunk is held back so it is never spoken.
 */
const MARKERS: RegExp[] = [
  // K2: also `<<SAMMANFATTNING>>` (the user turn is full of <tags>); before, "<<" was read aloud
  /[[<]{1,2}\s*sammanfattning\s*[\]>]{1,2}\s*:?/i,
  /(?:^|\n)[ \t]*(?:\*\*)?sammanfattning(?:\*\*)?[ \t]*[:\-–—]/i,
  /(?<![[<][ \t]*)SAMMANFATTNING\b[ \t]*:?/,
];

/** First marker in `s`: [index where the spoken text ends, index where the summary starts]. */
export function findSummaryMarker(s: string): [number, number] | null {
  let best: [number, number] | null = null;
  for (const re of MARKERS) {
    const m = re.exec(s);
    if (!m) continue;
    const start = m.index + (m[0].startsWith("\n") ? 1 : 0);
    if (!best || start < best[0]) best = [start, m.index + m[0].length];
  }
  return best;
}

/** Length of the tail of `buf` that may still turn into a marker (held back, not spoken yet). */
function markerHold(buf: string): number {
  let hold = 0;
  const tail = buf.slice(-24);
  for (let br = tail.search(/[[<]/); br !== -1; br = tail.slice(br + 1).search(/[[<]/) === -1 ? -1 : br + 1 + tail.slice(br + 1).search(/[[<]/)) {
    const t = tail.slice(br).toLowerCase().replace(/\s+/g, "").replace(/</g, "[").replace(/>/g, "]");
    if ("[[sammanfattning]]:".startsWith(t) || "[sammanfattning]:".startsWith(t)) {
      hold = tail.length - br;
      break;
    }
  }
  const caps = /[A-ZÅÄÖ]+$/.exec(buf)?.[0] ?? "";
  if (caps && ("SAMMANFATTNING".startsWith(caps) || caps === "SAMMANFATTNING")) {
    hold = Math.max(hold, caps.length);
  }
  const line = buf.slice(buf.lastIndexOf("\n") + 1);
  const l = line.replace(/^[ \t]*(?:\*\*)?/, "").toLowerCase();
  if (l && ("sammanfattning**".startsWith(l) || l === "sammanfattning")) {
    hold = Math.max(hold, line.length);
  }
  if (/^[ \t]*\*{1,2}$/.test(line)) hold = Math.max(hold, line.length);
  return hold;
}

export class SummaryTap {
  private buf = "";
  private sum = "";
  private inSummary = false;

  push(text: string): string {
    if (this.inSummary) {
      this.sum += text;
      return "";
    }
    this.buf += text;
    const f = findSummaryMarker(this.buf);
    if (f) {
      const spoken = this.buf.slice(0, f[0]).replace(/\s+$/, "");
      this.sum = this.buf.slice(f[1]);
      this.buf = "";
      this.inSummary = true;
      return spoken;
    }
    let hold = markerHold(this.buf);
    while (hold < this.buf.length && /\s/.test(this.buf[this.buf.length - hold - 1])) hold++;
    const out = this.buf.slice(0, this.buf.length - hold);
    this.buf = this.buf.slice(this.buf.length - hold);
    return out;
  }

  finish(): string {
    if (this.inSummary) return "";
    const out = this.buf;
    this.buf = "";
    return out;
  }

  /** Cleaned summary (no quotes, one line, <= 300 chars) or null. */
  get summary(): string | null {
    const t = this.sum.replace(/^[\s:\]\-–—*]+/, "").replace(/["“”«»]/g, "").replace(/\s+/g, " ")
      .trim()
      .slice(0, 300);
    return t.length >= 5 ? t : null;
  }
}

// ---------- 0a. relation tag (D53) ----------
export type Relation = "continues" | "refines" | "new_topic";
export const RELATIONS: readonly Relation[] = ["continues", "refines", "new_topic"];
export function parseRelation(v: unknown): Relation | null {
  const t = typeof v === "string" ? v.toLowerCase().replace(/[^a-z_]/g, "").replace(/^ation_?/, "") : "";
  // K7: Sonnet writes "[[RELATION: newtopic]]" as well as "[[REL new_topic]]"
  return RELATIONS.find((r) => r === t || r.replace(/_/g, "") === t) ?? null;
}

/**
 * The model's first line is `[[REL <relation>]]` (decided before the answer). It is split off here and
 * never spoken. If the text does not start with the tag the stream is passed on unchanged.
 */
export class RelationTap {
  relation: Relation | null = null;
  private buf = "";
  private strip = false; // drop the whitespace between the tag and the answer, across chunks
  private decided: boolean;
  constructor(private readonly enabled: boolean) {
    // K7 (Sonnet): the model can write the tag even when none was asked for ("[[RELATION: newtopic]]" was read
    // aloud): a leading tag is always split off; its value is used only when it was asked for
    this.decided = false;
  }
  push(text: string): string {
    if (this.decided) {
      if (!this.strip) return text;
      const r = text.replace(/^\s+/, "");
      if (r) this.strip = false;
      return r;
    }
    this.buf += text;
    const t = this.buf.trimStart();
    const open = "[[REL";
    if (t.length < open.length) {
      if (open.startsWith(t.toUpperCase())) return ""; // could still become the tag
      return this.release();
    }
    if (!t.toUpperCase().startsWith(open)) return this.release();
    const end = t.indexOf("]]");
    if (end === -1) return t.length > 40 ? this.release() : "";
    if (this.enabled) this.relation = parseRelation(t.slice(open.length, end));
    this.decided = true;
    this.strip = true;
    this.buf = "";
    const r = t.slice(end + 2).replace(/^\s+/, "");
    if (r) this.strip = false;
    return r;
  }
  finish(): string {
    return this.decided ? "" : this.release();
  }
  private release(): string {
    this.decided = true;
    const b = this.buf;
    this.buf = "";
    return b;
  }
}

// ---------- 0a2. web answers: source line + English sentences (D65) ----------
/** Spoken name of a domain: "scb.se" -> "SCB", "riksdagen.se" -> "Riksdagen", "developer.mozilla.org" -> "Mozilla". */
export function spokenSource(domain: string): string {
  const labels = domain.toLowerCase().replace(/^www\./, "").split(".").filter(Boolean);
  const sld = new Set(["co", "com", "org", "gov", "ac"]);
  let i = labels.length - 2;
  if (
    labels.length >= 3 && labels[labels.length - 1].length === 2 &&
    sld.has(labels[labels.length - 2])
  ) i--;
  const name = labels[Math.max(0, i)] ?? domain;
  return name.length <= 4 ? name.toUpperCase() : name[0].toUpperCase() + name.slice(1);
}

/**
 * Web answers end with `källa: <domain>`. That line is never read out as written ("scb punkt se"): it is cut
 * from the stream, exposed as `source` (for the screen) and spoken as "Källa: SCB.".
 */
export class SourceTap {
  source: string | null = null;
  private buf = "";
  private inSource = false;
  private src = "";
  constructor(private readonly enabled: boolean) {}
  private static readonly RE = /(?:^|\n|\s)källa\s*:/i;

  push(text: string): string {
    if (!this.enabled) return text;
    if (this.inSource) {
      this.src += text;
      return "";
    }
    this.buf += text;
    const m = SourceTap.RE.exec(this.buf);
    if (m) {
      const at = m.index + (/^\s/.test(m[0]) ? 1 : 0);
      const spoken = this.buf.slice(0, at).replace(/\s+$/, "");
      this.src = this.buf.slice(m.index + m[0].length);
      this.buf = "";
      this.inSource = true;
      return spoken;
    }
    // hold back a tail that may still become "källa:"
    const tail = this.buf.slice(-8).toLowerCase();
    let hold = 0;
    for (let k = Math.min(6, tail.length); k > 0; k--) {
      if ("källa:".startsWith(tail.slice(-k))) {
        hold = k;
        break;
      }
    }
    while (hold < this.buf.length && /\s/.test(this.buf[this.buf.length - hold - 1])) hold++;
    const out = this.buf.slice(0, this.buf.length - hold);
    this.buf = this.buf.slice(this.buf.length - hold);
    return out;
  }

  finish(): string {
    if (!this.enabled) return "";
    if (!this.inSource) {
      const out = this.buf;
      this.buf = "";
      return out;
    }
    const d = /([a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.[a-z]{2,})/i.exec(this.src)?.[1] ?? null;
    this.source = d ? d.toLowerCase().replace(/^www\./, "") : null;
    this.inSource = false;
    return this.source ? ` Källa: ${spokenSource(this.source)}.` : "";
  }
}

const EN = new Set(
  "the of and is are was were he she it they to in since as with for by that this has have had been who which serves served from at on be an or his her their its not but also king queen ruler rulers reigned ruled succeeded succeeding became born died during until years sources source don doesn didn give gives given year founding founded information available about any find found provide provides mention mentions results search there no exact date need needs should ask asks user users so would will can cannot me you your my what how however friend number name call calls open play request"
    .split(" "),
);
const SV = new Set(
  "och att är som det en ett på av för med har till den i inte var de hon han vi du man om vid från efter under över sedan blev blir kan ska sig sin sitt dess"
    .split(" "),
);
/** True for a sentence that is clearly English (web answers must be Swedish; a copied source sentence is dropped). */
export function isEnglishSentence(sentence: string): boolean {
  const w = sentence.toLowerCase().match(/\p{L}+/gu) ?? [];
  if (w.length < 5) return false;
  let en = 0, sv = 0;
  for (const x of w) {
    if (EN.has(x)) en++;
    else if (SV.has(x)) sv++;
  }
  if (en >= 3 && en > 1.5 * sv) return true;
  // Oscar round 2 / D72 live test: an English source fragment inside a Swedish sentence
  // ("Ordningen stämmer också med Succeeding rulers were his son ..."): 3+ English and no Swedish
  // function words within 5 consecutive words.
  for (let i = 0; i + 5 <= w.length; i++) {
    const win = w.slice(i, i + 5);
    if (win.filter((x) => EN.has(x)).length >= 3 && !win.some((x) => SV.has(x))) return true;
  }
  return false;
}

/**
 * Oscar round 2 (F16): in web mode the model sometimes narrates its own decision ("Det här är en historisk
 * fråga som jag kan svara på direkt, utan sökning.", "Jag söker på ..."). Such a sentence is system talk.
 */
const SEARCH_META =
  /(?:utan (?:att )?(?:beh\u00f6va |ha )?s\u00f6k|jag har inte s\u00f6kt|om du vill vara (?:helt )?s\u00e4ker|^\s*hmm\b|jag \u00e4r s\u00e4ker p\u00e5 (?:detta|det h\u00e4r|det)\b|(?:beh\u00f6ver|beh\u00f6vs) (?:inte |ingen )?s\u00f6k|ingen s\u00f6kning|jag kan svara (?:p\u00e5 )?(?:den |det |fr\u00e5gan )?direkt|^\s*(?:jag|l\u00e5t mig) (?:ska |kan |vill |m\u00e5ste |beh\u00f6ver )?(?:s\u00f6ka|s\u00f6ker|kolla|kollar|letar|leta)\b|^\s*det h\u00e4r \u00e4r en \p{L}+ fr\u00e5ga)/iu;
export function isSearchMeta(sentence: string): boolean {
  return SEARCH_META.test(sentence);
}

/** Drops whole English sentences (web mode only, unless the user asked for a translation), and sentences
 *  that only narrate the search decision. */
export class EnglishGate {
  private buf = "";
  constructor(private readonly enabled: boolean) {}
  push(text: string): string {
    if (!this.enabled) return text;
    this.buf += text;
    let out = "";
    for (;;) {
      const m = /[.!?](?:\s+|$)|\n/.exec(this.buf);
      if (!m || m.index + m[0].length >= this.buf.length && !/\s$/.test(m[0]) && m[0] !== "\n") {
        break;
      }
      const end = m.index + m[0].length;
      const sentence = this.buf.slice(0, end);
      this.buf = this.buf.slice(end);
      if (!isEnglishSentence(sentence) && !isSearchMeta(sentence)) out += sentence;
    }
    return out;
  }
  finish(): string {
    if (!this.enabled) return "";
    const r = isEnglishSentence(this.buf) || isSearchMeta(this.buf) ? "" : this.buf;
    this.buf = "";
    return r;
  }
}

// ---------- 0a. D75: silence in Provläge / Auto ----------
/** The model's "say nothing" marker (prompt.ts SILENT_MARK); everything after it is dropped. */
const SILENT_OPEN = "[[TYST";
export class SilenceTap {
  silent = false;
  /** History fix 2026-11-08: the marker came AFTER spoken text ("… nöjd med det. [[TYST]]"). */
  late = false;
  private buf = "";
  private decided: boolean;
  private spoke = false;
  private closing = false;
  constructor(private readonly enabled: boolean) {
    this.decided = !enabled;
  }
  push(text: string): string {
    if (this.silent || this.late) return "";
    if (this.decided) return this.scan(text);
    this.buf += text;
    const t = this.buf.trimStart().toUpperCase();
    if (t.length < SILENT_OPEN.length) {
      return SILENT_OPEN.startsWith(t) ? "" : this.release();
    }
    if (t.startsWith(SILENT_OPEN)) {
      this.silent = true;
      this.buf = "";
      return "";
    }
    return this.release();
  }
  finish(): string {
    if (this.silent || this.late) return "";
    if (!this.decided) {
      // a reply that is only "[[T" or "[[" is not an answer either
      if (this.buf.trim() && SILENT_OPEN.startsWith(this.buf.trim().toUpperCase())) {
        this.silent = this.enabled;
        this.buf = "";
        return "";
      }
      return this.release();
    }
    // a held-back "[" that never became the marker is ordinary text; a lone "[[T…" tail is dropped
    const b = this.buf;
    this.buf = "";
    return /\[\[[A-ZÅÄÖ]*$/i.test(b) && SILENT_OPEN.startsWith(b.slice(b.lastIndexOf("[[")).toUpperCase())
      ? b.slice(0, b.lastIndexOf("[["))
      : b;
  }
  /** The marker is never passed on, wherever it is (all modes). */
  private scan(text: string): string {
    this.buf += text;
    const u = this.buf.toUpperCase();
    const at = u.indexOf(SILENT_OPEN);
    if (at >= 0) {
      const before = this.buf.slice(0, at);
      const after = this.buf.slice(at + SILENT_OPEN.length);
      this.buf = "";
      if (this.spoke || before.trim()) {
        this.late = true;
        return before;
      }
      this.silent = this.enabled;
      if (this.silent) return "";
      // a mode without silence: the marker is dropped and the rest is said
      this.closing = true;
      return this.scan(after);
    }
    if (this.closing) {
      const m = /^[\]\s]*/.exec(this.buf)!;
      if (m[0].length === this.buf.length) {
        this.buf = "";
        return "";
      }
      this.buf = this.buf.slice(m[0].length);
      this.closing = false;
    }
    // hold back a tail that may still become the marker ("[", "[[", "[[TY")
    const lb = this.buf.lastIndexOf("[");
    if (lb >= 0) {
      const tail = u.slice(lb);
      const tail2 = lb > 0 && this.buf[lb - 1] === "[" ? u.slice(lb - 1) : tail;
      if (SILENT_OPEN.startsWith(tail2) || SILENT_OPEN.startsWith(tail)) {
        const cut = SILENT_OPEN.startsWith(tail2) ? lb - (tail2 === tail ? 0 : 1) : lb;
        const out = this.buf.slice(0, cut);
        this.buf = this.buf.slice(cut);
        if (out.trim()) this.spoke = true;
        return out;
      }
    }
    const out = this.buf;
    this.buf = "";
    if (out.trim()) this.spoke = true;
    return out;
  }
  private release(): string {
    this.decided = true;
    const b = this.buf;
    this.buf = "";
    return this.scan(b);
  }
}

/**
 * D75 (first device run): the model commented on what the student seemed to think ("Det låter som att du
 * tänker på …") or asked for clarification ("Berätta gärna ordet …") instead of answering. Such a
 * sentence is never spoken in Provläge or Auto; when nothing else remains the reply is silence.
 */
const META_REPLY = new RegExp(
  [
    String.raw`^(?:det|detta|det här) (?:låter|verkar|känns|tycks) (?:som )?(?:att|om) (?:du|ni)\b`,
    String.raw`^(?:det|detta|det här) (?:låter|verkar) som (?:en|ett) (?:ofullständig|avbruten|avbrutet|ofullständigt|halv)`,
    String.raw`^(?:du|ni) (?:verkar|låter|tycks|kanske) (?:tänka|mena|syfta|undra|vilja|fundera|prata)`,
    String.raw`^(?:jag )?(?:förstår|uppfattade|uppfattar|hörde|fattar|kunde inte (?:höra|uppfatta|förstå)) (?:tyvärr )?(?:inte|riktigt|helt)?`,
    String.raw`^jag (?:är )?(?:inte (?:helt )?säker på|osäker på) vad (?:du|ni)`,
    String.raw`^jag (?:kunde|kan) inte (?:höra|uppfatta|tolka|förstå)`,
    String.raw`^berätta (?:gärna|lite|mer|vad (?:du|ni) (?:menar|vill|tänker|syftar))`,
    String.raw`^(?:kan|kunde|vill) (?:du|ni) (?:förtydliga|upprepa|utveckla|precisera|säga (?:det )?igen|säga (?:lite )?mer|berätta (?:lite )?mer|ge (?:mig )?(?:mer|lite) )`,
    String.raw`^(?:vad|vilket|vilken|vem) (?:menar|syftar|tänker) (?:du|ni)`,
    String.raw`^menar (?:du|ni)\b`,
    String.raw`^tänker (?:du|ni) på\b`,
    String.raw`^syftar (?:du|ni) på\b`,
    String.raw`^om (?:du|ni) (?:menar|syftar|tänker) (?:på )?`,
    String.raw`^(?:säg|ge|nämn) (?:gärna |mig )+(?:ordet|vilket|vad|mer)`,
    String.raw`^hörde jag rätt`,
    // D82: comments on the fragment or the sound ("Det här är bara en rest av ljud från tidigare …")
    String.raw`^(?:det|detta|det här|det där)(?: fragmentet)? (?:är|var|verkar vara|låter som) (?:bara |nog |troligen )?(?:en |ett )?(?:rest av (?:ljud|mitt|det jag|ett tidigare|det tidigare|svaret)|restljud|brus|bakgrundsljud|eko|ljud från|upprepning|del av (?:mitt|ett) (?:svar|tidigare)|(?:ett )?(?:stopp|avbrotts)\w*)`,
    String.raw`^(?:jag )?(?:ser|hör|hittar) (?:ingen|inte någon|inte någon ny) (?:ny )?(?:fråga|begäran)`,
    String.raw`^(?:det|här) (?:finns|går inte att (?:se|höra|hitta)) (?:ingen|inte någon|någon) (?:ny )?(?:fråga|begäran)`,
    String.raw`^om (?:du|ni) vill (?:fortsätta|gå vidare|ställa en (?:ny )?fråga|fråga något)`,
    String.raw`^jag gissar (?:att|på att) (?:du|ni)`,
    String.raw`^(?:det|det där|det här) (?:är|var) (?:lite )?(?:svårt|oklart) att (?:förstå|veta|tolka|höra|säga)`,
  ].join("|"),
  "iu",
);
/** D80: naming the interpretation ("Det där låter som 'Pythagoras sats'."): case-sensitive on the term. */
const NAMED_READING = /^[Dd]e(?:t|t där|tta|t här) (?:låter|verkar) som ["'„”»«]?\p{Lu}/u;
export function isMetaReply(sentence: string): boolean {
  const s = sentence.trim().replace(/^[\s"'„”»«-]+/, "");
  return META_REPLY.test(s) || NAMED_READING.test(s);
}

/**
 * D77 (Oscar's D72 run + live eval): with no personal facts given, the interview answer said so out loud
 * ("Jag har inte någon konkret upplevelse att utgå från, så jag svarar med …", "… i den här övningen").
 * The user reads the answer aloud in the interview, so that part is removed: when the sentence goes on with
 * ", men …" / ", så …" and the rest is a real answer, only the rest is kept; otherwise the sentence is dropped.
 */
const INTERVIEW_META = new RegExp(
  [
    String.raw`\b(?:jag har|jag inte har|det finns|det inte finns) (?:inte |ingen |inga )?(?:någon |något |en |ett |några )?(?:konkret|egen|specifik|faktisk|verklig)\w* (?:\w+ )?(?:upplevelse|händelse|situation|erfarenhet|exempel|uppgift|uppgifter|information)`,
    String.raw`\bjag (?:har (?:inte|inga)|inte har) (?:några )?uppgifter om\b`,
    String.raw`\b(?:så )?(?:jag|då) svarar (?:jag )?(?:med|utifrån|genom) (?:hur|vad|det|att)\b`,
    String.raw`\bsvarar jag (?:med|utifrån|genom) (?:hur|vad|det|att)\b`,
    String.raw`\b(?:så )?jag börjar med (?:vem|vad|att berätta)\b`,
    String.raw`\b(?:i|under|för) (?:den här|denna|detta|det här) (?:konversationen|övningen|sessionen|samtalet|scenariot)\b`,
    String.raw`\b(?:eftersom|då) (?:jag inte vet|det inte framgår|inget (?:är|finns) (?:angivet|givet))`,
    String.raw`\bjag kan inte (?:säga|uppge|berätta|nämna) (?:min|mitt|mina|vad jag heter|hur gammal)`,
    String.raw`\bjag heter (?:inte|och)\b`,
    // Oscar 2026-11-08: "Jag har inget namn angivet …", "Jag vill hellre prata om … än om mina år",
    // "Jag är inte så noga med siffror", "Hur gammal jag är spelar inte lika stor roll …"
    String.raw`\b(?:jag har|det finns) (?:inget|inte något|ingen) (?:namn|ålder|skola|uppgift)\w* (?:angiv|givet|nämnt|här)`,
    String.raw`\bjag vill (?:hellre|hellst) prata om\b[^.]{0,80} än om (?:min|mitt|mina)\b`,
    String.raw`\bjag är inte (?:så )?noga med (?:siffror|åldrar|år|datum)\b`,
    String.raw`\b(?:jag tänker|jag vill|jag kommer) inte (?:att )?(?:fokusera|prata|lägga fokus|gå in) på (?:min|mitt|mina)\b`,
    String.raw`\b(?:hur gammal jag är|min ålder|vad jag heter|vilken skola jag går på) (?:spelar|är) (?:inte|mindre)\b`,
    String.raw`\b(?:inte )?(?:nämnt|angett|angivet|givet|framgår) (?:här|i (?:annonsen|uppgifterna))\b`,
    // D79: coaching the user instead of answering ("Däremot kan du svara att du …")
    String.raw`\b(?:du kan|kan du|du bör|bör du|du ska|du skulle kunna) (?:svara|säga|berätta|nämna|lyfta|börja|ta upp|förklara)\b`,
    String.raw`\bjag kan inte (?:säga|veta|uppge) (?:vilken|vilket|vad|hur|om)\b`,
    // D79: stand-ins for a missing fact ("Jag är ganska ny på arbetsmarknaden, men …", "Jag heter det du vill veta")
    String.raw`\bjag är (?:ganska |väldigt |rätt )?(?:ung|ny på arbetsmarknaden)\b`,
    String.raw`\bjag är inte säker på (?:att det|hur mycket|om det|hur gammal|min ålder)`,
    String.raw`\bjag heter det\b`,
  ].join("|"),
  "iu",
);
export function isInterviewMeta(sentence: string): boolean {
  return INTERVIEW_META.test(sentence);
}

/** D77: the interview sentence without its meta part ("" when nothing worth saying is left). */
export function stripInterviewMeta(sentence: string): string {
  // "Jag heter och är sexton år" (an empty name): keep the fact
  const s = sentence.replace(/\bjag heter och (?=är |går |bor |tränar |har )/iu, "Jag ");
  const m = INTERVIEW_META.exec(s);
  if (!m) return s;
  const after = s.slice(m.index + m[0].length);
  const c = /(?:,?\s+(?:men|så)|,\s*och)\s+([\s\S]+)$/u.exec(after);
  if (c) {
    const rest = c[1];
    if (rest.trim().split(/\s+/).length >= 4 && !INTERVIEW_META.test(rest)) {
      return rest.charAt(0).toUpperCase() + rest.slice(1);
    }
  }
  return "";
}

/**
 * History fix 2026-11-08: metasvar slipped through in Provläge although D75/D80 ("Men jag kan inte se vad din
 * mikrofon uppfattar …", "Det här är inte en fråga jag kan svara på som något specifikt ämne …", "… så jag
 * föreslår att du säger vilket ämne …"). A sentence about the fragment, the sound, the microphone or the
 * recording, or one that asks the user to clarify, is never spoken, in every mode without a persona.
 */
const INPUT_META = new RegExp(
  [
    String.raw`\b(?:din|er|telefonens|appens) mikrofon`,
    String.raw`\bvad (?:mikrofonen|appen|jag) (?:uppfattar|hör|hörde|har hört)\b`,
    String.raw`\bjag kan inte (?:se|höra) vad (?:du|ni|mikrofonen)`,
    String.raw`\b(?:det här|det|detta|ditt) fragment(?:et)?\b`,
    String.raw`\bi fragmentet\b`,
    String.raw`\b(?:rest|rester) av (?:ljud|det jag sa|mitt (?:svar|förra))`,
    String.raw`\b(?:ljudet|inspelningen|transkriptionen|transkriberingen) (?:är|var|verkar|innehåller)`,
    String.raw`^(?:men |så )?(?:det här|detta|det) är inte en (?:ny |riktig )?fråga\b`,
    String.raw`\b(?:jag ser|det finns|här finns) (?:ingen|inte någon) (?:ny |riktig )?fråga\b`,
    String.raw`\bjag väntar på (?:nästa|din|en ny) fråga\b`,
    String.raw`\b(?:föreslår att du säger|säg vilket ämne|berätta vilket ämne|vilket ämne (?:det|provet) gäller)`,
    String.raw`\b(?:kan|kunde) (?:du|ni) (?:förtydliga|upprepa|säga det igen|formulera om)`,
    String.raw`\bså (?:jag svarar på|svarar jag på) det jag hör\b`,
    // D82: "… och jag tolkar det som att du vill …", "Det här är en fortsättning på …"
    String.raw`\bjag tolkar det (?:som|så)\b`,
    String.raw`^(?:det här|detta|det) är en fortsättning på\b`,
    String.raw`\bfragmentet (?:blandar|är|var|verkar|innehåller|säger|låter|består)\b`,
    String.raw`\bjag är (?:inte (?:helt )?säker på|osäker på) vad (?:du|ni) menar\b`,
    String.raw`\bså jag svarar inte\b`,
    String.raw`\b(?:eftersom )?(?:ingen|det finns ingen) tidigare (?:tur|fråga|samtal)`,
    String.raw`\b(?:är det|det är) svårt att (?:avgöra|veta|säga) (?:vad|vilket)`,
    String.raw`^det verkar vara en fråga om\b`,
    // K7.7 (Oscar O6, noisy input): "Jag hör inget nytt att svara på, så jag håller mig tyst.", "Det här är bara ett
    // skärmljud.", "Säg gärna en fråga …", "Det verkar vara tre olika saker, så jag tar …"
    String.raw`\bjag (?:hör|uppfattar|hittar) (?:inget|ingenting|inte något|ingen)\b`,
    // K7 run (Lisa/Tom): "Frågan kan tolkas på två sätt, men det naturliga är att …"
    String.raw`^(?:frågan|uppgiften|det) kan (?:tolkas|läsas|förstås) (?:på|som)(?![\p{L}])`,
    String.raw`\b(?:jag )?håller (?:mig|jag mig) tyst\b|\bjag (?:är|förblir) tyst\b|\bså jag säger (?:inget|ingenting)\b`,
    String.raw`\b(?:bara|endast|nog|troligen|antagligen) (?:ett |en )?(?:skärmljud|ljud|brus|bakgrundsljud|bakgrundsprat|prat i bakgrunden|ljudeffekt|ljudklipp|reklam)\b`,
    String.raw`\bsäg gärna (?:en |ett |vad |vilket |din |ditt )`,
    String.raw`\bdet (?:verkar|låter|ser ut att) (?:vara|som) (?:två|tre|fyra|flera|några) (?:olika )?(?:saker|ämnen|frågor|delar|meningar)\b`,
  ].join("|"),
  "iu",
);
export function isInputMeta(sentence: string): boolean {
  return INPUT_META.test(sentence);
}

/**
 * K1.2 (Oscar D84, 2026-11-08): Provläge spoke its reasoning about the heard word ("Syntes är nog fotosyntes, som är
 * det mest närliggande biologiska begreppet i din lista.", "Syntes är inte ett kemiord, så jag tar det som att du
 * menar …", "… ligger nära, så jag tar nära ämnesord: …"). Read by meaning, not by one phrase: a sentence is
 * reasoning when it (a) points at the student's input or the app's material (the list, the profile, "ämnesord",
 * "närliggande", "låter likt"), or (b) classifies a word as belonging or not belonging to a subject ("inte ett
 * kemiord"), or (c) states an interpretation ("jag tar det som", "X är nog Y", "du menar") about the heard word.
 * Such a sentence is never spoken; the rest of the answer is.
 */
const REASON_REF = new RegExp(
  [
    String.raw`\b(?:i |på |från )?(?:din|dina|er|era) (?:lista|listan|ordlista|ordlistan|termer|termlista|begrepp|ord|profil|ämnesord|provord)\b`,
    String.raw`\bi (?:listan|ordlistan|termlistan|profilen|provlistan)\b`,
    String.raw`(?<!\p{L})(?:nära |närliggande )?ämnesord(?:en)?\b`,
    String.raw`\bdet (?:mest )?närliggande\b`,
    String.raw`\blåter (?:likt|liknande|nästan som)\b`,
    String.raw`\b(?:inte|inget|ett|är ett|är inget) (?:\p{L}+-)?(?:kemi|biologi|bio|fysik|matte|matematik|historie|historia|samhälls|geografi|religions|svensk|engelsk|ämnes|fack|skol)ord\b`,
  ].join("|"),
  "iu",
);
const REASON_ACT = new RegExp(
  [
    String.raw`\b(?:jag tar|tar jag|så jag tar) (?:det|ordet|nära|de)\b`,
    String.raw`\bjag (?:tolkar|gissar|antar|väljer|utgår från|läser det)\b`,
    String.raw`\b(?:tolkar|gissar|antar) jag\b`,
    String.raw`\b(?:du|ni) (?:menar|mena|syftar)\b`,
    String.raw`\b(?:menar|syftar) (?:du|ni)\b`,
  ].join("|"),
  "iu",
);
/** "Syntes är nog fotosyntes …": the heard word named, then an interpretation verb. */
const REASON_GUESS = /^["'„”»«]?([\p{L}-]{2,40})["'„”»«]? (?:är|betyder) (?:nog|troligen|förmodligen|antagligen|sannolikt|kanske) /iu;
/** K2: the same reasoning in English ("The fragment sounds like 'present perfect', …", Oscar's D87 review). */
const REASON_EN =
  /^(?:the|this|your) (?:fragment|word|phrase|term|input|question)s? (?:sounds|seems|looks) like|^(?:it|that|this) (?:sounds|seems) like (?:you|the)|^you (?:probably |likely |most likely )?(?:mean|meant)(?![\p{L}])|^i (?:take|read|interpret) (?:it|this|that) as/iu;

export function isReasoningMeta(sentence: string, heard: string): boolean {
  const t = sentence.trim();
  if (!t) return false;
  if (REASON_EN.test(t)) return true;
  if (REASON_REF.test(t)) return true;
  if (REASON_ACT.test(t)) return true;
  const g = REASON_GUESS.exec(t);
  if (g && heard && heard.toLowerCase().split(/\s+/).some((w) => similarity(w, g[1]) >= 0.6)) return true;
  return false;
}

/**
 * K7.1 (Oscar O1 finding A): Provläge said the level aloud when the question lay above the grade ("det här är Åk
 * åtta, så på den nivån förklarar jag bara idén", "Det är svårt att förklara en derivata på grundskolenivå, men här
 * är idén.", "I Åk nio tänker man på det som …"). Read by meaning in every sentence: a sentence that names the
 * grade or a school level, the curriculum, or what the answer chooses to explain, is about the answer, not the
 * subject. When the part after a colon is the real answer it is kept ("… på grundskolenivå: X är …" -> "X är …").
 */
const LEVEL_GRADE =
  /(?<![\p{L}])(?:åk|årskurs|årskursen)\s*(?:[0-9]|sex|sju|åtta|nio)|(?<![\p{L}])(?:grundskole|gymnasie|högstadie|mellanstadie|universitets|högskole)nivå|\bkursplan(?:en)?\b|\bläroplan(?:en)?\b|\bcentrala innehållet\b|\bkunskapskrav(?:en)?\b/iu;
const LEVEL_SELF =
  /\b(?:på|för) (?:den|din|er|rätt|denna|en enkel|en enklare|grundläggande) nivå(?:n)?(?![\p{L}])|(?:förklarar|tar|visar|beskriver|håller) jag (?:bara |det |den |enkelt |här )*(?:idén|grunden|det enkelt|enkelt)\b|\bjag (?:förklarar|tar|visar|håller) (?:bara |det |den )*(?:idén|grunden|det enkelt|enkelt)\b|\bhär är (?:den |själva )?(?:enkla |grundläggande |övergripande )?idén\b|\b(?:inte|inget) (?:något )?(?:du|ni|man|eleven) (?:behöver|ska) (?:kunna|räkna|lära)|\bhör (?:till|hemma i) (?:gymnasiet|gymnasiets|högstadiet|grundskolan|universitetet|högskolan)\b|\b(?:ingår|finns) (?:inte )?i (?:gymnasiets|grundskolans|högstadiets) (?:matte|matematik|kurs|kurser)\b|\b(?:i|på) (?:gymnasiet|grundskolan|högstadiet) (?:lär|läser|räknar|tänker|möter) (?:man|du|ni)\b|\bså jag förklarar\b/iu;
export function isLevelMeta(sentence: string): boolean {
  const t = sentence.trim();
  return !!t && (LEVEL_GRADE.test(t) || LEVEL_SELF.test(t));
}
export function rewriteLevelMeta(sentence: string): string {
  if (!isLevelMeta(sentence)) {
    // K7.6 (Aron's phone test 21:22): never what is "enough" on the exam: "På provet räcker det att skriva …" ->
    // "På provet kan du skriva …"
    return sentence.replace(/^(\s*på provet,?\s+)(?:så\s+)?räcker det (?:med )?att (?:du\s+)?(\p{L}+a)\b/iu, "$1kan du $2");
  }
  const i = sentence.lastIndexOf(":");
  if (i > 0) {
    const rest = sentence.slice(i + 1).trim();
    if (rest.split(/\s+/).length >= 3 && !isLevelMeta(rest)) {
      return rest.charAt(0).toUpperCase() + rest.slice(1) + (/\s$/.test(sentence) ? " " : "");
    }
  }
  return "";
}

/**
 * K7.2 (Oscar O1 finding C): after a dropped sentence the next one must not start with a stump that pointed at it
 * ("Där lärde jag mig …", "A syntes är …"). A stray single capital letter before a lower-case word is removed; a
 * sentence that opens with a word pointing back at the dropped one is dropped as well.
 */
// K11 (Oscar O5): "Det är just den noggrannheten jag vill ta med mig …" pointed at the dropped claim
const STUMP_BACKREF = /^\s*(?:där|därför|dessutom|alltså|också|då|sedan|därefter|annars|ändå|det vill säga|med andra ord|(?:det|detta|det här) är (?:just|precis|också|därför)|just (?:den|det|de|därför|så)|(?:den|det|de) (?:här|där)|(?:denna|detta|dessa|samma)|(?:den|det|de) [\p{L}]+(?:heten|erfarenheten|vanan|kunskapen)(?:na)? (?:jag|är|har|vill|tar|gör))(?![\p{L}-])/iu;
/**
 * K11 (live 2/5): an interview answer about a fact the CV lacks OPENED with a back-reference to nothing
 * ("Det är precis den noggrannheten jag vill ta med mig …", "Det har lärt mig att …"): the first sentence of an
 * interview answer is held to the same test, plus "det har lärt/gett mig".
 */
const OPENING_BACKREF = /^\s*(?:det|den|detta|det där) (?:har|gav|ger) (?:lärt|gett|givit|format|visat|gjort|fått) mig(?![\p{L}-])/iu;
export function isOpeningStump(sentence: string): boolean {
  return !!sentence.trim() && (STUMP_BACKREF.test(sentence) || OPENING_BACKREF.test(sentence));
}
export function fixStump(sentence: string): string {
  if (!sentence.trim()) return sentence;
  if (STUMP_BACKREF.test(sentence)) return "";
  // an English article left in front of the term ("A syntes är …"); single letters such as "X är sju" are kept
  return sentence.replace(/^(\s*)(?:A|An|The)\s+(\p{Ll})(?=[\p{L}-]*\s+(?:är|betyder|kallas|innebär)\b)/u, (_m, ws: string, c: string) => ws + c.toUpperCase());
}

/**
 * Oscar 2026-11-08 (Provläge): the answer to a misheard term opened with its reading ("Fragmentet … låter som
 * gravitationskraften, så jag svarar på det.", "Det låter som kosinussatsen, en sats …", "Det här är fotosyntesen.",
 * "Det är demokrati, ett styrelseskick …"). Only the FIRST sentence is looked at, and only when the named term is
 * close to what was heard (the fragment), so "Det är rätt." after a check question is never touched.
 */
const letters = (t: string) => t.toLowerCase().replace(/[^\p{L}]+/gu, "");
function bigrams(t: string): Map<string, number> {
  const m = new Map<string, number>();
  for (let i = 0; i < t.length - 1; i++) m.set(t.slice(i, i + 2), (m.get(t.slice(i, i + 2)) ?? 0) + 1);
  return m;
}
/** Dice similarity of letter bigrams (0..1). */
export function similarity(a: string, b: string): number {
  const x = bigrams(letters(a)), y = bigrams(letters(b));
  let both = 0, nx = 0, ny = 0;
  for (const v of x.values()) nx += v;
  for (const v of y.values()) ny += v;
  for (const [k, v] of x) both += Math.min(v, y.get(k) ?? 0);
  return nx + ny ? (2 * both) / (nx + ny) : 0;
}
const LEAD_META = /^(?:fragmentet|det du sa|orden|ordet)\b[^.]{0,160}\b(?:låter som|liknar|är nog|är troligen|tolkar|uppfattar)\b|^(?:the (?:request|user|utterance|statement|fragment)\b|this is (?:a|an) (?:request|statement|question)\b|i'?ll (?:open|call|start|set|play)\b|det (?:här )?är (?:en statement|ett påstående, inte en fråga)\b|det (?:här )?är en fråga om (?:vem|vad|hur|när|var|varför|vilken|vilket|vilka)\b|det (?:här )?är en \p{L}*(?:förfrågan|begäran)\b)/iu;
/** "Och jag svarar på det: …" before the real answer. */
const LEAD_PREFIX = /^(?:och\s+|så\s+)?(?:jag svarar på det|då svarar jag|här är svaret)\s*[:,]?\s*/iu;
/** A first sentence that guesses ("som du kanske menar", "jag är inte säker"): rather silence than a wrong subject. */
const LEAD_UNSURE =
  /\b(?:som du (?:kanske|nog|troligen|antagligen) menar|om du menar|jag är (?:inte (?:helt )?säker|osäker)|kanske menar du|du menar (?:nog|kanske))\b/iu;
export function isUnsureLeadIn(sentence: string): boolean {
  return LEAD_UNSURE.test(sentence);
}
const LEAD_NAMED =
  /^(?:det|det här|detta|det där)\s+(?:låter som|verkar vara|verkar handla om|är|gäller)\s+["'„”»«]?([\p{L}][\p{L} -]{1,40}?)["'„”»«]?(?:\s*([,:])\s*(.*))?\s*[.!]?\s*$/isu;
export function rewriteLeadIn(sentence: string, heard: string): string {
  const t = sentence.trim();
  if (!t) return sentence;
  if (LEAD_META.test(t)) return "";
  if (LEAD_PREFIX.test(t)) {
    const r = t.replace(LEAD_PREFIX, "");
    return r ? `${r.charAt(0).toUpperCase()}${r.slice(1)}${/\s$/.test(sentence) ? " " : ""}` : "";
  }
  const m = LEAD_NAMED.exec(t);
  if (!m) return sentence;
  const [, term0, sep, rest0] = m;
  const term = term0.replace(/^(?:begreppet|ordet|termen|ämnet)\s+/iu, "");
  const rest = rest0?.replace(/^(?:så här är det(?: kort)?|kort sagt)\s*[:,]\s*/iu, "");
  // "Det låter som …" is always a reading; "Det är …" only when the term is what was heard (misheard), so
  // "Det är rätt." or "Det är viktigt, …" is never touched
  const sounds = /^(?:det|det här|detta|det där)\s+låter som\b/iu.test(t);
  if (!sounds && similarity(term, heard) < 0.6 && !letters(heard).includes(letters(term).slice(0, 6))) {
    return sentence;
  }
  const cap = term.charAt(0).toUpperCase() + term.slice(1);
  const trail = /\s$/.test(sentence) ? " " : "";
  if (!sep || !rest?.trim()) return ""; // "Det här är fotosyntesen." on its own says nothing
  const r = rest.trim().replace(/^(?:alltså|det vill säga|dvs\.?)\s+/i, "").replace(/^som\s+(?:är|betyder)\s+/iu, "");
  if (/^(?:en|ett|när|den|det|de|processen|läran|ett sätt)\b/i.test(r)) {
    return `${cap} är ${r}${/[.!?]$/.test(r) ? "" : "."}${trail}`;
  }
  return `${r.charAt(0).toUpperCase()}${r.slice(1)}${/[.!?]$/.test(r) ? "" : "."}${trail}`;
}

export class MetaGate {
  dropped = 0;
  private buf = "";
  private emitted = false;
  constructor(
    private readonly enabled: boolean,
    private readonly isMeta: (sentence: string) => boolean = isMetaReply,
    /** D77: returns the sentence with its meta part removed ("" = drop it); replaces `isMeta`. */
    private readonly rewrite?: (sentence: string) => string,
  ) {}
  push(text: string): string {
    if (!this.enabled) return text;
    this.buf += text;
    let out = "";
    for (;;) {
      const m = /[.!?](?:\s+|$)|\n/.exec(this.buf);
      if (!m || m.index + m[0].length >= this.buf.length && !/\s$/.test(m[0]) && m[0] !== "\n") {
        break;
      }
      const end = m.index + m[0].length;
      out += this.keep(this.buf.slice(0, end));
      this.buf = this.buf.slice(end);
    }
    return out;
  }
  finish(): string {
    if (!this.enabled) return "";
    const r = this.keep(this.buf);
    this.buf = "";
    return r;
  }
  /** K7.2: the sentence right after a dropped one is checked for a stump (once, never in a chain). */
  private afterDrop = false;
  private keep(sentence: string): string {
    const r0 = this.keep0(sentence);
    if (!sentence.trim()) return r0;
    if (r0 !== sentence && !r0.trim()) {
      this.afterDrop = true;
      return r0;
    }
    if (this.afterDrop) {
      this.afterDrop = false;
      const f = fixStump(r0);
      if (f !== r0) this.dropped++;
      return f;
    }
    return r0;
  }
  private keep0(sentence: string): string {
    if (this.rewrite) {
      if (!sentence.trim()) return sentence;
      let r = this.rewrite(sentence);
      if (r !== sentence) this.dropped++;
      // D79: after a dropped opening, the answer must not start with "Men …" / "Så …" / "Däremot …"
      if (r.trim() && !this.emitted && this.dropped > 0) {
        r = r.replace(/^(\s*)(?:men|så|däremot|dock)\b,?\s+(\p{L})/iu, (_m, ws: string, c: string) => ws + c.toUpperCase());
      }
      if (r.trim()) this.emitted = true;
      return r;
    }
    if (sentence.trim() && this.isMeta(sentence)) {
      this.dropped++;
      return "";
    }
    return sentence;
  }
}

// ---------- 0b. first line only (social lines) ----------
/** The social line is ONE line: whatever the model adds after the first line break (tips, requests for
 *  more context) is dropped in code, whatever the prompt said. */
export class FirstLineGate {
  private started = false;
  private closed = false;
  constructor(private readonly enabled: boolean) {}
  push(text: string): string {
    if (!this.enabled) return text;
    if (this.closed) return "";
    let out = "";
    for (const ch of text) {
      if (ch === "\n") {
        if (this.started) {
          this.closed = true;
          break;
        }
        continue; // leading blank lines
      }
      if (!/\s/.test(ch)) this.started = true;
      out += ch;
    }
    return out;
  }
}

// ---------- 1. duplicate guard ----------
const DUP_PREFIX = 40;
const DUP_PROBE = 12;

export class DupGuard {
  tripped = false;
  /** The earlier answer that was about to be repeated. */
  matched: string | null = null;
  private held = "";
  private decided: boolean;
  private readonly cands: string[];
  private readonly originals: string[];

  /** `previous`: earlier answers of this session whose question differs from the current fragment. */
  constructor(previous: string[]) {
    this.originals = previous.filter((p) => norm(p).length >= DUP_PREFIX);
    this.cands = this.originals.map((p) => norm(p).slice(0, DUP_PREFIX));
    this.decided = this.cands.length === 0;
  }

  push(text: string): string {
    if (this.decided || this.tripped) return this.tripped ? "" : text;
    this.held += text;
    const n = norm(this.held);
    if (n.length < DUP_PROBE) return ""; // too early to tell
    const alive = this.cands.some((c) => c.startsWith(n.slice(0, DUP_PREFIX)));
    if (!alive) return this.release();
    if (n.length >= DUP_PREFIX) {
      this.tripped = true;
      this.matched = this.originals[this.cands.findIndex((c) => c === n.slice(0, DUP_PREFIX))] ??
        null;
      this.held = "";
      return "";
    }
    return "";
  }

  finish(): string {
    if (this.decided || this.tripped) return "";
    return this.release();
  }

  private release(): string {
    this.decided = true;
    const h = this.held;
    this.held = "";
    return h;
  }
}

// ---------- 2. closing question trim ----------
// First words of Swedish/English questions put to the user. Only sentences starting with one are held
// back until their end is known; everything else streams straight through.
const Q_WORDS = new Set(
  (
    "vill önskar behöver kan skulle ska har är menar tycker finns får vad hur varför vilken vilket vilka när " +
    "var vem undrar want would do does is are can could should shall need have"
  ).split(" "),
);

/** Tutor check questions: short, one question, answerable in a word (no "..., och vilken ...?" pairs). */
export function tutorQuestionOk(sentence: string): boolean {
  const t = sentence.trim();
  if ((t.match(/\?/g) ?? []).length > 1) return false;
  if (t.split(/\s+/).length > 14) return false;
  return !/,?\s+och\s+(?:vilken|vilket|vilka|vad|hur|varför|när|var|vem)\s/i.test(t);
}

export class QuestionTrim {
  /** True when a trailing question was dropped and nothing else of the answer was passed on. */
  droppedOnly = false;
  dropped = "";
  private emitted = false;
  private mode: "undecided" | "pass" | "hold" = "undecided";
  private cur = ""; // current sentence text not yet passed on (undecided / hold)
  private heldQuestion = ""; // a finished question sentence waiting to see if more text follows
  private prev = ""; // previous char

  constructor(private readonly enabled: boolean, private readonly tutor = false) {}

  push(text: string): string {
    if (!this.enabled && !this.tutor) {
      if (text.trim()) this.emitted = true;
      return text;
    }
    let out = "";
    for (const ch of text) {
      out += this.char(ch);
      this.prev = ch;
    }
    if (out.trim()) this.emitted = true;
    return out;
  }

  private char(ch: string): string {
    let out = "";
    if (this.heldQuestion && !/\s/.test(ch)) {
      out += this.heldQuestion; // more text follows: it was a question inside the answer
      this.heldQuestion = "";
      this.mode = "undecided";
      this.cur = "";
    }
    if (this.mode === "pass") {
      out += ch;
      if (/\s/.test(ch) && /[.!?]/.test(this.prev)) {
        this.mode = "undecided";
        this.cur = "";
      }
      return out;
    }
    this.cur += ch;
    if (this.mode === "undecided") {
      const lead = /^\s*(\p{L}+)[^\p{L}]$/u.exec(this.cur);
      if (lead) {
        if (Q_WORDS.has(lead[1].toLowerCase())) this.mode = "hold";
        else {
          out += this.cur;
          this.cur = "";
          this.mode = "pass";
          if (/\s/.test(ch) && /[.!?]/.test(this.prev)) this.mode = "undecided";
        }
      } else if (/^\s*[^\s\p{L}]/u.test(this.cur) || this.cur.length > 40) {
        out += this.cur; // starts with a digit or symbol: not a question opener
        this.cur = "";
        this.mode = "pass";
      }
      if (this.mode !== "hold") return out;
    }
    // hold: wait for the sentence end
    if (/\s/.test(ch) && /[.!?]/.test(this.prev)) {
      const sent = this.cur;
      this.cur = "";
      this.mode = "undecided";
      if (this.tutor) {
        if (sent.trimEnd().endsWith("?") && !tutorQuestionOk(sent)) this.dropped = sent.trim();
        else out += sent;
      } else if (sent.trimEnd().endsWith("?")) this.heldQuestion = sent;
      else out += sent;
    }
    return out;
  }

  finish(): string {
    if (!this.enabled && !this.tutor) return "";
    let out = "";
    if (this.heldQuestion) {
      this.dropped = this.heldQuestion.trim();
      this.droppedOnly = !this.emitted;
      this.heldQuestion = "";
    }
    if (this.cur) {
      if (
        this.mode === "hold" && this.cur.trimEnd().endsWith("?") &&
        (!this.tutor || !tutorQuestionOk(this.cur))
      ) {
        this.dropped = this.cur.trim();
        this.droppedOnly = !this.emitted && !out.trim();
      } else out += this.cur;
      this.cur = "";
    }
    if (out.trim()) this.emitted = true;
    return out;
  }
}

// ---------- 3. digits -> words across chunk boundaries ----------
export class NumberStream {
  private buf = "";
  private tail = ""; // last raw text already passed on (context for the phone-number guard)

  private say(raw: string): string {
    const out = toSpeech(raw, this.tail);
    this.tail = (this.tail + raw).slice(-120);
    return out;
  }

  push(text: string): string {
    this.buf += text;
    // Complete tokens end at the last whitespace; the trailing partial token is always held back, and
    // so is the last complete token when it holds digits (its unit / next word is still to come).
    const lastWs = Math.max(this.buf.lastIndexOf(" "), this.buf.lastIndexOf("\n"));
    if (lastWs === -1) {
      if (this.buf.length <= 60) return "";
      const out = this.say(this.buf); // a very long token without spaces: do not hold it forever
      this.buf = "";
      return out;
    }
    let cut = lastWs + 1;
    const head = this.buf.slice(0, cut);
    const m = /((?:\d{1,3}[ \u00a0\u202f])*\S*\d\S*|[=≈≠]|\S*\^\S*)\s+$/.exec(head) ?? // incl. "1 " of "1 789"
      // D72 live test: "Karl " must wait for a possible "XV" (a regnal number is read as a pair with the
      // name), and a "Karl XV." pair is passed on together.
      /(?:\p{Lu}\p{L}+\s+)?(?:XVIII|XVII|XIII|XIV|XVI|XIX|VIII|VII|III|XII|XV|XI|IX|IV|II|VI|XX|V|X|I)[.,!?;:]?\s+$|\p{Lu}\p{L}+\s+$/u
        .exec(head);
    if (m && this.buf.length - cut < 160) cut = head.length - m[0].length;
    const out = this.say(this.buf.slice(0, cut));
    this.buf = this.buf.slice(cut);
    return out;
  }

  finish(): string {
    const out = this.say(this.buf);
    this.buf = "";
    return out;
  }
}

// ---------- pipeline ----------
export interface PostOptions {
  /** Earlier answers (for different fragments) to guard against repeating; empty disables the guard. */
  previousAnswers: string[];
  /** Drop a closing question to the user (false in tutoring, personas, confirmations). */
  trimQuestion: boolean;
  /** Social lines: keep only the first line (D51: no tips, no questions about context). */
  firstLineOnly?: boolean;
  /** D65: tutor mode: check questions must be short single questions (others are dropped). */
  tutor?: boolean;
  /** D53: the stream starts with a `[[REL ...]]` relation tag that is split off. */
  relationTag?: boolean;
  /** D65: web answer: `källa:` line to `source`, English sentences dropped. */
  web?: boolean;
  /** O41: phone tools offered in Swedish: the model's English reasoning ("The user asks to call…") is dropped. */
  dropEnglish?: boolean;
  /** D75: Provläge / Auto: the `[[TYST]]` marker and meta comments mean "say nothing". */
  silence?: boolean;
  /** D77: interview answer: sentences that say facts are missing are dropped. */
  interview?: boolean;
  /** D87: a Provläge profile names the subject, so a guessed reading is kept within it. */
  subjectKnown?: boolean;
  /** K1.5: the interviewer asks about a fact the CV does not give. */
  missingFact?: string;
  /** D86: "förhör mig": only the check question itself is said (the last sentence that ends with "?"). */
  quizOnly?: boolean;
  /** D84: split off a `källa:` line without the English filter (texts and quotes). */
  source?: boolean;
  /** 2026-11-08: sentences about the fragment / sound / microphone are dropped (all modes without a persona). */
  inputMeta?: boolean;
  /** K11: a request for a person's quote: a verbatim quote is kept only when the search gave its words. */
  quoteCheck?: boolean;
  /** Oscar 2026-11-08: Provläge: the fragment, so a first sentence that names the heard term can be cut. */
  heard?: string;
}

/**
 * K2 (Oscar's D87 review): markup the model sometimes writes at the end ("<br>", "<!-- -->", "<already_asked>",
 * "<safety>") is never read aloud. A "<" that starts a tag or comment is held until it closes (or 60 chars); a tag
 * or comment is dropped, anything else ("x < 5", "<3") is passed on unchanged.
 */
export class TagStrip {
  private held = "";
  push(text: string): string {
    let out = "";
    for (const ch of text) {
      if (this.held) {
        this.held += ch;
        const h = this.held;
        if (h.startsWith("<!--")) {
          if (h.endsWith("-->")) this.held = "";
          else if (h.length > 400) { out += h; this.held = ""; }
          continue;
        }
        if (h.length === 2 && !/^<[!/a-zA-Z_]$/.test(h)) { out += h; this.held = ""; continue; }
        if (h.startsWith("<!") && h.length <= 4 && "<!--".startsWith(h)) continue;
        if (ch === ">") {
          if (/^<\/?[a-zA-Z_][\w:-]{0,30}(?:\s[^<>]{0,40})?\/?>$/.test(h)) this.held = "";
          else { out += h; this.held = ""; }
          continue;
        }
        if (ch === "<" || ch === "\n" || h.length > 60) { out += h.slice(0, -1); this.held = ch === "<" ? "<" : ""; if (ch === "\n") out += ch; }
        continue;
      }
      if (ch === "<") this.held = "<";
      else out += ch;
    }
    return out;
  }
  /** An unclosed "<tag" at the very end is junk, not speech. */
  finish(): string {
    const h = this.held;
    this.held = "";
    return /^<[!/a-zA-Z_][\w:!-]*\s*$/.test(h) || h === "<" ? "" : h;
  }
}

/**
 * K11 (Oscar O5 finding D, third time): a quote by a person ("citera Strindberg om kärlek") was made up even with
 * the prompt rule. A verbatim quote (4+ words in quotation marks) is now said only when the same words are in what
 * the web search returned (the API's citations, `cited_text`); otherwise the sentence is dropped and the handler
 * asks once more for the content in the model's own words.
 */
const normWords = (t: string) => t.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();
/** The quoted parts of a sentence (an opening mark without a closing one runs to the end). */
export function quotedParts(sentence: string): string[] {
  const out: string[] = [];
  const re = /(?:^|[^\p{L}\p{N}])["“”«»„'‘’]([^"“”«»„]+?)(?:["“”«»„'‘’](?![\p{L}\p{N}])|$)/gu;
  for (const m of sentence.matchAll(re)) {
    const q = normWords(m[1]);
    if (q.split(" ").length >= 4) out.push(q);
  }
  return out;
}
export function quoteVerified(quote: string, cited: string): boolean {
  const c = normWords(cited);
  if (!c) return false;
  if (c.includes(quote)) return true;
  const w = quote.split(" ");
  let hit = 0;
  for (let i = 0; i < w.length - 1; i++) if (c.includes(`${w[i]} ${w[i + 1]}`)) hit++;
  return hit / Math.max(1, w.length - 1) >= 0.75;
}

export class AnswerPost {
  readonly dup: DupGuard;
  readonly trim: QuestionTrim;
  private readonly tap = new SummaryTap();
  private readonly strip = new TagStrip();
  private readonly rel: RelationTap;
  private readonly sil: SilenceTap;
  private readonly meta: MetaGate;
  private readonly imeta: MetaGate;
  private readonly input: MetaGate;
  private readonly level: MetaGate;
  private readonly lead: MetaGate;
  private readonly quote: MetaGate;
  private cited = "";
  /** K11: a quote was dropped because the search did not give its words (the handler may ask again). */
  unverifiedQuote = false;
  private readonly quizOnly: boolean;
  private quizBuf = "";
  private readonly src: SourceTap;
  private spoke = false;
  private readonly en: EnglishGate;
  private readonly gate: FirstLineGate;
  private readonly nums = new NumberStream();

  constructor(opts: PostOptions) {
    this.dup = new DupGuard(opts.previousAnswers);
    // K2: a profile without check questions trims every closing question, also in Provläge
    // K9: a question the student asked for ("ställ en svår fråga", "förhör mig på X") is never held to the short
    // check-question form (a hard question needs reasoning)
    this.trim = new QuestionTrim(opts.trimQuestion, opts.tutor === true && opts.trimQuestion !== true && opts.quizOnly !== true);
    this.gate = new FirstLineGate(opts.firstLineOnly === true);
    this.rel = new RelationTap(opts.relationTag === true);
    this.sil = new SilenceTap(opts.silence === true);
    this.meta = new MetaGate(opts.silence === true);
    let firstInterview = true;
    let interviewKept = false;
    const interviewRewrite = (sentence: string): string => {
      // K1.5: about a fact the CV does not give, the answer never opens with yes or no
      if (opts.missingFact && sentence.trim()) {
        if (claimsMissing(opts.missingFact, sentence)) return ""; // "Jag bor i Malmö …" when the CV never says so
        if (firstInterview) {
          firstInterview = false;
          const r = stripYesNoLead(sentence);
          if (r !== sentence) return r ? stripInterviewMeta(r) : "";
        }
      }
      return stripInterviewMeta(sentence);
    };
    this.imeta = new MetaGate(opts.interview === true, isInterviewMeta, (sentence) => {
      const r = interviewRewrite(sentence);
      if (!interviewKept && r.trim()) {
        if (isOpeningStump(r)) return ""; // K11: the answer never opens pointing at something not said
        interviewKept = true;
      }
      return r;
    });
    this.input = new MetaGate(opts.inputMeta === true, (x) => isInputMeta(x) || (opts.tutor === true && isReasoningMeta(x, opts.heard ?? "")));
    // K7.1: Provläge never says the level, the grade or what it chooses to explain (every sentence)
    this.level = new MetaGate(opts.tutor === true, () => false, rewriteLevelMeta);
    let firstDone = false;
    let unsure = false;
    this.lead = new MetaGate(opts.inputMeta === true && !!opts.heard, () => false, (sentence) => {
      if (unsure) return ""; // the answer started with a guess: nothing of it is said
      if (firstDone || !sentence.trim()) return sentence;
      firstDone = true;
      if (isUnsureLeadIn(sentence)) {
        // D87: with an exam profile the subject decides: drop the guess sentence, keep the answer.
        // Without one: rather silence than a wrong subject (Oscar 2026-11-08).
        unsure = opts.subjectKnown !== true;
        return "";
      }
      return rewriteLeadIn(sentence, opts.heard ?? "");
    });
    let openQuote = false;
    this.quote = new MetaGate(opts.quoteCheck === true, () => false, (sentence) => {
      if (openQuote) {
        // the rest of a dropped quote that ran over a sentence end
        if (/["“”«»„'’](?![\p{L}\p{N}])/u.test(sentence)) openQuote = false;
        return "";
      }
      const parts = quotedParts(sentence);
      if (!parts.length || parts.every((q) => quoteVerified(q, this.cited))) return sentence;
      this.unverifiedQuote = true;
      const marks = [...sentence].filter((ch) => `"“”«»„`.includes(ch)).length;
      if (marks % 2 === 1) openQuote = true;
      return "";
    });
    this.quizOnly = opts.quizOnly === true;
    this.src = new SourceTap(opts.web === true || opts.source === true);
    this.en = new EnglishGate(opts.web === true || opts.dropEnglish === true);
  }

  /** K11: text the web search returned (citations), used to check a verbatim quote. */
  addCited(text: string): void {
    this.cited += `
${text}`;
  }

  /** Domain of the web source (from the `källa:` line), or null. */
  get source(): string | null {
    return this.src.source;
  }

  /** D53 relation reported by the model (tag), or null. */
  get relation(): Relation | null {
    return this.rel.relation;
  }

  get duplicate(): boolean {
    return this.dup.tripped;
  }
  /** The model produced only a question to the user (nothing else could be said). */
  get questionOnly(): boolean {
    return this.trim.droppedOnly;
  }

  /** D48 summary of this exchange (from the trailer line), or null. */
  get summary(): string | null {
    return this.silent ? null : this.tap.summary;
  }

  /** D75: the model chose silence, or every sentence was a meta comment (nothing was spoken). */
  get silent(): boolean {
    return this.sil.silent || ((this.meta.dropped > 0 || this.input.dropped > 0 || this.level.dropped > 0 || this.lead.dropped > 0) && !this.spoke);
  }

  /** Oscar 2026-11-08: every interview sentence was a remark about missing facts (nothing was said). */
  get interviewMetaOnly(): boolean {
    return this.imeta.dropped > 0 && !this.spoke;
  }

  /** 2026-11-08: the silence marker came after text was already said: the whole answer counts as silent. */
  get silencedLate(): boolean {
    return this.sil.late;
  }

  /** D75: the silence marker was seen (the stream can stop at once). */
  get silenceMarked(): boolean {
    return this.sil.silent;
  }

  private capitalised = false;
  /** The answer starts with a capital letter (digits-to-words and the model can leave it lower case). */
  private cap(t: string): string {
    if (this.capitalised || !t.trim()) return t;
    this.capitalised = true;
    return t.replace(
      /^(\s*)(\p{Ll})(?![\p{L}]*\p{Lu})/u,
      (_m, ws: string, c: string) => ws + c.toUpperCase(),
    );
  }

  push(raw: string): string {
    const a = this.dup.push(
      this.gate.push(
        this.imeta.push(
          this.lead.push(this.level.push(this.input.push(
            this.meta.push(this.quote.push(this.en.push(this.src.push(this.strip.push(this.tap.push(this.sil.push(this.rel.push(raw)))))))),
          ))),
        ),
      ),
    );
    if (!a) return "";
    if (this.quizOnly) {
      this.quizBuf += a; // D86: held until the end, then only the question is said
      return "";
    }
    const out = this.cap(this.nums.push(this.trim.push(a)));
    if (out.trim()) this.spoke = true;
    return out;
  }

  finish(): string {
    const t0 = this.tap.push(this.sil.push(this.rel.finish()) + this.sil.finish()) + this.tap.finish();
    const t = this.strip.push(t0) + this.strip.finish();
    const s = this.src.push(t) + this.src.finish();
    const e0q = this.en.push(s) + this.en.finish();
    const e0 = this.quote.push(e0q) + this.quote.finish();
    const e1 = this.meta.push(e0) + this.meta.finish();
    const e2i = this.input.push(e1) + this.input.finish();
    const e2a = this.level.push(e2i) + this.level.finish();
    const e2 = this.lead.push(e2a) + this.lead.finish();
    const e = this.imeta.push(e2) + this.imeta.finish();
    let rest = this.trim.push(this.dup.push(this.gate.push(e)) + this.dup.finish()) +
      this.trim.finish();
    if (this.quizOnly) {
      const all = (this.quizBuf + rest).trim();
      const sentences = all.split(/(?<=[.!?])\s+/);
      const q = [...sentences].reverse().find((x) => x.trim().endsWith("?"));
      rest = q ? q.trim().replace(/^(?:[^:?]{0,80}:\s*)/u, "") : /\p{L}{3}/u.test(all) ? all : "";
    }
    const out = this.cap(this.nums.push(rest) + this.nums.finish());
    // D72 live test: when every answer sentence was filtered, a lone "Källa: X." is not an answer
    // (nothing is spoken, so the handler reports empty_answer and the app falls back).
    if (!this.spoke && /^\s*Källa: [^.]*\.\s*$/.test(out)) return "";
    if (out.trim()) this.spoke = true;
    return out;
  }
}
