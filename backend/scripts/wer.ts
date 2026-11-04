// Word error rate + exact-match rate of recognised phrases against testdata/scripts/sv-short-prompts.md (D44).
// Usage: deno run --allow-read scripts/wer.ts hypotheses.tsv      (lines: "<item number><TAB><recognised text>")
// Run it once per recogniser (Scribe, Safari) with the owner's recordings read aloud and compare the output.
import { numbersToSpeech } from "../supabase/functions/answer/svnum.ts";

const norm = (s: string) =>
  numbersToSpeech(s).toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim().split(/\s+/).filter(
    Boolean,
  );

export function wer(ref: string[], hyp: string[]): { errors: number; words: number } {
  const d = Array.from({ length: ref.length + 1 }, (_, i) => [i, ...new Array(hyp.length).fill(0)]);
  for (let j = 1; j <= hyp.length; j++) d[0][j] = j;
  for (let i = 1; i <= ref.length; i++) {
    for (let j = 1; j <= hyp.length; j++) {
      d[i][j] = Math.min(
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + (ref[i - 1] === hyp[j - 1] ? 0 : 1),
      );
    }
  }
  return { errors: d[ref.length][hyp.length], words: ref.length };
}

export function parseReference(md: string): Map<number, string> {
  const out = new Map<number, string>();
  for (const line of md.split("\n")) {
    const c = line.split("|").map((x) => x.trim());
    if (c.length >= 6 && /^\d+$/.test(c[1])) out.set(Number(c[1]), c[4]);
  }
  return out;
}

if (import.meta.main) {
  const ref = parseReference(
    await Deno.readTextFile(new URL("../../testdata/scripts/sv-short-prompts.md", import.meta.url)),
  );
  const hyp = (await Deno.readTextFile(Deno.args[0])).split("\n").map((l) => l.split("\t")).filter((
    c,
  ) => c.length >= 2);
  let errors = 0, words = 0, exact = 0, n = 0;
  for (const [id, text] of hyp) {
    const r = ref.get(Number(id));
    if (r === undefined) continue;
    const e = wer(norm(r), norm(text));
    errors += e.errors;
    words += e.words;
    n++;
    if (e.errors === 0) exact++;
    if (e.errors) console.log(`#${id} ref="${r}" hyp="${text}" errors=${e.errors}`);
  }
  console.log(
    `items=${n} WER=${(100 * errors / Math.max(1, words)).toFixed(1)}% exact=${exact}/${n}`,
  );
}
