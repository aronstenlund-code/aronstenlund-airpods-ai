// K74 part 3: the five texts for the A/B listening test (scripts/k74-ab.py), made with the drill's voice text
// (the current rules version). Run: deno run -A scripts/k74-ab-texts.ts > testdata/voice/k74-ab-texts.json
// The test drill/voicerules_test.ts checks that the file still matches the code.
import { longVoice, voiceText } from "../supabase/functions/drill/handler.ts";
import { V4_PAUSE_TAG, VOICE_RULES_VERSION } from "../supabase/functions/drill/voicerules.ts";
export function abTexts() {
  const items = JSON.parse(Deno.readTextFileSync(new URL("../testdata/voice/o63-o64-answers.json", import.meta.url))) as
    { subject: string; question: string; short: string; long: string }[];
  const sv = items.filter((i) => /[åäö]/i.test(i.question + i.long) && !/engelska/i.test(i.subject) && !/det jag har|materialet|framgår inte/i.test(i.short));
  const made = sv.map((i) => ({ subject: i.subject, question: voiceText(i.question, "", VOICE_RULES_VERSION), answer: longVoice(i.short, i.short, "", VOICE_RULES_VERSION).text }))
    .map((x) => ({ ...x, chars: x.question.length + 1 + x.answer.length }))
    .filter((x) => x.chars >= 120 && x.chars <= 220);
  // five different subjects first, the ones closest to 200 characters
  const out: typeof made = [];
  for (const x of made.sort((a, b) => Math.abs(200 - a.chars) - Math.abs(200 - b.chars))) {
    if (out.length < 5 && !out.some((o) => o.question === x.question) && (out.filter((o) => o.subject === x.subject).length < 2)) out.push(x);
  }
  return {
    pause_tag: V4_PAUSE_TAG,
    variants: ["eleven_multilingual_v2", "eleven_v4", "eleven_v4+tag"],
    items: out.map((x) => ({ subject: x.subject, plain: `${x.question} ${x.answer}`, tagged: `${x.question} ${V4_PAUSE_TAG} ${x.answer}` })),
  };
}
if (import.meta.main) console.log(JSON.stringify(abTexts(), null, 1));
