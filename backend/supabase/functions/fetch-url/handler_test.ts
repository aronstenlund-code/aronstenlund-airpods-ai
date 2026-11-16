// K81 (D204): fetch-url with a fake network and fake DNS. Invented pages only; nothing leaves the test.
import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "../_shared/ratelimit.ts";
import { BlockedUrl, checkUrl, publicIp } from "./guard.ts";
import { createFetchUrlHandler } from "./handler.ts";
import { htmlToText, pageTitle } from "./html.ts";

const PAGE = `<!doctype html><html><head><title>Fotosyntes – Biologi</title><script>alert(1)</script><style>p{}</style></head>
<body><nav><a href="/">Hem</a> <a href="/om">Om oss</a></nav><main>
<h1>Fotosyntes</h1><p>Växter bildar socker av koldioxid och vatten med hjälp av ljus. Syre blir över.</p>
<h2>Var sker den?</h2><ul><li>I kloroplasterna, som finns i bladens celler.</li><li>Klorofyllet fångar ljuset.</li></ul>
<table><tr><th>Ämne</th><th>Formel</th></tr><tr><td>Koldioxid</td><td>CO2</td></tr><tr><td>Glukos</td><td>C6H12O6</td></tr></table>
<p hidden>Gömd text som inte ska med.</p><p>Fotosyntesen är grunden för nästan alla näringskedjor på jorden &amp; i havet.</p>
</main><footer>© 2026 Påhittad skola</footer></body></html>`;

Deno.test("K81 html to text: headings, paragraphs, list items, table rows; no script, nav, footer or hidden text", () => {
  const t = htmlToText(PAGE);
  assert(t.includes("# Fotosyntes") && t.includes("# Var sker den?"), t);
  assert(t.includes("Växter bildar socker av koldioxid och vatten med hjälp av ljus."));
  assert(t.includes("I kloroplasterna, som finns i bladens celler."));
  assert(t.includes("Koldioxid, CO2") && t.includes("Glukos, C6H12O6"), t);
  assert(t.includes("jorden & i havet"));
  for (const bad of ["alert", "Hem", "Om oss", "Gömd", "©", "p{}"]) assert(!t.includes(bad), `${bad} in ${t}`);
  assertEquals(pageTitle(PAGE), "Fotosyntes – Biologi");
});

Deno.test("K81 SSRF: only public http/https on default ports; internal names and every private address form refused", () => {
  const blocked: [string, string][] = [
    ["file:///etc/passwd", "scheme"], ["ftp://example.com/x", "scheme"], ["gopher://example.com", "scheme"], ["javascript:alert(1)", "scheme"],
    ["http://127.0.0.1/", "private_address"], ["http://10.0.0.5/", "private_address"], ["http://172.16.3.4/", "private_address"],
    ["http://192.168.1.1/", "private_address"], ["http://169.254.169.254/latest/meta-data/", "private_address"],
    ["http://0.0.0.0/", "private_address"], ["http://100.64.0.1/", "private_address"], ["http://[::1]/", "private_address"],
    ["http://[::ffff:127.0.0.1]/", "private_address"], ["http://[fd00::1]/", "private_address"], ["http://[fe80::1]/", "private_address"],
    ["http://2130706433/", "private_address"], ["http://0x7f.0.0.1/", "private_address"], ["http://0177.0.0.1/", "private_address"], // URL normalises them to 127.0.0.1
    ["http://localhost/", "internal_name"], ["http://intranet/", "internal_name"], ["http://db.internal/", "internal_name"],
    ["http://metadata.google.internal/", "internal_name"], ["http://printer.local/", "internal_name"],
    ["http://example.com:22/", "port"], ["https://example.com:8443/", "port"], ["http://user:pw@example.com/", "userinfo"],
    ["https://abc.supabase.co/rest/v1/", "own_host"],
    // K84 (Oscar O73): an IPv4 address inside IPv6 (translated, 6to4), Teredo and the discard prefix
    ["http://[::ffff:0:7f00:1]/", "private_address"], ["http://[2002:7f00:1::]/", "private_address"], ["http://[2002:a9fe:a9fe::]/", "private_address"],
    ["http://[2001:0:4136:e378::1]/", "private_address"], ["http://[100::1]/", "private_address"], ["not a url", "invalid_url"],
  ];
  for (const [u, reason] of blocked) {
    const e = assertThrows(() => checkUrl(u, ["supabase.co"]), BlockedUrl, undefined, u);
    assertEquals(e.reason, reason, u);
  }
  assertEquals(checkUrl("https://sv.wikipedia.org/wiki/Fotosyntes").hostname, "sv.wikipedia.org");
  assertEquals(checkUrl("http://93.184.216.34/").hostname, "93.184.216.34");
  assertEquals(publicIp("8.8.8.8"), true);
  assertEquals(publicIp("2606:4700::1111"), true);
  assertEquals(publicIp("2002:5db8:d822::1"), true, "6to4 of a public IPv4 is public");
});

function setup(pages: Record<string, () => Response>, dns: Record<string, string[]> = {}) {
  const fetched: string[] = [];
  const h = createFetchUrlHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    resolve: (host) => Promise.resolve(dns[host] ?? ["93.184.216.34"]),
    ownHosts: ["supabase.co"],
    fetchImpl: ((url: string) => {
      fetched.push(String(url));
      const p = pages[String(url)];
      return Promise.resolve(p ? p() : new Response("nope", { status: 404 }));
    }) as typeof fetch,
  });
  const call = async (url: string) => {
    const r = await h(new Request("http://x/fetch-url", { method: "POST", body: JSON.stringify({ url }) }));
    return { status: r.status, body: await r.json() };
  };
  return { call, fetched };
}
const html = (s: string) => () => new Response(s, { headers: { "content-type": "text/html; charset=utf-8" } });

Deno.test("K81 a page is read: final url, title, text, chars", async () => {
  const { call } = setup({ "https://skola.example/fotosyntes": html(PAGE) });
  const r = await call("https://skola.example/fotosyntes");
  assertEquals(r.status, 200);
  assertEquals(r.body.title, "Fotosyntes – Biologi");
  assert(r.body.text.startsWith("# Fotosyntes"));
  assertEquals(r.body.chars, r.body.text.length);
});

Deno.test("K81 a redirect to an internal address is refused before it is fetched; more than 3 redirects stop", async () => {
  const s = setup({
    "https://a.example/": () => new Response(null, { status: 302, headers: { location: "http://169.254.169.254/latest/meta-data/" } }),
  });
  const r = await s.call("https://a.example/");
  assertEquals(r.status, 400);
  assertEquals(r.body.error.code, "url_blocked");
  assertEquals(r.body.reason, "private_address");
  assertEquals(s.fetched, ["https://a.example/"], "the metadata address was never fetched");
  // a name that resolves to a private address (DNS) is refused too, also after a redirect
  const d = setup({ "https://b.example/": () => new Response(null, { status: 301, headers: { location: "https://evil.example/" } }) }, { "evil.example": ["10.1.2.3"] });
  const r2 = await d.call("https://b.example/");
  assertEquals(r2.body.reason, "private_address");
  assertEquals(d.fetched, ["https://b.example/"]);
  const loop: Record<string, () => Response> = {};
  for (let i = 0; i < 5; i++) loop[`https://c.example/${i}`] = () => new Response(null, { status: 302, headers: { location: `/${i + 1}` } });
  const r3 = await setup(loop).call("https://c.example/0");
  assertEquals(r3.body.error.code, "url_unreachable");
  assertEquals(r3.body.reason, "too_many_redirects");
});

Deno.test("K81 too large, not text, empty and unreachable pages get their own codes", async () => {
  const big = "<p>" + "Fotosyntes är viktig. ".repeat(110_000) + "</p>";
  const s = setup({
    "https://big.example/": html(big),
    "https://pdf.example/": () => new Response("%PDF-1.4", { headers: { "content-type": "application/pdf" } }),
    "https://app.example/": html("<html><body><div id=root></div><script>render()</script></body></html>"),
    "https://down.example/": () => new Response("err", { status: 503 }),
  });
  assertEquals((await s.call("https://big.example/")).body.error.code, "url_too_large");
  assertEquals((await s.call("https://pdf.example/")).body.error.code, "url_not_text");
  assertEquals((await s.call("https://app.example/")).body.error.code, "url_empty");
  assertEquals((await s.call("https://down.example/")).body.error.code, "url_unreachable");
  assertEquals((await s.call("ftp://x.example/")).body.error.code, "url_blocked");
});
