// Oscar O22 (new phrasings: corrections 4/20, commands 3/10) and Kevin's own hold-out, written after the change.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { detectCorrection } from "./settings.ts";
import { detectAppCommand } from "../answer/appcommand.ts";

const g = (t: string) => {
  const r = detectCorrection(t);
  return r ? `${r.key}:${r.value}` : null;
};

Deno.test("O22 corrections in own words (Oscar's 20 + hold-out), no false hits", () => {
  for (const [t, w] of [
    ["asså det där var alldeles för långt", "length:shorter"], ["orka lyssna på så långa svar", "length:shorter"], ["säg det på typ en mening", "length:shorter"],
    ["Lumen, du snackar för mycket", "length:shorter"], ["mindre prat", "length:shorter"], ["kan du förklara lite mer", "length:longer"],
    ["det där var för lite", "length:longer"], ["gå in mer på djupet", "length:longer"], ["jag hänger inte med", "simplicity:simpler"],
    ["förklara som om jag var tio", "simplicity:simpler"], ["med enklare ord tack", "simplicity:simpler"], ["fattar ingenting", "simplicity:simpler"],
    ["det var för avancerat", "simplicity:simpler"], ["exempel hade varit nice", "examples:more"], ["du sa fel", "accuracy:careful"],
    ["det är ju inte sant", "accuracy:careful"],
    // hold-out
    ["för långt asså", "length:shorter"], ["du babblar för mycket", "length:shorter"], ["säg det med två ord", "length:shorter"],
    ["berätta gärna mer", "length:longer"], ["gå djupare", "length:longer"], ["det var alldeles för komplicerat", "simplicity:simpler"],
    ["på ett enklare sätt tack", "simplicity:simpler"], ["ett exempel hade hjälpt", "examples:more"], ["du säger fel", "accuracy:careful"],
  ]) assertEquals(g(t), w, t);
  for (const t of ["vilken är längst, Nilen eller Amazonas", "vad är ett bra exempel på en metafor", "jag fattar inte varför hon är sur",
    "det var för långt att cykla till skolan", "jag hänger inte med i matten i skolan, vad ska jag göra", "för kort kjol enligt mamma",
    "du har fel strumpor på dig", "det var för långt för mig att springa", "jag fattar inte vad min lärare menar med det",
    "för lite sömn är farligt", "han säger fel saker hela tiden", "mer exempel på verb i preteritum"]) assertEquals(g(t), null, t);
});

Deno.test("O22 app commands in own words: Standardläge's new name, paus, vänta lite, du kan sluta nu, intervju", () => {
  const a = (m: Parameters<typeof detectAppCommand>[1], t: string) => detectAppCommand(t, m);
  assertEquals(a("prov", "byt till frågor")?.mode, "fragor");
  assertEquals(a("prov", "byt till standardläge")?.mode, "fragor");
  assertEquals(a("fragor", "nu ska jag plugga")?.mode, "prov");
  assertEquals(a("prov", "vänta lite")?.action, "pause");
  assertEquals(a("prov", "paus")?.action, "pause");
  assertEquals(a("fragor", "du kan sluta nu")?.action, "stop");
  assertEquals(a("fragor", "jag ska på intervju, kan vi öva")?.mode, "intervju");
  for (const [m, t] of [["prov", "vänta, var det tre eller fyra"], ["fragor", "vad är standardläget i appen"], ["prov", "byt till frågor om andra världskriget"],
    ["fragor", "när ska man sluta äta innan träning"], ["socialt", "han sa stäng av musiken"]] as const) assert(!a(m, t), t);
  assertEquals(a("socialt", "stäng av"), null, "in Socialt other people talk: a command needs 'Lumen' (A7/A9)");
});
