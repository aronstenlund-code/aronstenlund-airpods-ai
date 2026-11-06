import { wordsToNumber } from "./svnum.ts";
import type { Computed } from "./calc.ts";

/**
 * D54: clock times and time differences between places are computed in code with the real tz database
 * (daylight saving included, for today's date) and handed to the model as `<computed>` data. The model
 * used to guess the offset (and hedge about "winter / summer").
 */

const HOME = "Europe/Stockholm";

// Swedish and English names -> IANA zone. Keys are lower case, without "i"/"in".
const ZONES: Record<string, [string, string]> = {
  "kapstaden": ["Africa/Johannesburg", "Kapstaden"],
  "cape town": ["Africa/Johannesburg", "Kapstaden"],
  "sydafrika": ["Africa/Johannesburg", "Sydafrika"],
  "tel aviv": ["Asia/Jerusalem", "Tel Aviv"],
  "jerusalem": ["Asia/Jerusalem", "Jerusalem"],
  "israel": ["Asia/Jerusalem", "Israel"],
  "riyadh": ["Asia/Riyadh", "Riyadh"],
  "saudiarabien": ["Asia/Riyadh", "Saudiarabien"],
  "doha": ["Asia/Qatar", "Doha"],
  "teheran": ["Asia/Tehran", "Teheran"],
  "karachi": ["Asia/Karachi", "Karachi"],
  "dhaka": ["Asia/Dhaka", "Dhaka"],
  "jakarta": ["Asia/Jakarta", "Jakarta"],
  "manila": ["Asia/Manila", "Manila"],
  "taipei": ["Asia/Taipei", "Taipei"],
  "kuala lumpur": ["Asia/Kuala_Lumpur", "Kuala Lumpur"],
  "hanoi": ["Asia/Bangkok", "Hanoi"],
  "osaka": ["Asia/Tokyo", "Osaka"],
  "kyoto": ["Asia/Tokyo", "Kyoto"],
  "wellington": ["Pacific/Auckland", "Wellington"],
  "santiago": ["America/Santiago", "Santiago"],
  "lima": ["America/Lima", "Lima"],
  "bogota": ["America/Bogota", "Bogotá"],
  "bogotá": ["America/Bogota", "Bogotá"],
  "havanna": ["America/Havana", "Havanna"],
  "anchorage": ["America/Anchorage", "Anchorage"],
  "houston": ["America/Chicago", "Houston"],
  "dallas": ["America/Chicago", "Dallas"],
  "atlanta": ["America/New_York", "Atlanta"],
  "philadelphia": ["America/New_York", "Philadelphia"],
  "las vegas": ["America/Los_Angeles", "Las Vegas"],
  "phoenix": ["America/Phoenix", "Phoenix"],
  "montreal": ["America/Toronto", "Montreal"],
  "ottawa": ["America/Toronto", "Ottawa"],
  "edmonton": ["America/Edmonton", "Edmonton"],
  "kiev": ["Europe/Kyiv", "Kiev"],
  "kyiv": ["Europe/Kyiv", "Kiev"],
  "warszawa": ["Europe/Warsaw", "Warszawa"],
  "warsaw": ["Europe/Warsaw", "Warszawa"],
  "prag": ["Europe/Prague", "Prag"],
  "wien": ["Europe/Vienna", "Wien"],
  "budapest": ["Europe/Budapest", "Budapest"],
  "bukarest": ["Europe/Bucharest", "Bukarest"],
  "sofia": ["Europe/Sofia", "Sofia"],
  "belgrad": ["Europe/Belgrade", "Belgrad"],
  "zürich": ["Europe/Zurich", "Zürich"],
  "zurich": ["Europe/Zurich", "Zürich"],
  "genève": ["Europe/Zurich", "Genève"],
  "bryssel": ["Europe/Brussels", "Bryssel"],
  "amsterdam": ["Europe/Amsterdam", "Amsterdam"],
  "köpenhamn": ["Europe/Copenhagen", "Köpenhamn"],
  "oslo": ["Europe/Oslo", "Oslo"],
  "stockholm": ["Europe/Stockholm", "Stockholm"],
  "tallinn": ["Europe/Tallinn", "Tallinn"],
  "riga": ["Europe/Riga", "Riga"],
  "vilnius": ["Europe/Vilnius", "Vilnius"],
  "minsk": ["Europe/Minsk", "Minsk"],
  "casablanca": ["Africa/Casablanca", "Casablanca"],
  "accra": ["Africa/Accra", "Accra"],
  "addis abeba": ["Africa/Addis_Ababa", "Addis Abeba"],
  "dar es salaam": ["Africa/Dar_es_Salaam", "Dar es Salaam"],
  "barcelona": ["Europe/Madrid", "Barcelona"],
  "milano": ["Europe/Rome", "Milano"],
  "münchen": ["Europe/Berlin", "München"],
  "hamburg": ["Europe/Berlin", "Hamburg"],
  "göteborg": ["Europe/Stockholm", "Göteborg"],
  "malmö": ["Europe/Stockholm", "Malmö"],
  "mexiko": ["America/Mexico_City", "Mexiko"],
  "kanada": ["America/Toronto", "Kanada"],
  "usa": ["America/New_York", "USA (östkusten)"],
  tokyo: ["Asia/Tokyo", "Tokyo"],
  tokio: ["Asia/Tokyo", "Tokyo"],
  seoul: ["Asia/Seoul", "Seoul"],
  peking: ["Asia/Shanghai", "Peking"],
  beijing: ["Asia/Shanghai", "Peking"],
  shanghai: ["Asia/Shanghai", "Shanghai"],
  kina: ["Asia/Shanghai", "Kina"],
  japan: ["Asia/Tokyo", "Japan"],
  hongkong: ["Asia/Hong_Kong", "Hongkong"],
  "hong kong": ["Asia/Hong_Kong", "Hongkong"],
  singapore: ["Asia/Singapore", "Singapore"],
  bangkok: ["Asia/Bangkok", "Bangkok"],
  thailand: ["Asia/Bangkok", "Thailand"],
  delhi: ["Asia/Kolkata", "Delhi"],
  "new delhi": ["Asia/Kolkata", "New Delhi"],
  mumbai: ["Asia/Kolkata", "Mumbai"],
  indien: ["Asia/Kolkata", "Indien"],
  dubai: ["Asia/Dubai", "Dubai"],
  moskva: ["Europe/Moscow", "Moskva"],
  moscow: ["Europe/Moscow", "Moskva"],
  istanbul: ["Europe/Istanbul", "Istanbul"],
  turkiet: ["Europe/Istanbul", "Turkiet"],
  kairo: ["Africa/Cairo", "Kairo"],
  cairo: ["Africa/Cairo", "Kairo"],
  johannesburg: ["Africa/Johannesburg", "Johannesburg"],
  nairobi: ["Africa/Nairobi", "Nairobi"],
  lagos: ["Africa/Lagos", "Lagos"],
  london: ["Europe/London", "London"],
  storbritannien: ["Europe/London", "Storbritannien"],
  dublin: ["Europe/Dublin", "Dublin"],
  lissabon: ["Europe/Lisbon", "Lissabon"],
  reykjavik: ["Atlantic/Reykjavik", "Reykjavik"],
  island: ["Atlantic/Reykjavik", "Island"],
  paris: ["Europe/Paris", "Paris"],
  berlin: ["Europe/Berlin", "Berlin"],
  rom: ["Europe/Rome", "Rom"],
  madrid: ["Europe/Madrid", "Madrid"],
  helsingfors: ["Europe/Helsinki", "Helsingfors"],
  helsinki: ["Europe/Helsinki", "Helsingfors"],
  finland: ["Europe/Helsinki", "Finland"],
  aten: ["Europe/Athens", "Aten"],
  "new york": ["America/New_York", "New York"],
  newyork: ["America/New_York", "New York"],
  washington: ["America/New_York", "Washington"],
  boston: ["America/New_York", "Boston"],
  miami: ["America/New_York", "Miami"],
  toronto: ["America/Toronto", "Toronto"],
  chicago: ["America/Chicago", "Chicago"],
  denver: ["America/Denver", "Denver"],
  "los angeles": ["America/Los_Angeles", "Los Angeles"],
  "san francisco": ["America/Los_Angeles", "San Francisco"],
  kalifornien: ["America/Los_Angeles", "Kalifornien"],
  seattle: ["America/Los_Angeles", "Seattle"],
  vancouver: ["America/Vancouver", "Vancouver"],
  honolulu: ["Pacific/Honolulu", "Honolulu"],
  hawaii: ["Pacific/Honolulu", "Hawaii"],
  "mexico city": ["America/Mexico_City", "Mexico City"],
  "rio de janeiro": ["America/Sao_Paulo", "Rio de Janeiro"],
  "sao paulo": ["America/Sao_Paulo", "São Paulo"],
  "são paulo": ["America/Sao_Paulo", "São Paulo"],
  brasilien: ["America/Sao_Paulo", "Brasilien"],
  "buenos aires": ["America/Argentina/Buenos_Aires", "Buenos Aires"],
  sydney: ["Australia/Sydney", "Sydney"],
  melbourne: ["Australia/Melbourne", "Melbourne"],
  australien: ["Australia/Sydney", "Australien"],
  perth: ["Australia/Perth", "Perth"],
  auckland: ["Pacific/Auckland", "Auckland"],
  "nya zeeland": ["Pacific/Auckland", "Nya Zeeland"],
};

function offsetMinutes(zone: string, at: Date): number {
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: zone, timeZoneName: "longOffset" })
    .formatToParts(at);
  const name = parts.find((p) => p.type === "timeZoneName")?.value ?? "GMT";
  const m = /GMT([+-])(\d{1,2})(?::(\d{2}))?/.exec(name);
  if (!m) return 0;
  return (m[1] === "-" ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3] ?? 0));
}

const pad = (n: number) => String(n).padStart(2, "0");
const fmt = (min: number) => `${pad(Math.floor(min / 60))}:${pad(min % 60)}`;

function parseClock(t: string): number | null {
  const s = t.trim().replace(/^(?:klockan|kl\.?)\s*/, "");
  const d = /^(\d{1,2})(?:[:.](\d{2}))?$/.exec(s);
  if (d) {
    const h = Number(d[1]), m = Number(d[2] ?? 0);
    return h <= 24 && m < 60 ? (h % 24) * 60 + m : null;
  }
  const w = wordsToNumber(s);
  return w !== null && w >= 0 && w <= 24 ? (w % 24) * 60 : null;
}

function hoursText(diffMin: number): string {
  const h = Math.abs(diffMin) / 60;
  const n = Number.isInteger(h) ? String(h) : String(h).replace(".", ",");
  return `${n} ${h === 1 ? "timme" : "timmar"}`;
}

const LOOK = "(?:vad|hur mycket|vilken tid|hur sent|hur tidigt)";

export function zoneClock(fragment: string, now: Date = new Date()): Computed | null {
  const f = fragment.toLowerCase().trim().replace(/[?!.]+$/g, "").replace(/\s+/g, " ");
  if (f.length > 100) return null;
  let city: string | null = null, given: string | null = null, diffOnly = false;
  let m = new RegExp(
    `^${LOOK} är (?:klockan|tiden) (?:i|på|över) (.+?)(?: (?:när|om) (?:den|klockan|det) är (.+?) (?:här|hemma|i sverige))?$`,
  ).exec(f);
  if (m) [city, given] = [m[1], m[2] ?? null];
  if (!m) {
    m =
      /^när (?:den|klockan|det) är (.+?) (?:här|hemma|i sverige),? (?:vad|hur mycket) är (?:den|klockan|det) (?:i|på) (.+)$/
        .exec(f);
    if (m) [given, city] = [m[1], m[2]];
  }
  if (!m) {
    m = /^(?:vad|hur stor) är tidsskillnaden (?:mellan sverige och|till|från sverige till) (.+)$/
      .exec(
        f,
      ) ??
      /^hur många timmar (?:före|efter|skiljer) (?:är )?(?:det )?(?:mellan sverige och |i |från sverige till )?(.+)$/
        .exec(f);
    if (m) [city, diffOnly] = [m[1], true];
  }
  if (!m || !city) return null;
  const key = city.replace(/^(?:staden|i)\s+/, "").trim();
  const z = ZONES[key];
  if (!z) return null;
  const home = offsetMinutes(HOME, now), there = offsetMinutes(z[0], now);
  const diff = there - home;
  const rel = diff === 0
    ? "samma tid som Sverige"
    : `${hoursText(diff)} ${diff > 0 ? "före" : "efter"} Sverige`;
  if (diffOnly) {
    return {
      value: diff / 60,
      text: `${z[1]} är ${rel} just nu (sommar-/vintertid för dagens datum)`,
    };
  }
  let hereMin: number;
  let label: string;
  if (given) {
    const g = parseClock(given);
    if (g === null) return null;
    hereMin = g;
    label = `Klockan ${fmt(g)} i Sverige`;
  } else {
    const t = new Date(now.getTime() + home * 60000);
    hereMin = t.getUTCHours() * 60 + t.getUTCMinutes();
    label = `Klockan ${fmt(hereMin)} i Sverige just nu`;
  }
  const thereAbs = hereMin + diff;
  const dayShift = Math.floor(thereAbs / 1440);
  const thereMin = ((thereAbs % 1440) + 1440) % 1440;
  const day = dayShift === 0 ? "" : dayShift > 0 ? ", nästa dag" : ", dagen före";
  return {
    value: thereMin,
    text: `${label} är klockan ${fmt(thereMin)} i ${z[1]}${day} (${z[1]} är ${rel})`,
  };
}
