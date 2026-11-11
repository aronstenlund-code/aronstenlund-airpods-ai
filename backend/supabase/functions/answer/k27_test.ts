// K27: Oscar's O24 (questions about Lumen), O30 (echo vs a quote in a follow-up) and O31 (link requests), offline.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { selfAnswer, SELF_TEXT, selfTopic } from "./self.ts";
import { stripEcho } from "./echo.ts";
import { isResourceRequest, resourceTopic } from "./resource.ts";

Deno.test("K27 O24 + O34: questions about Lumen are recognised by content and answered by what is asked", () => {
  const topic = selfTopic;
  for (const [t, want] of [
    ["är du en AI", "robot"], ["Lumen, är du en människa eller en robot", "robot"], ["är det chatgpt", "which_ai"],
    ["vilken AI är du", "which_ai"], ["vem har gjort dig", "who_made"], ["är du på riktigt eller", "robot"],
    ["lyssnar du på mig nu", "listen"], ["hör du allt jag säger", "listen"], ["spelar du in lektionen", "listen"],
    ["lyssnar du när appen är stängd", "listen"], ["kan du höra mig när skärmen är släckt", "listen"],
    ["spelar du in det här", "listen"], ["asså lyssnar du hela tiden", "listen"],
    ["sparar du mina frågor", "save"], ["vem ser det jag frågar", "who_sees"], ["kan läraren se vad jag frågar", "who_sees"],
    ["sparas det jag säger", "audio"], ["säljer ni min data", "sell"], ["vart skickas ljudet", "audio"],
    ["kan mina föräldrar läsa mina frågor", "who_sees"],
    // O36 misses
    ["hör du vad min lärare säger", "listen"], ["är du typ en bot", "robot"], ["vem programmerade dig", "who_made"],
    ["kan någon annan läsa det här", "who_sees"], ["tar du upp ljud i bakgrunden", "audio"],
  ]) assertEquals(topic(t), want, t);
  // O16: never "ljud sparas inte" (ElevenLabs keeps Scribe sessions on our plan); every audio answer names ElevenLabs
  for (const k of ["listen", "audio", "save"] as const) assert(SELF_TEXT[k].includes("ElevenLabs"), k);
  assert(!Object.values(SELF_TEXT).some((x) => /ljud sparas inte/i.test(x)));
  assert(SELF_TEXT.sell.startsWith("Nej, vi säljer ingen data"));
  assert(SELF_TEXT.which_ai.startsWith("Nej, Lumen är inte ChatGPT"));
  for (const t of ["är en robot levande", "vad är AI", "vem har gjort Mona Lisa", "lyssnar hundar på musik", "spelar du piano",
    "sparar man pengar på att cykla", "hör fladdermöss ultraljud", "vad är en chattbot", "vem är du i Hamlet, Horatio eller Hamlet",
    "är det sant att robotar tar jobb", "lyssnar du på musik", "spelar du in en låt", "sparar du pengar", "hör du vad läraren sa",
    "är du på riktigt arg", "är du klar med läxan"]) assertEquals(selfAnswer(t), null, t);
});

const A1 = "Fotosyntesen omvandlar ljusenergi till kemisk energi i form av glukos.";
const A2 = "Du sätter in ett i formeln, gångrar med fem och lägger till tio.";
const A3 = "Mitokondrien är cellens kraftverk och gör energi av socker och syre.";
const A4 = "Andra världskriget började den första september nittonhundratrettionio när Tyskland anföll Polen.";

Deno.test("K27 O30: a follow-up that quotes the answer keeps its words; a bare echo is still removed", () => {
  assertEquals(stripEcho("fotosyntesen omvandlar ljusenergi till kemisk energi i form av glukos", A1).rest, "");
  assertEquals(stripEcho("du sätter in ett i formeln", A2).rest, "");
  assert(/^(?:gud|ehm)/i.test(stripEcho("och lägger till tio. Gud- ehm", A2).rest));
  const q = stripEcho("vad menar du med i form av glukos", A1);
  assertEquals(q.rest, "vad menar du med i form av glukos");
  assert(q.quoted && q.echoed > 0);
  assert(stripEcho("så fotosyntesen omvandlar ljusenergi till kemisk energi?", A1).rest.includes("kemisk"));
  assert(stripEcho("vad betyder gör energi av socker och syre", A3).rest.includes("syre"));
  assert(stripEcho("vänta, när Tyskland anföll Polen, vad hände sen", A4).rest.includes("Polen"));
});

Deno.test("K27 O31: link requests by content, not a film that was seen", () => {
  for (const t of ["kan du hitta en film om cellen", "jag vill se en film om vulkaner", "visa en video om Pythagoras sats",
    "har du något klipp om franska revolutionen", "finns det nån bra sida om det här", "kan du länka något om DNA",
    "var kan jag läsa mer om klimatförändringar", "har du nåt bra på UR om demokrati", "någon youtube om derivata",
    "kan du rekommendera en film om fotosyntesen"]) assert(isResourceRequest(t), t);
  for (const t of ["vilken film vann Oscar 2020", "vad handlar filmen Titanic om", "hur gör man en film i skolan",
    "vad är en webbsida", "jag såg en film om hajar igår", "jag såg någon film om hajar", "har du sett Harry Potter",
    "skicka hälsningar till mamma"]) assert(!isResourceRequest(t), t);
  assertEquals(resourceTopic("finns det en film om det här på UR Play", "vad är cellandning"), "cellandning");
});
