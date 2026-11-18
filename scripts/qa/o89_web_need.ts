// O89 (Oscar moln, 2026-11-18): hur många enheter av webbtaket nattens live-eval drar, räknat med serverns egna regler
// (needsText, needsWeb, isResourceRequest) på varje tur i scripts/live-eval-cases.json. En enhet dras per sådan tur
// även när modellen sedan inte söker (answer/handler.ts: enforceLimits("answer-web") före svaret).
// Kör: cd backend && deno run --no-lock --no-check --allow-read ../scripts/qa/o89_web_need.ts
import { needsText, needsWeb } from "../../backend/supabase/functions/answer/web.ts";
import * as h from "../../backend/supabase/functions/answer/handler.ts";
const cases = JSON.parse(await Deno.readTextFile("../scripts/live-eval-cases.json"));
const isRes = (h as Record<string, unknown>).isResourceRequest as ((s: string) => boolean) | undefined;
const hits: Record<string, string[]> = { text: [], web: [], resurs: [] };
let turns = 0;
for (const c of cases) {
  for (const [i, t] of (c.turns ?? []).entries()) {
    if (!t.q) continue;
    turns++;
    const plan = !!(t.profile || t.interview || t.rizz_ref);
    const auto = t.mode === "auto";
    if (plan) continue;
    if (needsText(t.q)) hits.text.push(`${c.id}#${i}`);
    else if (!auto && needsWeb(t.q)) hits.web.push(`${c.id}#${i}`);
    else if (isRes && isRes(t.q)) hits.resurs.push(`${c.id}#${i}`);
  }
}
console.log(JSON.stringify({ turer: turns, text: hits.text.length, web: hits.web.length, resurs: hits.resurs.length,
  totalt: hits.text.length + hits.web.length + hits.resurs.length, ...hits }, null, 1));
