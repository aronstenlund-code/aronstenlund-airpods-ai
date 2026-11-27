// D274 (Deangelo, within D113; Oscar O107 M-2/M-3): contact details (phone, e-mail, street address) are never kept,
// and about other people only name and relation are kept – never their health, work/money, relationships or other
// private circumstances. Checked in code, not only in the prompt.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { isSensitiveMemory, parseMemoryReply, SYSTEM_PROMPT_MEMORY } from "./handler.ts";

const kept = (reply: string) => parseMemoryReply(reply, []).add;

Deno.test("D274 Oscar M8–M11: phone, street address, e-mail and a parent's job are not kept", () => {
  assertEquals(kept('{"add":["Mobilnummer 070-123 45 67."],"update":[],"remove":[]}'), [], "M8");
  assertEquals(kept('{"add":["Bor på Storgatan 12 i Uppsala."],"update":[],"remove":[]}'), [], "M9");
  assertEquals(kept('{"add":["Mejladress elev.test@example.com."],"update":[],"remove":[]}'), [], "M10");
  assertEquals(kept('{"add":["Pappan heter Johan och är arbetslös."],"update":[],"remove":[]}'), [], "M11");
  // An update to a contact detail is dropped too.
  assertEquals(parseMemoryReply('{"add":[],"update":[{"old":"Har prov i kemi fredag 4 december 2026.","new":"Telefon 0701234567."}],"remove":[]}', ["Har prov i kemi fredag 4 december 2026."]).update, []);
});

Deno.test("D274: contact details in Swedish and English, written in different ways", () => {
  for (const t of [
    "Mobilnummer 0701234567", "Telefon +46 70 123 45 67", "Nås på 08-123 456 78", "Telefonnumret är 073 12 34 567",
    "Phone number +1 555 123 4567", "His number is (555) 123-4567",
    "Mejl: elev@skolan.se", "E-postadress anna.b+skola@gmail.com", "Email is student@example.org",
    "Bor på Storgatan 12 i Uppsala", "Bor på Kungsvägen 3B", "Adress: Lilla Torget 4, 411 18 Göteborg", "Hemadressen är Björkstigen 7",
    "Gatuadress Ringvägen 21", "Postnummer 752 36", "Lives at 221B Baker Street", "Home address 12 Oak Road",
  ]) assertEquals(isSensitiveMemory(t), true, t);
});

Deno.test("D274: other people – only name and relation are kept", () => {
  for (const t of [
    "Pappan heter Johan och är arbetslös", "Mamman jobbar som sjuksköterska", "Brodern har skulder", "Kompisen Elias är kär i Sara",
    "Systern har gjort slut med sin pojkvän", "Föräldrarna är skilda", "Mormor bor i Lund", "Har en bror som heter Elias och sitter i fängelse",
    "Bästa kompisen Sara tjänar mycket pengar", "Pappa röstar på ett parti", "His mother lost her job", "Morfar fick sparken",
  ]) assertEquals(isSensitiveMemory(t), true, t);
  for (const t of [
    "Brodern heter Elias", "Pappan heter Johan", "Har en syster som heter Maja", "Bästa kompisen heter Sara Lind", "Läraren i matte heter Eva",
    "Pluggar med kompisen Elias på tisdagar", "Har prov i kemi fredag 4 december 2026", "Bor i Uppsala", "Jobbar extra på helgerna",
    "Vill ha korta svar", "Tåget går klockan 17.40", "Har mattebok Matte 5000 kapitel 3", "Har 50 000 kronor sparade", "Går i klass 9B på Kungsholmen",
    "Har prov i samhällskunskap om arbetslöshet", "Läser om familjen i svenska",
  ]) assertEquals(isSensitiveMemory(t), false, t);
});

Deno.test("D274: the prompt says the same rule", () => {
  assert(/phone numbers, e-mail addresses (?:and|or) street addresses/.test(SYSTEM_PROMPT_MEMORY));
  assert(/other people[^.]*name and relation/.test(SYSTEM_PROMPT_MEMORY));
  assert(/never their health, work, money, relationships or other private circumstances/.test(SYSTEM_PROMPT_MEMORY));
});
