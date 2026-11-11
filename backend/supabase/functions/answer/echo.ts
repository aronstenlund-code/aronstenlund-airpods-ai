/**
 * D82 (Aron's device test 2026-11-08, Provläge): the microphone picked up the end of the app's own answer
 * plus noise ("Du sätter in ett i formeln, gångrar med fem och lägger till ut till tio. Gud- …"), and the
 * model answered it. Words of the fragment that repeat the last answer (a run of at least four words in the
 * same order) are removed before the model sees the fragment; what is left is the user's own new words.
 */
const norm = (w: string) => w.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "");
/**
 * K27 (Oscar O30: "vad menar du med i form av glukos" became "vad menar du med" in 4/8): when the wearer's own words
 * around the repeated part ask about it, the repeat is a quote, not an echo: the whole fragment is kept and only
 * marked (quoted = true); a bare echo with noise ("och lägger till tio. Gud- ehm") is still removed.
 */
const ASKS_ABOUT_IT =
  /(?<![\p{L}])(?:vad|varför|hur|när|vem|vilken|vilket|vilka|menar|betyder|stämmer|förklara|eller|igen|hände|händer|alltså)(?![\p{L}])/iu;
const SO_QUESTION = /^(?:så|alltså|va|vänta|menar du att|är det så att|så det|så det är)$/iu;
// live eval klocka-01: "är det samma som tjugo över åtta på kvällen" lost its quote and got silence; a yes/no frame
// about the quoted words is a follow-up question
const ASK_FRAME = /^(?:och |men |så )?(?:är det|är de|blir det|stämmer det|gäller det|betyder det|samma som|lika med)(?![\p{L}])/iu;

export function stripEcho(fragment: string, lastAnswer: string | undefined, minRun = 4): {
  rest: string;
  echoed: number;
  quoted?: boolean;
} {
  if (!lastAnswer) return { rest: fragment, echoed: 0 };
  const words = fragment.split(/\s+/).filter(Boolean);
  const ans = lastAnswer.split(/\s+/).map(norm).filter(Boolean);
  if (words.length < minRun || ans.length < minRun) return { rest: fragment, echoed: 0 };
  const grams = new Set<string>();
  for (let i = 0; i + minRun <= ans.length; i++) grams.add(ans.slice(i, i + minRun).join(" "));
  const keep = new Array(words.length).fill(true);
  const nw = words.map(norm);
  let echoed = 0;
  for (let i = 0; i + minRun <= nw.length; i++) {
    if (grams.has(nw.slice(i, i + minRun).join(" "))) {
      for (let j = i; j < i + minRun; j++) {
        if (keep[j]) echoed++;
        keep[j] = false;
      }
    }
  }
  if (!echoed) return { rest: fragment, echoed: 0 };
  const rest = words.filter((_, i) => keep[i]).join(" ").replace(/^[\s,.;:!?-]+/, "").trim();
  const own = rest.replace(/[,.;:!?-]+/g, " ").replace(/\s+/g, " ").trim();
  if (own && (ASKS_ABOUT_IT.test(own) || ASK_FRAME.test(own) || (SO_QUESTION.test(own) && /\?\s*$/.test(fragment)))) {
    return { rest: fragment, echoed, quoted: true };
  }
  return { rest, echoed };
}
