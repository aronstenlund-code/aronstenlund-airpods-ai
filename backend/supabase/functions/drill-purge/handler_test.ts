import { assertEquals } from "jsr:@std/assert@1.0.8";
import { createPurgeHandler } from "./handler.ts";

Deno.test("K53 purge: only photos older than one hour are deleted", async () => {
  const removed: string[] = [];
  const now = Date.parse("2026-11-14T00:00:00Z");
  const h = createPurgeHandler({
    folders: () => Promise.resolve(["u1", "u2"]),
    files: (f) => Promise.resolve(f === "u1"
      ? [{ name: "a.jpg", created_at: "2026-11-13T22:30:00Z" }, { name: "b.jpg", created_at: "2026-11-13T23:30:00Z" }]
      : [{ name: "c.jpg", created_at: "2026-11-13T21:00:00Z" }]),
    remove: (p) => {
      removed.push(...p);
      return Promise.resolve();
    },
  }, () => now);
  const r = await h(new Request("http://x/drill-purge", { method: "POST" }));
  assertEquals(await r.json(), { deleted: 2 });
  assertEquals(removed, ["u1/a.jpg", "u2/c.jpg"]);
  assertEquals((await h(new Request("http://x/drill-purge"))).status, 405);
});
