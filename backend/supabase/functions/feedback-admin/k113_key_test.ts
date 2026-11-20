// Reported cases (K4.3) failed every day since at least 2026-11-15 with 401: the edge log shows the function ran and
// refused the repo secret's legacy service_role JWT (the gateway accepted it as service_role), because the function
// compared it with the different service key the runtime injects. As voice-lab (K6): any key the database treats as the
// service role is accepted, verified by a call only a service key can make; a wrong key is still 401.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { createAdminHandler } from "./handler.ts";

const rows = [{ id: "a", type: "report" }];
function h(verify?: (k: string) => Promise<boolean>) {
  return createAdminHandler({ serviceKey: "sb_secret_runtimekey", select: () => Promise.resolve(rows), ...(verify ? { verifyServiceKey: verify } : {}) });
}
const get = (key: string) => new Request("http://x/feedback-admin?type=report&limit=40", { headers: { authorization: `Bearer ${key}` } });

Deno.test("feedback-admin: the runtime's own key still works without a database check", async () => {
  let asked = 0;
  const r = await h(() => (asked++, Promise.resolve(false)))(get("sb_secret_runtimekey"));
  assertEquals(r.status, 200);
  assertEquals(asked, 0);
});

Deno.test("feedback-admin: another valid service key (the repo's legacy JWT) is accepted when the database says it is one", async () => {
  const legacy = "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.sig";
  const r = await h((k) => Promise.resolve(k === legacy))(get(legacy));
  assertEquals(r.status, 200);
  assertEquals((await r.json()).length ?? 1, 1);
});

Deno.test("feedback-admin: any other key is still 401", async () => {
  assertEquals((await h(() => Promise.resolve(false))(get("eyJ.wrong.key"))).status, 401);
  assertEquals((await h()(get("eyJ.wrong.key"))).status, 401);
  assertEquals((await h(() => Promise.resolve(true))(new Request("http://x/feedback-admin"))).status, 401, "no bearer, no call");
});

Deno.test("serviceKeyVerifier: 200 from the service-only table = a service key (remembered); 401 or a malformed key = not", async () => {
  const { serviceKeyVerifier } = await import("../_shared/servicekey.ts");
  let calls = 0;
  const good = "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.c2ln";
  const v = serviceKeyVerifier("https://x.supabase.co", ((_u: string, init?: RequestInit) => {
    calls++;
    const h = init?.headers as Record<string, string>;
    return Promise.resolve(new Response("[]", { status: h.apikey === good ? 200 : 401 }));
  }) as typeof fetch);
  assertEquals(await v(good), true);
  assertEquals(await v(good), true);
  assertEquals(calls, 1, "remembered");
  assertEquals(await v("eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.c2ln"), false);
  assertEquals(await v("not a key"), false);
  assertEquals(calls, 2, "a malformed key is never sent");
});
