import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { AnswerPost, isInputMeta } from "./speech.ts";

const run = (opts: ConstructorParameters<typeof AnswerPost>[0], chunks: string[]) => {
  const p = new AnswerPost(opts);
  let out = "";
  for (const c of chunks) out += p.push(c);
  return { out: out + p.finish(), post: p };
};
const base = { previousAnswers: [], trimQuestion: false };

Deno.test("2026-11-08 [[TYST]] is never spoken, wherever it is", () => {
  // after an answer (Aron's history): the text stops at the marker and the answer is withdrawn
  const late = run({ ...base, silence: true, tutor: true }, [
    "Jag vet inte ditt namn. Det är skönt att du känner dig nöjd med det.\n\n[[TY",
    "ST]]",
  ]);
  assert(!late.out.includes("[["), late.out);
  assert(late.post.silencedLate);
  // split over chunks at the start: silent
  const early = run({ ...base, silence: true, tutor: true }, ["[", "[TY", "ST]]"]);
  assertEquals(early.out, "");
  assert(early.post.silent);
  // a mode without silence never shows the marker either
  const text = run({ ...base }, ["[[TYST]] Fotosyntes är när växter bygger socker."]);
  assertEquals(text.out.trim(), "Fotosyntes är när växter bygger socker.");
  // an ordinary bracket stays
  const br = run({ ...base }, ["Svaret [se ovan] är fyra."]);
  assertEquals(br.out, "Svaret [se ovan] är fyra.");
});

Deno.test("2026-11-08 sentences about the fragment, sound or microphone are dropped (the four from the history)", () => {
  for (
    const s of [
      "Det fragmentet verkar vara ett stopp- eller avbrottskommando, inte en ny fråga om ämnet.",
      "Men jag kan inte se vad din mikrofon uppfattar, så jag svarar på det jag hör.",
      "Det här är inte en fråga jag kan svara på som något specifikt ämne, så jag föreslår att du säger vilket ämne provet gäller.",
      "Det här är bara en rest av ljud från tidigare, och det går inte att se någon ny fråga i det.",
      "Det finns inget att svara på i sak här, så jag väntar på nästa fråga.",
    ]
  ) assert(isInputMeta(s), s);
  for (
    const s of [
      "En mikrofon omvandlar ljudvågor till elektriska signaler.",
      "DNA klipps i fragment av restriktionsenzymer.",
      "Fotosyntesen sker i kloroplasterna.",
    ]
  ) assert(!isInputMeta(s), s);
  const all = run({ ...base, silence: true, tutor: true, inputMeta: true }, [
    "Det fragmentet verkar vara ett stopp- eller avbrottskommando, inte en ny fråga om ämnet.\n",
    "Det finns inget att svara på i sak här, så jag väntar på nästa fråga.",
  ]);
  assertEquals(all.out.trim(), "");
  assert(all.post.silent, "only meta = silence in Provläge");
  const mixed = run({ ...base, inputMeta: true }, [
    "Men jag kan inte se vad din mikrofon uppfattar, så jag svarar på det jag hör. Obamacare kritiseras för kostnaderna.",
  ]);
  assertEquals(mixed.out.trim(), "Obamacare kritiseras för kostnaderna.");
});
