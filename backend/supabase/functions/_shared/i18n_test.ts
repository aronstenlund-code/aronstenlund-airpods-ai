// K114 (D251): English by default, Swedish when the device/browser says Swedish. The server's messages to the user are
// Swedish in the code; for anyone else withCors gives the English one (the iOS app and the browser send Accept-Language).
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { english, userLang } from "./i18n.ts";
import { withCors } from "./cors.ts";
import { errorResponse, HttpError } from "./errors.ts";

const r = (h: Record<string, string>) => new Request("http://x/drill", { method: "POST", headers: h });

Deno.test("K114: the user's language from x-earmind-lang or Accept-Language; English by default", () => {
  assertEquals(userLang(r({ "accept-language": "sv-SE,sv;q=0.9,en;q=0.8" })), "sv");
  assertEquals(userLang(r({ "accept-language": "en-GB,en;q=0.9" })), "en");
  assertEquals(userLang(r({ "accept-language": "de-DE" })), "en");
  assertEquals(userLang(r({})), "en");
  assertEquals(userLang(r({ "accept-language": "en-US", "x-earmind-lang": "sv" })), "sv");
});

Deno.test("K114: every Swedish message the user can meet has an English one, also those with numbers", () => {
  for (const sv of ["Du behöver logga in igen.", "Provet finns inte längre.", "Något gick fel hos EarMind. Försök igen om en stund.", "Välkomstkrediterna är inte på än.", "Du har många prov sparade. Ta bort några gamla först.", "För många försök just nu. Vänta en liten stund."]) {
    const en = english(sv);
    assert(en && !/[åäö]/i.test(en), `${sv} -> ${en}`);
  }
  assertEquals(english("Det här kostar 5 882 krediter. Du har 1 259 kvar. Nya krediter den 1 december."), "This costs 5 882 credits. You have 1 259 left. New credits on 1 December.");
  assertEquals(english("Ett prov med 12 frågor kostar cirka 7 704 krediter. Du har 1 500 kvar, det räcker inte till ett prov (minst 3 frågor). Nya krediter den 1 december."),
    "An exam with 12 questions costs about 7 704 credits. You have 1 500 left, not enough for an exam (at least 3 questions). New credits on 1 December.");
  assertEquals(english("Dela när ljudet är klart (3 av 6)"), "Share when the audio is ready (3 of 6)");
});

Deno.test("K114: withCors gives the English message to an English user, the Swedish one to a Swedish user; 200s untouched", async () => {
  const h = withCors(() => Promise.resolve(errorResponse(new HttpError(404, "not_found", "Provet finns inte längre."))));
  const en = await (await h(r({ "accept-language": "en-US" }))).json();
  assertEquals(en.error.message, "This exam is no longer there.");
  assertEquals(en.error.code, "not_found");
  const sv = await (await h(r({ "accept-language": "sv-SE" }))).json();
  assertEquals(sv.error.message, "Provet finns inte längre.");
  const ok = withCors(() => Promise.resolve(Response.json({ text: "Svar på svenska" })));
  assertEquals((await (await ok(r({ "accept-language": "en" }))).json()).text, "Svar på svenska");
});
