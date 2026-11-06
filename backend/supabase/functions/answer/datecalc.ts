import type { Computed } from "./calc.ts";

/**
 * D65: today's date, weekday, week number and time (Europe/Stockholm) go to the model as data in EVERY
 * request (`<now>`), and questions about the date, the clock and "how many days until ..." are computed here.
 * The model must never say it has no access to the date.
 */
const TZ = "Europe/Stockholm";
const WEEKDAYS = ["söndag", "måndag", "tisdag", "onsdag", "torsdag", "fredag", "lördag"];
const MONTHS = [
  "januari",
  "februari",
  "mars",
  "april",
  "maj",
  "juni",
  "juli",
  "augusti",
  "september",
  "oktober",
  "november",
  "december",
];

export interface Local {
  y: number;
  m: number; // 1-12
  d: number;
  wd: number; // 0 = Sunday
  hh: number;
  mm: number;
}

/** Wall-clock fields of `at` in Swedish time. */
export function localParts(at: Date): Local {
  const p = new Intl.DateTimeFormat("en-GB", {
    timeZone: TZ,
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "numeric",
    minute: "numeric",
    hour12: false,
  }).formatToParts(at);
  const g = (t: string) => Number(p.find((x) => x.type === t)?.value);
  const y = g("year"), m = g("month"), d = g("day");
  return {
    y,
    m,
    d,
    wd: new Date(Date.UTC(y, m - 1, d)).getUTCDay(),
    hh: g("hour") % 24,
    mm: g("minute"),
  };
}

const dayNumber = (y: number, m: number, d: number) => Math.round(Date.UTC(y, m - 1, d) / 86400000);

/** ISO 8601 week number. */
export function isoWeek(y: number, m: number, d: number): number {
  const t = new Date(Date.UTC(y, m - 1, d));
  const wd = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - wd);
  const start = Date.UTC(t.getUTCFullYear(), 0, 1);
  return Math.ceil(((t.getTime() - start) / 86400000 + 1) / 7);
}

const pad = (n: number) => String(n).padStart(2, "0");
const longDate = (y: number, m: number, d: number, wd: number) =>
  `${WEEKDAYS[wd]} ${d} ${MONTHS[m - 1]} ${y}`;

/** The data line sent with every request. */
export function nowContext(at: Date): string {
  const l = localParts(at);
  return `${longDate(l.y, l.m, l.d, l.wd)}, vecka ${isoWeek(l.y, l.m, l.d)}, klockan ${pad(l.hh)}:${
    pad(l.mm)
  } (svensk tid, ${TZ})`;
}

// ---------- named dates ----------
function easter(y: number): [number, number] {
  const a = y % 19, b = Math.floor(y / 100), c = y % 100, d = Math.floor(b / 4), e = b % 4;
  const f = Math.floor((b + 8) / 25), g = Math.floor((b - f + 1) / 3);
  const h = (19 * a + b - d - g + 15) % 30, i = Math.floor(c / 4), k = c % 4;
  const l = (32 + 2 * e + 2 * i - h - k) % 7, m = Math.floor((a + 11 * h + 22 * l) / 451);
  const month = Math.floor((h + l - 7 * m + 114) / 31), day = ((h + l - 7 * m + 114) % 31) + 1;
  return [month, day];
}
/** Date of the first `wd` on or after (m, d). */
function onOrAfter(y: number, m: number, d: number, wd: number): [number, number] {
  const t = new Date(Date.UTC(y, m - 1, d));
  t.setUTCDate(t.getUTCDate() + ((wd - t.getUTCDay() + 7) % 7));
  return [t.getUTCMonth() + 1, t.getUTCDate()];
}
function lastSunday(y: number, m: number): [number, number] {
  const t = new Date(Date.UTC(y, m, 0));
  t.setUTCDate(t.getUTCDate() - t.getUTCDay());
  return [t.getUTCMonth() + 1, t.getUTCDate()];
}
const shift = (y: number, [m, d]: [number, number], by: number): [number, number] => {
  const t = new Date(Date.UTC(y, m - 1, d + by));
  return [t.getUTCMonth() + 1, t.getUTCDate()];
};

type Named = { label: string; at: (y: number) => [number, number] };
const NAMED: Record<string, Named> = {
  julafton: { label: "julafton", at: () => [12, 24] },
  jul: { label: "julafton", at: () => [12, 24] },
  juldagen: { label: "juldagen", at: () => [12, 25] },
  "annandag jul": { label: "annandag jul", at: () => [12, 26] },
  nyårsafton: { label: "nyårsafton", at: () => [12, 31] },
  nyår: { label: "nyårsdagen", at: () => [1, 1] },
  nyårsdagen: { label: "nyårsdagen", at: () => [1, 1] },
  trettondedag: { label: "trettondedag jul", at: () => [1, 6] },
  "trettondedag jul": { label: "trettondedag jul", at: () => [1, 6] },
  lucia: { label: "lucia", at: () => [12, 13] },
  "alla hjärtans dag": { label: "alla hjärtans dag", at: () => [2, 14] },
  valborg: { label: "valborgsmässoafton", at: () => [4, 30] },
  valborgsmässoafton: { label: "valborgsmässoafton", at: () => [4, 30] },
  "första maj": { label: "första maj", at: () => [5, 1] },
  nationaldagen: { label: "nationaldagen", at: () => [6, 6] },
  halloween: { label: "halloween", at: () => [10, 31] },
  påsk: { label: "påskdagen", at: easter },
  påskdagen: { label: "påskdagen", at: easter },
  påskafton: { label: "påskafton", at: (y) => shift(y, easter(y), -1) },
  långfredagen: { label: "långfredagen", at: (y) => shift(y, easter(y), -2) },
  midsommar: { label: "midsommarafton", at: (y) => onOrAfter(y, 6, 19, 5) },
  midsommarafton: { label: "midsommarafton", at: (y) => onOrAfter(y, 6, 19, 5) },
  midsommardagen: { label: "midsommardagen", at: (y) => shift(y, onOrAfter(y, 6, 19, 5), 1) },
  "alla helgons dag": { label: "alla helgons dag", at: (y) => onOrAfter(y, 10, 31, 6) },
  "mors dag": { label: "mors dag", at: (y) => lastSunday(y, 5) },
  "fars dag": { label: "fars dag", at: (y) => onOrAfter(y, 11, 8, 0) },
};
const MONTH_NO = Object.fromEntries(MONTHS.map((m, i) => [m, i + 1]));

function daysText(n: number): string {
  if (n === 0) return "i dag";
  if (n === 1) return "i morgon";
  const w = Math.floor(n / 7), r = n % 7;
  const weeks = w > 0
    ? ` (${w} ${w === 1 ? "vecka" : "veckor"}${r ? ` och ${r} ${r === 1 ? "dag" : "dagar"}` : ""})`
    : "";
  return `om ${n} dagar${weeks}`;
}

/** Next occurrence (today counts) of a month/day, or the exact date when a year is given. */
function untilDate(
  l: Local,
  label: string,
  find: (y: number) => [number, number],
  year?: number,
): Computed {
  let y = year ?? l.y;
  let [m, d] = find(y);
  let diff = dayNumber(y, m, d) - dayNumber(l.y, l.m, l.d);
  if (diff < 0 && year === undefined) {
    y += 1;
    [m, d] = find(y);
    diff = dayNumber(y, m, d) - dayNumber(l.y, l.m, l.d);
  }
  const wd = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  const when = diff < 0 ? `för ${-diff} ${-diff === 1 ? "dag" : "dagar"} sedan` : daysText(diff);
  return {
    value: diff,
    text: `Idag är det ${longDate(l.y, l.m, l.d, l.wd)}. ${label[0].toUpperCase()}${
      label.slice(1)
    } är ${longDate(y, m, d, wd)}, ${when}`,
  };
}

/** Date / weekday / week / clock questions and "how many days until X". */
export function dateCalc(fragment: string, at: Date = new Date()): Computed | null {
  const f = fragment.toLowerCase().trim().replace(/[?!.]+$/g, "").replace(/\s+/g, " ");
  if (!f || f.length > 90) return null;
  const l = localParts(at);
  const today = longDate(l.y, l.m, l.d, l.wd);
  const week = isoWeek(l.y, l.m, l.d);
  if (
    /^(?:vad|vilket) (?:är det för )?datum (?:är det|har vi)(?: idag| i dag| nu)?$|^vad är det för datum(?: idag| i dag)?$/
      .test(f)
  ) {
    return { value: l.d, text: `Idag är det ${today} (vecka ${week})` };
  }
  if (
    /^vilken (?:veckodag|dag) (?:är det|har vi)(?: idag| i dag| nu)?$|^vad är det för dag(?: idag| i dag)?$/
      .test(f)
  ) {
    return { value: l.wd, text: `Idag är det ${WEEKDAYS[l.wd]} (${today}, vecka ${week})` };
  }
  if (
    /^vilken vecka (?:är det|har vi)(?: nu| idag| i dag)?$|^vilket veckonummer (?:är det|har vi)(?: nu| idag)?$/
      .test(f)
  ) {
    return { value: week, text: `Det är vecka ${week} (${today})` };
  }
  if (/^vilket år (?:är det|har vi)(?: nu| idag)?$/.test(f)) {
    return { value: l.y, text: `Det är år ${l.y} (${today})` };
  }
  if (/^vilken månad (?:är det|har vi)(?: nu| idag)?$/.test(f)) {
    return { value: l.m, text: `Det är ${MONTHS[l.m - 1]} ${l.y} (${today})` };
  }
  if (/^(?:vad|hur mycket) är klockan(?: nu| just nu| idag)?$|^vad är klockan här$/.test(f)) {
    return {
      value: l.hh * 60 + l.mm,
      text: `Klockan är ${pad(l.hh)}:${pad(l.mm)} svensk tid (${today})`,
    };
  }
  const m =
    /^hur (?:många dagar|lång tid|länge|många veckor) (?:är det |dröjer det |återstår det )?(?:kvar |det )?(?:till|tills)(?: att det är| att det blir)? (?:den )?(.+)$/
      .exec(f);
  if (m) {
    const what = m[1].replace(/^(?:nästa|kommande) /, "").trim();
    const named = NAMED[what];
    if (named) return untilDate(l, named.label, named.at);
    const dm =
      /^(\d{1,2}):?(?:a|e)? (januari|februari|mars|april|maj|juni|juli|augusti|september|oktober|november|december)(?: (\d{4}))?$/
        .exec(what);
    if (dm) {
      const day = Number(dm[1]), mon = MONTH_NO[dm[2]];
      if (day >= 1 && day <= 31) {
        return untilDate(l, `${day} ${dm[2]}`, () => [mon, day], dm[3] ? Number(dm[3]) : undefined);
      }
    }
  }
  return null;
}
