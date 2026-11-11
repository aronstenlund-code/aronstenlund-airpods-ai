/**
 * Oscar O52 (prio 1): "Vad är klockan?" was answered by the model from <now> and read wrong ("20:57" became "tjugo
 * över åtta", "tjugo över nio"). The local time in Sweden is said by code, no model call:
 *   20:57 -> "Klockan är tre minuter i nio på kvällen, alltså tjugo och femtiosju."
 */
const NUM = ["noll", "ett", "två", "tre", "fyra", "fem", "sex", "sju", "åtta", "nio", "tio", "elva", "tolv", "tretton", "fjorton",
  "femton", "sexton", "sjutton", "arton", "nitton", "tjugo"];
const tens = (n: number) => n < 21 ? NUM[n] : `${["", "", "tjugo", "trettio", "fyrtio", "femtio"][Math.floor(n / 10)]}${n % 10 ? NUM[n % 10] : ""}`;
const HOUR12 = ["tolv", "ett", "två", "tre", "fyra", "fem", "sex", "sju", "åtta", "nio", "tio", "elva"];
const mins = (n: number) => n % 5 === 0 ? (n === 5 ? "fem" : tens(n)) : n === 1 ? "en minut" : `${tens(n)} minuter`;

function part(h: number): string {
  if (h < 5) return "på natten";
  if (h < 10) return "på morgonen";
  if (h < 12) return "på förmiddagen";
  if (h < 18) return "på eftermiddagen";
  return "på kvällen";
}

/** Swedish everyday clock for hour h (0-23) and minute m. */
export function sayClock(h: number, m: number): string {
  const next = (h + 1) % 24;
  const nameOf = (x: number) => HOUR12[x % 12];
  let words: string;
  if (m === 0) words = nameOf(h);
  else if (m === 15) words = `kvart över ${nameOf(h)}`;
  else if (m <= 20) words = `${mins(m)} över ${nameOf(h)}`;
  else if (m < 30) words = `${mins(30 - m)} i halv ${nameOf(next)}`;
  else if (m === 30) words = `halv ${nameOf(next)}`;
  else if (m < 40) words = `${mins(m - 30)} över halv ${nameOf(next)}`;
  else if (m === 45) words = `kvart i ${nameOf(next)}`;
  else words = `${mins(60 - m)} i ${nameOf(next)}`;
  const digital = m === 0 ? `${tens(h === 0 ? 0 : h)} noll noll` : `${h === 0 ? "noll" : tens(h)} och ${m < 10 ? `noll ${NUM[m]}` : tens(m)}`;
  return `Klockan är ${words} ${part(h)}, alltså ${digital}.`;
}

const CLOCK_Q = /^(?:(?:hej|okej|ok)\s+)?(?:(?:lumen|earmind),?\s+)?(?:(?:vet du|kan du (?:säga|kolla)|kolla) )?(?:vad (?:är|e) klockan|hur mycket är klockan|vad klockan är|vilken tid är det|vad är det för tid|hur dags är det|klockan)(?: (?:nu|just nu|exakt|egentligen|i sverige|här))?\s*[?.!]?$/iu;

/** The answer when the utterance asks the local time, else null. */
export function localClockAnswer(text: string, now: Date): string | null {
  if (!CLOCK_Q.test(text.trim())) return null;
  const p = Object.fromEntries(new Intl.DateTimeFormat("sv-SE", { hour: "numeric", minute: "numeric", hourCycle: "h23", timeZone: "Europe/Stockholm" })
    .formatToParts(now).map((x) => [x.type, x.value]));
  return sayClock(Number(p.hour), Number(p.minute));
}
