import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { guardPhoneNumbers, PHONE_PLACEHOLDER } from "./speechsym.ts";
import { needsText } from "./web.ts";

Deno.test("K13 (O10 #6) large numbers are never taken for phone numbers; real ones still are", () => {
  for (const t of [
    "På cirka hundra dagar dödades omkring 800 000 människor.",
    "Efter larmet evakuerades 12 000 personer.",
    "Under jourtiden kom 25 000 besökare.",
    "Det såldes 1 000 000 telefoner.",
  ]) assertEquals(guardPhoneNumbers(t), t, t);
  assert(guardPhoneNumbers("Ring kundtjänsten på 0771-23 45 67.").includes(PHONE_PLACEHOLDER));
  assert(guardPhoneNumbers("Numret är 08 123 456 78.").includes(PHONE_PLACEHOLDER));
});

Deno.test("K13 (O10 #8) 'första raden' goes to the text path", () => {
  for (const f of ["vad är första raden i Du gamla du fria", "citera första raden", "första raden i Imagine"]) assert(needsText(f), f);
});
