// Oscar QA, O30: the echo filter (D82, answer/echo.ts stripEcho: a run of >= 4 words that repeats the last answer is
// removed before the model sees the fragment; nothing left = silence) in Provläge/Auto. Risk: a student who quotes
// the answer to ask about it, or repeats it to check, loses the question. Offline, free, the deployed file.
//   node scripts/qa/o30_echo_offline.mjs > reports/qa/data/<stamp>-o30-echo.json
import { stripEcho } from "../../backend/supabase/functions/answer/echo.ts";

const A1 = "Fotosyntesen omvandlar ljusenergi till kemisk energi i form av glukos.";
const A2 = "Du sätter in ett i formeln, gångrar med fem och lägger till tio.";
const A3 = "Mitokondrien är cellens kraftverk och gör energi av socker och syre.";
const A4 = "Andra världskriget började den första september nittonhundratrettionio när Tyskland anföll Polen.";
const C = [ // [last answer, fragment, "echo" (should become empty) | words the rest must still contain (| = all)]
  [A1, "fotosyntesen omvandlar ljusenergi till kemisk energi i form av glukos", "echo"],
  [A2, "du sätter in ett i formeln gånger med fem", "echo"],
  [A2, "och lägger till tio. Gud- ehm", "echo"],
  [A3, "cellens kraftverk och gör energi av socker", "echo"],
  [A1, "vad menar du med i form av glukos", "vad menar du med i form av glukos"],
  [A1, "så fotosyntesen omvandlar ljusenergi till kemisk energi?", "fotosyntesen|kemisk"],
  [A3, "varför kallas mitokondrien för cellens kraftverk", "kraftverk"],
  [A3, "vad betyder gör energi av socker och syre", "socker|syre"],
  [A4, "vänta, när Tyskland anföll Polen, vad hände sen", "Polen|hände"],
  [A4, "började andra världskriget den första september eller den tredje", "september|tredje"],
  [A2, "varför lägger man till tio", "tio"],
  [A1, "kan du säga det igen fast enklare", "igen|enklare"],
];
const rows = C.map(([a, f, want]) => {
  const r = stripEcho(f, a);
  const ok = want === "echo" ? r.rest.replace(/[^\p{L}]/gu, "").length < 6 || /^(?:gud|ehm|eh|gånger med fem)\b/iu.test(r.rest)
    : want.split("|").every((w) => r.rest.toLowerCase().includes(w.toLowerCase()));
  return { answer: a, fragment: f, want, rest: r.rest, echoed: r.echoed, ok };
});
console.log(JSON.stringify({ n: rows.length, ok: rows.filter((r) => r.ok).length, fails: rows.filter((r) => !r.ok), rows }, null, 1));
