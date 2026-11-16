// O73 (Oscar moln, 2026-11-16): hållout-fall för K81 fetch-url (D204), skrivna innan jag läste Kevins testfall.
// Kör: cd backend && deno test --no-lock --no-check --allow-read ../scripts/qa/o73_fetch_url_test.ts
// Rena funktioner (checkUrl, checkResolved, publicIp) och handlern med falsk fetch och falsk DNS (inget nät).
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { BlockedUrl, checkResolved, checkUrl, publicIp } from "../../backend/supabase/functions/fetch-url/guard.ts";
import { createFetchUrlHandler } from "../../backend/supabase/functions/fetch-url/handler.ts";
import { MemoryRateLimiter } from "../../backend/supabase/functions/_shared/ratelimit.ts";

const OWN = ["xjczbzfkmbjdebwlccki.supabase.co"];
const reason = (f: () => unknown) => {
  try {
    f();
    return "ok";
  } catch (e) {
    return e instanceof BlockedUrl ? e.reason : `other:${e}`;
  }
};

Deno.test("O73 1: adresser som ska stoppas redan i checkUrl", () => {
  const blocked = [
    "http://0/", "http://0.0.0.0/", "http://127.1/", "http://0x7f000001/", "http://017700000001/", "http://2852039166/",
    "http://0251.0376.0251.0376/", "http://[::]/", "http://[::1]/", "http://[0:0:0:0:0:0:0:1]/", "http://[::ffff:127.0.0.1]/",
    "http://[::ffff:7f00:1]/", "http://[::ffff:a9fe:a9fe]/", "http://[fe80::1%25eth0]/", "http://[fd00::1]/", "http://[64:ff9b::a00:1]/",
    "http://LOCALHOST/", "http://localhost./", "http://foo.localhost/", "http://ｌｏｃａｌｈｏｓｔ/", "http://metadata/",
    "http://metadata.google.internal/", "http://router.lan/", "http://nas.home.arpa/", "http://intranet/",
    "http://100.64.0.1/", "http://198.18.0.1/", "http://192.0.0.8/", "http://224.0.0.1/", "http://255.255.255.255/",
    "https://xjczbzfkmbjdebwlccki.supabase.co/rest/v1/", "https://XJCZBZFKMBJDEBWLCCKI.SUPABASE.CO./", "https://a.xjczbzfkmbjdebwlccki.supabase.co/",
    "https://example.com:8443/", "http://example.com:0/", "https://user:pw@example.com/", "https://user@example.com/",
    "ftp://example.com/", "file:///etc/passwd", "gopher://example.com/", "data:text/html,hi", "javascript:alert(1)", "  ",
  ];
  const leaked = blocked.filter((u) => reason(() => checkUrl(u, OWN)) === "ok");
  assertEquals(leaked, [], `släpptes igenom: ${leaked.join(" ")}`);
});

Deno.test("O73 2: vanliga publika adresser släpps", () => {
  for (const u of ["https://sv.wikipedia.org/wiki/Fotosyntes", "http://example.com/", "https://example.com:443/a?b=c#d", "https://8.8.8.8/", "https://[2606:4700:4700::1111]/", "https://other-project.supabase.co/"]) {
    assertEquals(reason(() => checkUrl(u, OWN)), "ok", u);
  }
});

Deno.test("O73 3: IPv6-skrivsätt som bär en privat IPv4 (luckor?)", () => {
  // ::ffff:0:a.b.c.d (IPv4-översatt, RFC 2765), 6to4 (2002::/16) och lokal NAT64 (64:ff9b:1::/48) med 127.0.0.1 inbäddat
  const cases = { "::ffff:0:7f00:1": publicIp("::ffff:0:7f00:1"), "2002:7f00:1::": publicIp("2002:7f00:1::"), "64:ff9b:1::7f00:1": publicIp("64:ff9b:1::7f00:1") };
  console.log("O73 3 publicIp (true = räknas som publik):", JSON.stringify(cases));
  // registreras i rapporten; testet kräver inget här (se obs)
  assert(true);
});

Deno.test("O73 4: DNS som pekar på privata adresser stoppas, också blandat med publika", async () => {
  const u = checkUrl("https://evil.example.com/", OWN);
  for (const ips of [["10.0.0.5"], ["93.184.216.34", "127.0.0.1"], ["::ffff:169.254.169.254"], ["fd12::1"], ["0.0.0.0"]]) {
    let r = "ok";
    try {
      await checkResolved(u, () => Promise.resolve(ips));
    } catch (e) {
      r = e instanceof BlockedUrl ? e.reason : "other";
    }
    assertEquals(r, "private_address", JSON.stringify(ips));
  }
  let r = "ok";
  try {
    await checkResolved(u, () => Promise.resolve([]));
  } catch (e) {
    r = (e as BlockedUrl).reason;
  }
  assertEquals(r, "dns_failed");
});

// ---------- handlern med falsk fetch ----------
function handler(routes: Record<string, () => Response | Promise<Response>>, dns: Record<string, string[]> = {}) {
  const calls: string[] = [];
  const h = createFetchUrlHandler({
    authenticate: () => Promise.resolve({ id: "u1", isAnonymous: true }),
    rateLimiter: new MemoryRateLimiter(),
    resolve: (host) => Promise.resolve(dns[host] ?? ["93.184.216.34"]),
    ownHosts: OWN,
    fetchImpl: ((url: string, init?: RequestInit) => {
      calls.push(url);
      const f = routes[url];
      if (!f) return Promise.resolve(new Response("nope", { status: 404 }));
      return new Promise<Response>((res, rej) => {
        init?.signal?.addEventListener("abort", () => rej(new DOMException("aborted", "AbortError")));
        Promise.resolve(f()).then(res, rej);
      });
    }) as typeof fetch,
  });
  const post = (url: string) => h(new Request("http://x/fetch-url", { method: "POST", body: JSON.stringify({ url }) }));
  return { post, calls };
}
const page = (body: string, type = "text/html; charset=utf-8", extra: Record<string, string> = {}) => () =>
  new Response(body, { status: 200, headers: { "content-type": type, ...extra } });
const redirect = (to: string, status = 302) => () => new Response(null, { status, headers: { location: to } });
const TEXT = "<html><head><title>T</title></head><body><main><h1>Rubrik</h1><p>" + "Fotosyntesen gör socker av ljus. ".repeat(5) + "</p></main></body></html>";

Deno.test("O73 5: omdirigering till interna adresser stoppas innan de hämtas", async () => {
  for (const to of ["http://[::ffff:7f00:1]/", "http://127.1/", "http://localhost:80/", "http://0x7f000001/", "file:///etc/passwd", "http://user@a.example/", "https://xjczbzfkmbjdebwlccki.supabase.co/rest/v1/drills"]) {
    const w = handler({ "https://a.example/": redirect(to) });
    const r = await w.post("https://a.example/");
    const j = await r.json();
    assertEquals([r.status, j.error?.code], [400, "url_blocked"], `${to}: ${JSON.stringify(j)}`);
    assertEquals(w.calls.length, 1, `${to} hämtades: ${w.calls}`);
  }
});

Deno.test("O73 6: omdirigering via ett namn som pekar internt (DNS efter omdirigering)", async () => {
  const w = handler({ "https://a.example/": redirect("https://b.example/x") }, { "b.example": ["192.168.1.1"] });
  const j = await (await w.post("https://a.example/")).json();
  assertEquals([j.error?.code, j.reason], ["url_blocked", "private_address"]);
  assertEquals(w.calls.length, 1);
});

Deno.test("O73 7: relativ omdirigering och 3 hopp går, 4 hopp stoppas", async () => {
  const ok = handler({ "https://a.example/": redirect("/b"), "https://a.example/b": redirect("../c", 301), "https://a.example/c": redirect("https://d.example/", 307), "https://d.example/": page(TEXT) });
  const r = await ok.post("https://a.example/");
  const j = await r.json();
  assertEquals([r.status, j.url], [200, "https://d.example/"], JSON.stringify(j));
  const four = handler({ "https://a.example/": redirect("/1"), "https://a.example/1": redirect("/2"), "https://a.example/2": redirect("/3"), "https://a.example/3": redirect("/4"), "https://a.example/4": page(TEXT) });
  const k = await (await four.post("https://a.example/")).json();
  assertEquals(k.reason, "too_many_redirects", JSON.stringify(k));
});

Deno.test("O73 8: för stor sida, också utan content-length och med fel content-length", async () => {
  const big = "<p>" + "a".repeat(2 * 1024 * 1024 + 10) + "</p>";
  for (const extra of [{}, { "content-length": "100" }]) {
    const w = handler({ "https://a.example/": page(big, "text/html", extra) });
    const r = await w.post("https://a.example/");
    assertEquals(r.status, 413, JSON.stringify(extra));
  }
  const w = handler({ "https://a.example/": page("x", "text/html", { "content-length": String(3 * 1024 * 1024) }) });
  assertEquals((await w.post("https://a.example/")).status, 413);
});

Deno.test("O73 9: icke-HTML nekas, text/plain och xhtml går", async () => {
  for (const t of ["application/pdf", "image/png", "application/json", "application/octet-stream", "", "text/csv", "application/javascript"]) {
    const w = handler({ "https://a.example/": page(TEXT, t) });
    const r = await w.post("https://a.example/");
    assertEquals(r.status, 415, `"${t}"`);
  }
  for (const t of ["text/plain; charset=utf-8", "application/xhtml+xml", "TEXT/HTML"]) {
    const w = handler({ "https://a.example/": page(t.startsWith("text/plain") ? "Fotosyntesen gör socker av ljus. ".repeat(5) : TEXT, t) });
    assertEquals((await w.post("https://a.example/")).status, 200, t);
  }
});

Deno.test("O73 10: timeout ger url_unreachable inom cirka 10 s", async () => {
  const w = handler({ "https://a.example/": () => new Promise<Response>(() => {}) });
  const t0 = Date.now();
  const r = await w.post("https://a.example/");
  const ms = Date.now() - t0;
  const j = await r.json();
  assertEquals(j.error?.code, "url_unreachable");
  assert(ms >= 9_000 && ms < 12_000, `${ms} ms`);
});

Deno.test("O73 11: teckenkodning från meta och latin1, och tom JavaScript-sida", async () => {
  const latin = new Uint8Array([...new TextEncoder().encode('<html><head><meta charset="iso-8859-1"></head><body><p>'), ...Array.from("Växter gör socker av ljus i bladen, och det är fotosyntes. ".repeat(3)).map((c) => c.charCodeAt(0)), ...new TextEncoder().encode("</p></body></html>")]);
  const w = handler({ "https://a.example/": () => new Response(latin, { status: 200, headers: { "content-type": "text/html" } }) });
  const j = await (await w.post("https://a.example/")).json();
  assert(j.text?.includes("Växter gör socker"), JSON.stringify(j).slice(0, 200));
  const js = handler({ "https://a.example/": page('<html><body><div id="root"></div><script>render()</script></body></html>') });
  assertEquals((await (await js.post("https://a.example/")).json()).error?.code, "url_empty");
});
