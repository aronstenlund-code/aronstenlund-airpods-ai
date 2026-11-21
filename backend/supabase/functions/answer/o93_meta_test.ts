// O93 tillägg (Oscar 11:52, praktiskt-03): a new form of source talk said aloud before the answer.
import { assert } from "jsr:@std/assert@1.0.8";
import { isSearchMeta } from "./speech.ts";

Deno.test("O93: the model on its own sources ('ingen … källa i sökningen', 'jag bygger svaret på …') is never spoken", () => {
  for (const s of [
    "Det finns ingen officiell tillverkarkälla i sökningen, så jag bygger svaret på Clas Ohlsons guide.",
    "Jag bygger svaret på Biltemas guide.",
    "Det finns ingen officiell tillverkarkälla i sökningen.",
    "Sökningen gav ingen källa från tillverkaren.",
    "Jag hittade ingen officiell källa i sökresultaten.",
  ]) assert(isSearchMeta(s), s);
  for (const s of [
    "Det står inte i källorna jag hittade.", // the prompt's own sentence (WEB rule)
    "Sökningen visar att räntan är 2 procent.",
    "Lossa muttrarna innan du lyfter bilen.",
    "Han bygger ett hus på landet.",
    "Källan säger att bron öppnade 1998.",
  ]) assert(!isSearchMeta(s), s);
});
