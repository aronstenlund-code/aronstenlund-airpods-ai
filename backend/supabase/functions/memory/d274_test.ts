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

// Oscar D274 retest (2026-11-27 05:10): D1 spoken e-mail, D2 a 5+5 phone number, D3 a friend named without a relation.
Deno.test("D274 D1/D2: an e-mail address said aloud and a phone number grouped 5+5 are not kept", () => {
  for (const t of [
    "Mejl elev at example dot com", "Mejladress elev snabel-a example punkt com", "E-post anna punkt berg snabel a gmail punkt se",
    "Email student at school dot org", "Telefon 07012 34567.", "Nummer 07012 34567", "Mobil 0701-23 45 67.",
  ]) assertEquals(isSensitiveMemory(t), true, t);
  for (const t of ["Har prov i kemi fredag 4 december 2026.", "Tåget går klockan 17.40.", "Läser kapitel 3 at home", "Har 12 345 kronor sparade."]) {
    assertEquals(isSensitiveMemory(t), false, t);
  }
  assertEquals(kept('{"add":["Telefon 07012 34567.","Bor på 5 Baker Street."],"update":[],"remove":[]}'), [], "M21");
  assertEquals(kept('{"add":["Mejl elev at example dot com."],"update":[],"remove":[]}'), [], "M19");
});

Deno.test("D274 D3: a person the wearer named with a relation is held to name and relation, even when the memory uses only the name", () => {
  const q = "min kompis Elias är arbetslös";
  assertEquals(parseMemoryReply('{"add":["Elias är arbetslös."],"update":[],"remove":[]}', [], q).add, [], "M24");
  assertEquals(parseMemoryReply('{"add":["Elias jobbar på ICA."],"update":[],"remove":[]}', [], "min bror heter Elias och jobbar på ICA").add, []);
  assertEquals(parseMemoryReply('{"add":["Sara har gjort slut med Leo."],"update":[],"remove":[]}', [], "my best friend Sara broke up with Leo").add, []);
  // Name and relation are kept; so is the wearer's own memory that mentions the friend.
  assertEquals(parseMemoryReply('{"add":["Kompisen heter Elias."],"update":[],"remove":[]}', [], q).add, ["Kompisen heter Elias."]);
  assertEquals(parseMemoryReply('{"add":["Elias är bästa kompisen."],"update":[],"remove":[]}', [], "min bästa kompis heter Elias").add, ["Elias är bästa kompisen."]);
  assertEquals(
    parseMemoryReply('{"add":["Pluggar med Elias på tisdagar."],"update":[],"remove":[]}', [], "jag pluggar med min kompis Elias på tisdagar").add,
    ["Pluggar med Elias på tisdagar."],
  );
  // Without a turn (old callers) nothing changes.
  assertEquals(parseMemoryReply('{"add":["Pluggar med Elias."],"update":[],"remove":[]}', []).add, ["Pluggar med Elias."]);
});
