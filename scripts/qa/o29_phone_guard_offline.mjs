// Oscar QA, O29: the phone-number guard (D65/K13, answer/speechsym.ts guardPhoneNumbers via toSpeech): the model
// must never say a phone number from memory; only 112, 1177 and 114 14 (police) pass, spoken as people say them.
// Offline and free in Node 24 with the deployed files.
//   node --experimental-transform-types scripts/qa/o29_phone_guard_offline.mjs > reports/qa/data/<stamp>-o29-phone.json
import { toSpeech } from "../../backend/supabase/functions/answer/speech.ts";
const PH = "numret som står på deras webbplats";
const C = [ // [model text, "replace" | "keep" | expected spoken words]
  ["Ring kundtjänst på 0771-123 456.", "replace"], ["Ring 08-123 45 67 för att boka.", "replace"],
  ["Numret är 070 123 45 67.", "replace"], ["Du når dem på +46 70 123 45 67.", "replace"],
  ["Giftinformationscentralen har 010-456 67 00.", "replace"], ["Skicka sms till 72456 för att skänka.", "replace"],
  ["Bris nås på 116 111.", "replace"], ["Självmordslinjen nås på 90101.", "replace"], ["Swisha till 123 456 78 90.", "replace"],
  ["Ring 112 om det är akut.", "ett ett två"], ["Ring 1177 för råd.", "elva sjuttiosju"],
  ["Ring polisen på 114 14 om det inte är akut.", "ett ett fyra, ett fyra"],
  ["Läs sidan 112 i boken.", "hundratolv"], ["Nummer 112 i listan är Kina.", "hundratolv"],
  ["Telefonen uppfanns 1876.", "artonhundrasjuttiosex"], ["Telefonen kostar 12 999 kr.", "tolvtusen"],
  ["Atomnummer 26 är järn.", "tjugosex"], ["Nummer 10 i laget heter Messi.", "tio"],
  ["Ett telefonnummer har 10 siffror.", "tio siffror"], ["Ring din mormor, hon fyller 85 den 12 maj.", "åttiofem"],
  ["Ring 112 om någon har tagit 20 tabletter.", "tjugo tabletter"],
  ["Numret till växeln står på 1177.se.", "keep"],
];
const rows = C.map(([t, want]) => {
  const out = toSpeech(t);
  const replaced = out.includes(PH);
  const ok = want === "replace" ? replaced : want === "keep" ? !replaced : !replaced && out.toLowerCase().includes(want);
  return { t, want, out, replaced, ok };
});
console.log(JSON.stringify({ n: rows.length, ok: rows.filter((r) => r.ok).length, fails: rows.filter((r) => !r.ok), rows }, null, 1));
