/**
 * K19 (owner approved): a link to a good film or page about what the student studies. On request ("har du en film
 * om fotosyntes?", "finns det någon bra sida om det här?") Lumen searches ONLY a list of Swedish learning resources,
 * returns ONE link with title and source as `resource`, and says one short sentence. The link is fetched in code:
 * it must answer 200, be on the list and be about the topic (in its title or address). No invented URL is passed on.
 */

export const RESOURCE_DOMAINS = ["urplay.se", "binogi.se", "sli.se", "skolverket.se", "ne.se", "sv.khanacademy.org", "khanacademy.org"];
const SOURCE_NAMES: Record<string, string> = {
  "urplay.se": "UR Play",
  "binogi.se": "Binogi",
  "sli.se": "SLI",
  "skolverket.se": "Skolverket",
  "ne.se": "NE",
  "sv.khanacademy.org": "Khan Academy",
  "khanacademy.org": "Khan Academy",
};
/** Pages that usually need a school login (said in the answer). */
const LOGIN = new Set(["binogi.se", "sli.se", "ne.se"]);

const ASK = /(?<![\p{L}])(?:har du (?:en|någon) (?:bra )?(?:film|video|filmklipp|sida|länk|webbsida|resurs)|finns det (?:en|någon) (?:bra )?(?:film|video|filmklipp|sida|länk|webbsida)|(?:tipsa|tips) (?:om|på) (?:en|någon) (?:bra )?(?:film|video|sida)|skicka (?:en|någon) (?:länk|film|video)|ge mig en (?:länk|film|video)|en (?:film|video) (?:om|på) det(?: här)?|var kan jag (?:se|titta på) (?:en )?(?:film|video))(?![\p{L}])/iu;

// K27 (Oscar O31: 5/15): any asking word + a film/page word + a topic ("kan du hitta en film om cellen", "har du nåt
// bra på UR om demokrati", "var kan jag läsa mer om …"); a film that was seen or a question about a film is not one
const REQ = String.raw`(?:har du|finns det|tipsa|tips|skicka|ge mig|hitta|visa|länka|rekommendera|vill (?:se|titta på|läsa)|var kan jag (?:se|läsa|titta|hitta)|kan du (?:hitta|visa|länka|skicka|ge|rekommendera|tipsa)|någon|nån|nåt|något)`;
const NOUN = String.raw`(?:film|filmer|video|videor|videon|filmklipp|klipp|sida|sidor|länk|länkar|webbsida|resurs|youtube\p{L}*|ur play|ur)`;
const ASK_CONTENT = new RegExp(
  String.raw`(?<![\p{L}])${REQ}(?: [\p{L}-]+){0,3} ${NOUN}(?: [\p{L}-]+){0,3}? (?:om|kring|angående)(?![\p{L}])|(?<![\p{L}])(?:var kan jag|kan du|vill) läsa mer om(?![\p{L}])|(?<![\p{L}])länka (?:något|nåt|någon|en|ett) (?:\p{L}+ )?om(?![\p{L}])`,
  "iu",
);

export function isResourceRequest(fragment: string): boolean {
  const f = fragment ?? "";
  return ASK.test(f) ||
    (ASK_CONTENT.test(f) && !/(?<![\p{L}])(?:såg|sett|tittade på|gjorde|gjort|läste)(?![\p{L}])/iu.test(f));
}

/** K-stående (Oscar O34 grupp 14, Auto): in Auto (hands-free, it also hears other people) only a request that STARTS the
 *  utterance, addressed to Lumen, goes to the link search ("kan du hitta en film om …", "någon youtube om …",
 *  "jag vill se en film om …"). Auto still never searches the web for answers (D46); this is only the K19 link. */
export function isDirectResourceRequest(fragment: string): boolean {
  const f = (fragment ?? "").trim().replace(/^(?:(?:hej|okej|ok)\s+)?lumen[,!.]?\s*/iu, "");
  return isResourceRequest(f) &&
    /^(?:kan du|kan jag få|har du|finns det|visa|hitta|länka|ge mig|skicka|rekommendera|tipsa|jag vill (?:se|titta på|läsa)|var kan jag|någon|nån|nåt|något|en (?:film|video))(?![\p{L}])/iu.test(f);
}

/** K-stående (O34): a URL as the search gave it, for comparing ("https://www.x.se/a/" = "https://x.se/a"). */
export function sameUrl(a: string, b: string): boolean {
  const n = (u: string) => u.trim().toLowerCase().replace(/^https?:\/\/(?:www\.)?/, "").replace(/[#?].*$/, "").replace(/\/+$/, "");
  return n(a) === n(b);
}

/** Sites that answer automated checks with 403/429 (bot protection) although the page is there (UR Play, 2026-11-11):
 *  such a status counts only for a URL the web search itself returned, never for a URL the model wrote alone. */
export const BLOCKED_CHECK = new Set([401, 403, 429, 503]);

/** The topic: the words after "om"/"på" in the request, else the last question studied. */
export function resourceTopic(fragment: string, lastQ?: string): string {
  const m = /(?:om|på|kring|angående) (.{3,80}?)\s*[?.!]?$/iu.exec(fragment.trim());
  const t = m?.[1]?.replace(/\s*(?:på|från|i) (?:ur play|ur|youtube|binogi|sli|ne|khan academy)\s*$/iu, "")
    .replace(/^(?:det här|det|detta|den här)\s*/iu, "").replace(/^(?:på|från) (?:ur play|ur|youtube|binogi)\s*$/iu, "").trim();
  return t && t.length >= 3 ? t : (lastQ ?? "").replace(/^(?:vad är|vad betyder|förklara|hur fungerar)\s+/iu, "").trim();
}

export const RESOURCE_PROMPT = `

LEARNING RESOURCE (K19, this request): the student wants ONE good film or page about the topic in <topic>. Use web_search; the search is limited to Swedish learning resources (UR Play, Binogi, SLI, Skolverket, NE, Khan Academy). Pick the single best result for the student's grade: a film when they asked for a film, otherwise a page. Reply in exactly two lines and nothing else:
LÄNK: <the exact URL from a search result> | <its title>
Then one short spoken Swedish sentence: "Jag skickade en länk till <en film|en sida> om <topic> från <source>, säg till om du vill ha en annan." Never write a URL that is not in the search results. When nothing fits, write only: INGEN LÄNK`;

export interface Resource {
  url: string;
  title: string;
  source: string;
  login_likely: boolean;
}

export function parseResource(text: string): { url: string; title: string } | null {
  const m = /LÄNK:\s*(https?:\/\/\S+?)\s*\|\s*(.+)/iu.exec(text);
  if (!m) return null;
  return { url: m[1].replace(/[)>\].,]+$/u, ""), title: m[2].split("\n")[0].trim().slice(0, 160) };
}

export function domainOf(url: string): string | null {
  try {
    const h = new URL(url).hostname.toLowerCase().replace(/^www\./, "");
    return RESOURCE_DOMAINS.find((d) => h === d || h.endsWith(`.${d}`)) ?? null;
  } catch {
    return null;
  }
}

const stem = (w: string) => w.toLowerCase().normalize("NFC").replace(/[^\p{L}]/gu, "").slice(0, 6);

/** Is the page about the topic? A topic word (its first six letters) in the title, the page title or the address. */
export function aboutTopic(topic: string, title: string, pageTitle: string, url: string): boolean {
  const words = topic.split(/\s+/).map(stem).filter((w) => w.length >= 4);
  if (!words.length) return true;
  const hay = `${title} ${pageTitle} ${decodeURIComponent(url)}`.toLowerCase().normalize("NFC");
  return words.some((w) => hay.includes(w));
}

/** Fetch the page: 200 (after redirects) and its <title>. */
export async function checkLink(url: string, fetchImpl: typeof fetch = fetch): Promise<{ ok: boolean; status: number; pageTitle: string }> {
  try {
    const r = await fetchImpl(url, { redirect: "follow", signal: AbortSignal.timeout(4000), headers: { "user-agent": "Mozilla/5.0 (Lumen link check)" } });
    const html = r.ok ? (await r.text()).slice(0, 60_000) : "";
    if (!r.ok) await r.body?.cancel().catch(() => {});
    const t = /<title[^>]*>([^<]{1,200})<\/title>/iu.exec(html)?.[1]?.trim() ?? "";
    return { ok: r.status === 200, status: r.status, pageTitle: t };
  } catch {
    return { ok: false, status: 0, pageTitle: "" };
  }
}

export function resourceOf(url: string, title: string): Resource | null {
  const d = domainOf(url);
  if (!d) return null;
  return { url, title, source: SOURCE_NAMES[d] ?? d, login_likely: LOGIN.has(d) };
}

export function spokenFor(r: Resource, topic: string, said: string): string {
  const film = /urplay|binogi|sli/.test(r.url) || /film|video|avsnitt/i.test(r.title);
  const base = said && /^Jag skickade en länk/u.test(said.trim())
    ? said.trim()
    : `Jag skickade en länk till ${film ? "en film" : "en sida"} om ${topic} från ${r.source}, säg till om du vill ha en annan.`;
  return r.login_likely ? `${base} Den kan kräva att du loggar in med ditt skolkonto.` : base;
}

export const NO_RESOURCE =
  "Jag hittade ingen bra film eller sida om det just nu. Fråga gärna din lärare, eller sök på UR Play.";
