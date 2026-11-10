// Oscar QA, O24: independent offline test of Kevin's K20 (answer/self.ts selfAnswer: questions about Lumen answered
// in code with the words of "Om appen"; answer/speechsym.ts beforeNumbers (rulerNumbers) + afterNumbers: kings' numbers as ordinals),
// the deployed files in Node 24, free. New phrasings only (none in k20_test.ts).
//   node scripts/qa/o24_k20_offline.mjs > reports/qa/data/<stamp>-o24-k20.json
import { selfAnswer } from "../../backend/supabase/functions/answer/self.ts";
import { afterNumbers, beforeNumbers } from "../../backend/supabase/functions/answer/speechsym.ts";

const SELF = [ // [utterance, expected topic: robot | listen | save]
  ["är du en AI", "robot"], ["Lumen, är du en människa eller en robot", "robot"], ["är det chatgpt", "robot"],
  ["vilken AI är du", "robot"], ["vem har gjort dig", "robot"], ["är du på riktigt eller", "robot"],
  ["lyssnar du på mig nu", "listen"], ["hör du allt jag säger", "listen"], ["spelar du in lektionen", "listen"],
  ["lyssnar du när appen är stängd", "listen"], ["kan du höra mig när skärmen är släckt", "listen"],
  ["spelar du in det här", "listen"], ["asså lyssnar du hela tiden", "listen"],
  ["sparar du mina frågor", "save"], ["vem ser det jag frågar", "save"], ["kan läraren se vad jag frågar", "save"],
  ["sparas det jag säger", "save"], ["säljer ni min data", "save"], ["vart skickas ljudet", "save"], ["kan mina föräldrar läsa mina frågor", "save"],
];
const NOT_SELF = [
  "är en robot levande", "vad är AI", "vem har gjort Mona Lisa", "lyssnar hundar på musik", "spelar du piano",
  "sparar man pengar på att cykla", "hör fladdermöss ultraljud", "vad är en chattbot", "vem är du i Hamlet, Horatio eller Hamlet",
  "är det sant att robotar tar jobb",
];
const RULER = [ // [model text, must contain, must NOT contain]
  ["Erik 14 var kung av Sverige", "Erik den fjortonde", null], ["Karl den 12 dog 1718", "Karl den tolfte", null],
  ["Gustav III mördades på en maskerad", "Gustav den tredje", null], ["Kristina var drottning", "Kristina", "den"],
  ["Ludvig 14 kallades solkungen", "Ludvig den fjortonde", null],
];
const RULER_FALSE = [ // ordinary people with common first names in word problems and sport (must stay numbers)
  ["Erik 14 poäng, Johan 12 poäng", "den"], ["Peter 5 äpplen och Filip 3 äpplen", "den"], ["Alexander 2 mål i matchen", "den"],
  ["Oscar 7 och Leo 9 i provet", "den"], ["Henrik 3 rätt av 10", "den"], ["Karl 12 år gammal", "den"], ["Johan 3 kom tvåa", "den"],
  ["Magnus 4 timmar", "den"], ["Leo 10 cm lång", "den"], ["Filip 8, Ludvig 6", "den"],
];
const self = SELF.map(([t, want]) => {
  const a = selfAnswer(t);
  const got = !a ? null : /AI-assistent/.test(a) ? "robot" : /lyssnar bara/.test(a) ? "listen" : /sparas inte/.test(a) ? "save" : "?";
  return { t, want, got, ok: got === want };
});
const notSelf = NOT_SELF.map((t) => ({ t, got: selfAnswer(t), ok: selfAnswer(t) === null }));
const say = (s) => afterNumbers(beforeNumbers(s));
const ruler = RULER.map(([s, must, mustNot]) => { const o = say(s); return { s, out: o, ok: o.includes(must) && (!mustNot || !o.includes(mustNot)) }; });
const rulerFalse = RULER_FALSE.map(([s, mustNot]) => { const o = beforeNumbers(s); return { s, out: o, ok: !new RegExp(`\\b${mustNot}\\b`).test(o) }; });
const n = (a) => `${a.filter((x) => x.ok).length}/${a.length}`;
console.log(JSON.stringify({ sum_self: n(self), sum_not_self: n(notSelf), sum_ruler: n(ruler), sum_ruler_false: n(rulerFalse),
  fails: [...self, ...notSelf, ...ruler, ...rulerFalse].filter((x) => !x.ok), self, notSelf, ruler, rulerFalse }, null, 1));
