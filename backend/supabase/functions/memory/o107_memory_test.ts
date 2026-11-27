// O107 (Oscar): M-1 health slipped through the memory filter ("Tar penicillin", "Har hörselnedsättning", "Går på KBT",
// D113 B5). M-2 (phone, address, e-mail) is not stopped: D113 A5 (owner) allows them; reported to Deangelo.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { isSensitiveMemory } from "./handler.ts";

Deno.test("O107 M-1: health is never kept (D113 B5); ordinary memories are; phone, e-mail and address stay allowed (D113 A5)", () => {
  for (const t of ["Tar penicillin mot halsfluss", "Har hörselnedsättning på vänster öra", "Går på KBT varje tisdag", "Äter antibiotika", "Har en EpiPen"]) {
    assertEquals(isSensitiveMemory(t), true, t);
  }
  for (const t of ["Har prov i kemi på onsdag", "Brodern heter Elias", "Går andra året på naturprogrammet", "Tåget går klockan 17.40", "Vill ha korta svar", "Bor på Storgatan 12 i Lund"]) {
    assertEquals(isSensitiveMemory(t), false, t);
  }
});

Deno.test("O107 M-4: a change to something already remembered reaches the model without 'jag/min'; small talk still does not", async () => {
  const { createMemoryHandler } = await import("./handler.ts");
  const { MemoryRateLimiter } = await import("../_shared/ratelimit.ts");
  let calls = 0;
  const h = createMemoryHandler({
    authenticate: () => Promise.resolve({ id: "u-m4", isAnonymous: true }), rateLimiter: new MemoryRateLimiter(),
    provider: { name: "f", model: "f", stream: () => (calls++, (async function* () { yield { type: "text" as const, text: '{"add": [], "update": [{"old": "Har prov i kemi onsdag 2 december 2026.", "new": "Har prov i kemi onsdag 9 december 2026."}], "remove": []}' }; })()) },
    recordUsage: () => {}, now: () => new Date("2026-11-27T10:00:00Z"),
  });
  const post = (q: string, memories: string[]) => h(new Request("http://x/memory", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ turn: { q }, memories }) })).then((r) => r.json());
  const moved = await post("provet i kemi är flyttat till nästa onsdag", ["Har prov i kemi onsdag 2 december 2026."]);
  assertEquals(calls, 1);
  assertEquals(moved.update.length, 1);
  const chat = await post("det regnar idag", ["Har prov i kemi onsdag 2 december 2026."]);
  assertEquals([calls, chat.skipped], [1, "no_self_reference"]);
  const other = await post("provet i fysik är flyttat", ["Har prov i kemi onsdag 2 december 2026."]);
  assertEquals(other.skipped, "no_self_reference", "a change to something not remembered is not about the wearer");
});
