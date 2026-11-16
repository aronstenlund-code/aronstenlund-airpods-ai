/**
 * K81 (D204): a web page's readable text, in code (no JavaScript is ever run, no browser). Headings become "# "
 * lines (as /exam read and the photo flow expect), paragraphs and list items lines, a table row one line with its
 * cells joined. Navigation, scripts, styles, forms, footers and hidden parts are left out.
 */
const ENTITIES: Record<string, string> = {
  amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ", ndash: "–", mdash: "—", hellip: "…", laquo: "«", raquo: "»",
  rsquo: "’", lsquo: "‘", rdquo: "”", ldquo: "“", auml: "ä", ouml: "ö", aring: "å", Auml: "Ä", Ouml: "Ö", Aring: "Å",
  eacute: "é", uuml: "ü", deg: "°", shy: "", middot: "·", times: "×", copy: "©",
};
export function decodeEntities(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e: string) => {
    if (e[0] === "#") {
      const n = e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return Number.isFinite(n) && n > 0 && n < 0x110000 ? String.fromCodePoint(n) : "";
    }
    return ENTITIES[e] ?? m;
  });
}

const DROP = /<(script|style|noscript|template|svg|canvas|iframe|object|embed|form|select|button|nav|footer|aside|head)\b[\s\S]*?<\/\1\s*>/gi;

export function pageTitle(html: string): string {
  const og = /<meta[^>]+property=["']og:title["'][^>]*content=["']([^"']{1,300})["']/i.exec(html)?.[1];
  const t = /<title[^>]*>([\s\S]{0,500}?)<\/title>/i.exec(html)?.[1];
  return decodeEntities((t || og || "").replace(/<[^>]+>/g, "")).replace(/\s+/g, " ").trim().slice(0, 200);
}

export function htmlToText(html: string): string {
  let s = html.replace(/<!--[\s\S]*?-->/g, "");
  // prefer the main content when the page marks it
  const main = /<(main|article)\b[^>]*>([\s\S]*?)<\/\1>/i.exec(s);
  if (main && main[2].replace(/<[^>]+>/g, "").trim().length > 400) s = main[2];
  s = s.replace(DROP, " ")
    .replace(/<([a-z0-9]+)\b[^>]*\b(?:hidden|aria-hidden=["']true["'])[^>]*>[\s\S]*?<\/\1>/gi, " ")
    // headings
    .replace(/<h([1-6])\b[^>]*>([\s\S]*?)<\/h\1>/gi, (_m, _l, t: string) => `\n\n# ${t.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()}\n\n`)
    // tables: one line per row, cells joined
    .replace(/<\/t[dh]>\s*/gi, " | ")
    .replace(/<tr\b[^>]*>/gi, "\n")
    .replace(/<\/tr>/gi, "\n")
    // blocks
    .replace(/<li\b[^>]*>/gi, "\n")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(p|div|section|li|ul|ol|blockquote|pre|table|dd|dt|figcaption|h[1-6])>/gi, "\n\n")
    .replace(/<[^>]+>/g, " ");
  s = decodeEntities(s);
  const lines = s.split("\n").map((l) => l.replace(/[ \t ]+/g, " ").replace(/\s*\|\s*$/, "").replace(/^\s*\|\s*/, "").trim());
  // drop short menu-like lines (a word or two) that are not headings, and repeated lines
  const seen = new Set<string>();
  const out: string[] = [];
  for (const l of lines) {
    if (!l) {
      if (out.length && out[out.length - 1] !== "") out.push("");
      continue;
    }
    const heading = l.startsWith("# ");
    if (!heading && l.split(/\s+/).length < 3 && !/[.!?:]$/.test(l) && !/\d/.test(l)) continue;
    if (seen.has(l)) continue;
    seen.add(l);
    out.push(l.replace(/ \| /g, ", "));
  }
  return out.join("\n").replace(/\n{3,}/g, "\n\n").trim();
}
