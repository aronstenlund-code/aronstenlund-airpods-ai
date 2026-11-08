/**
 * D82 (Aron's device test 2026-11-08, Provläge): the microphone picked up the end of the app's own answer
 * plus noise ("Du sätter in ett i formeln, gångrar med fem och lägger till ut till tio. Gud- …"), and the
 * model answered it. Words of the fragment that repeat the last answer (a run of at least four words in the
 * same order) are removed before the model sees the fragment; what is left is the user's own new words.
 */
const norm = (w: string) => w.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "");

export function stripEcho(fragment: string, lastAnswer: string | undefined, minRun = 4): {
  rest: string;
  echoed: number;
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
  return { rest, echoed };
}
