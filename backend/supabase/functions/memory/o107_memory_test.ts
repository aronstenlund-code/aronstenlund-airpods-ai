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
