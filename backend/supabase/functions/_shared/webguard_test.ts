// K114 (D249): the web beta (earmind.vercel.app/beta) without closing it: at most WEB accounts per network and day, and
// the web's credits capped per network and in all per day. The iOS app (no Origin header) is never counted.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { MemoryRateLimiter } from "./ratelimit.ts";
import { isWebRequest, WEB_LIMITS, webCredits, withWebGuard } from "./webguard.ts";
import { originAllowed } from "./cors.ts";

const jwt = (sub: string) => `x.${btoa(JSON.stringify({ sub })).replace(/=+$/, "")}.y`;
const req = (o: { origin?: string; sub?: string; ip?: string }) =>
  new Request("http://x/drill", { method: "POST", headers: { ...(o.origin ? { origin: o.origin } : {}), ...(o.sub ? { authorization: `Bearer ${jwt(o.sub)}` } : {}), "x-forwarded-for": o.ip ?? "203.0.113.7" }, body: "{}" });

Deno.test("K114: the beta's address and the project's own Vercel previews are web; other projects never", () => {
  for (const o of ["https://earmind.vercel.app", "https://earmind-fsorpitca-aron-cfdc.vercel.app", "https://earmind-git-claude-eager-tesla-9u6jyi-aron-cfdc.vercel.app"]) {
    assert(isWebRequest(req({ origin: o })), o);
    assert(originAllowed(o), `CORS ${o}`);
  }
  for (const o of ["https://earmind-evil.vercel.app", "https://earmind-x-aron-cfdc.vercel.app.evil.com", "https://evil-aron-cfdc.vercel.app"]) assert(!originAllowed(o), o);
  assertEquals(isWebRequest(req({})), false, "the iOS app sends no Origin");
});

Deno.test("K114: at most WEB_LIMITS.accountsPerIpPerDay web accounts per network and day; an admitted one stays admitted", async () => {
  const rl = new MemoryRateLimiter();
  const inner = () => Promise.resolve(new Response("ok"));
  const h = withWebGuard(inner, { limiter: rl });
  for (let i = 0; i < WEB_LIMITS.accountsPerIpPerDay; i++) assertEquals((await h(req({ origin: "https://earmind.vercel.app", sub: `u${i}` }))).status, 200);
  const over = await h(req({ origin: "https://earmind.vercel.app", sub: "u-new" }));
  assertEquals(over.status, 429);
  const j = await over.json();
  assertEquals(j.error.code, "too_many_accounts");
  assert(/connection|anslutning/.test(j.error.message));
  assertEquals((await h(req({ origin: "https://earmind.vercel.app", sub: "u0" }))).status, 200, "an admitted account goes on");
  assertEquals((await h(req({ origin: "https://earmind.vercel.app", sub: "u-other", ip: "198.51.100.9" }))).status, 200, "another network");
  assertEquals((await h(req({ sub: "u-app" }))).status, 200, "the app is never counted");
});

Deno.test("K114: the web's credits are capped per network and in all per day; the app's never", async () => {
  const rl = new MemoryRateLimiter();
  const inner = async () => {
    const r = await webCredits(rl, 1000);
    return new Response(JSON.stringify(r), { status: r.allowed ? 200 : 429 });
  };
  const h = withWebGuard(inner, { limiter: rl });
  let ok = 0;
  for (let i = 0; i < 10; i++) if ((await h(req({ origin: "https://earmind.vercel.app", sub: `a${i % 3}` }))).status === 200) ok++;
  assertEquals(ok, Math.floor(WEB_LIMITS.creditsPerIpPerDay / 1000), "per network");
  assertEquals((await h(req({ sub: "app" }))).status, 200, "the app's credits are not web credits");
  assert(WEB_LIMITS.creditsGlobalPerDay >= WEB_LIMITS.creditsPerIpPerDay);
});
