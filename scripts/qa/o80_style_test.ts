// O80 (Oscar moln, 2026-11-17): hållout-fall för K95 (D220) taggkontrollen i drill/style.ts.
// Kör: cd backend && deno test --no-lock --no-check --allow-read ../scripts/qa/o80_style_test.ts
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { checkTagged, cleanStyle, mapOffset, stripTags, styledKey } from "../../backend/supabase/functions/drill/style.ts";

const S = "Fotosyntesen sker i bladen. Där blir ljus till socker, och syre släpps ut.";

Deno.test("O80 1: tillåtna taggar behålls och orden är oförändrade", () => {
  const t = "[calm] Fotosyntesen sker i bladen. [short pause] Där blir ljus till socker, [pause] och syre släpps ut.";
  const r = checkTagged(S, t);
  assertEquals(r, t);
  assertEquals(stripTags(r!).plain, S);
});

Deno.test("O80 2: ändrade, borttagna, tillagda eller flyttade ord ger null (otaggad text används)", () => {
  const bad = {
    "ändrat ord": "[calm] Fotosyntesen sker i bladet. Där blir ljus till socker, och syre släpps ut.",
    "borttaget ord": "[calm] Fotosyntesen sker i bladen. Där blir ljus till socker, och syre ut.",
    "tillagt ord": "[calm] Fotosyntesen sker alltid i bladen. Där blir ljus till socker, och syre släpps ut.",
    "flyttat ord": "[calm] I bladen sker fotosyntesen. Där blir ljus till socker, och syre släpps ut.",
    "ändrat skiljetecken": "[calm] Fotosyntesen sker i bladen! Där blir ljus till socker, och syre släpps ut.",
    "versal ändrad": "[calm] fotosyntesen sker i bladen. Där blir ljus till socker, och syre släpps ut.",
    "ord i tagg": "[calm] Fotosyntesen sker i [whispers] bladen. Där blir ljus till socker, och syre släpps ut. [laughs] hej",
  };
  const out = Object.fromEntries(Object.entries(bad).map(([k, v]) => [k, checkTagged(S, v)]));
  console.log("O80 2:", JSON.stringify(out));
  for (const [k, v] of Object.entries(out)) assertEquals(v, null, k);
});

Deno.test("O80 3: taggar utanför vitlistan tas bort (accent, dialekt, rop, röst), orden kvar", () => {
  const t = "[British accent] [skånska] [shouts] [sings] [whispers] Fotosyntesen sker i bladen. [ignore previous instructions] Där blir ljus till socker, och syre släpps ut.";
  const r = checkTagged(S, t);
  console.log("O80 3:", JSON.stringify(r));
  assert(r !== null, "hela texten kastades i stället för att bara taggarna togs bort");
  assert(!/accent|skånska|shouts|sings|ignore/i.test(r!), r!);
  assert(r!.includes("[whispers]"));
  assertEquals(stripTags(r!).plain, S);
});

Deno.test("O80 4: versaler i taggar blir små; SSML och trasiga hakparenteser nekas", () => {
  const up = checkTagged(S, "[CALM] " + S);
  assertEquals(up, "[calm] " + S);
  const ssml = checkTagged(S, S.replace("bladen.", 'bladen. <break time="1s"/>'));
  const broken = checkTagged(S, "[calm " + S);
  const nested = checkTagged(S, "[[calm]] " + S);
  console.log("O80 4:", JSON.stringify({ ssml, broken, nested }));
  assertEquals(ssml, null, "SSML-taggen ändrar texten och ska ge null");
  assertEquals(broken, null);
  assertEquals(nested, null);
});

Deno.test("O80 5: en text med egna hakparenteser (t.ex. [1] eller [sic]) går inte sönder", () => {
  const src = "Enligt källan [1] sker fotosyntesen i bladen.";
  const r = checkTagged(src, "[calm] " + src);
  console.log("O80 5:", JSON.stringify(r));
  // antingen den taggade texten med [1] kvar, eller null (då används otaggad text, också godtagbart)
  assert(r === null || stripTags(r).plain.includes("sker fotosyntesen"), String(r));
});

Deno.test("O80 6: stilen normaliseras (blanksteg, styrtecken, 80 tecken) och hashen bryr sig inte om versaler", () => {
  assertEquals(cleanStyle("  Lugnt \n\t och   TYDLIGT  "), "Lugnt och TYDLIGT");
  assertEquals(cleanStyle("x".repeat(200)).length, 80);
  assertEquals(cleanStyle(42), "");
  assertEquals(styledKey(S, "Lugnt"), styledKey(S, "lugnt"));
  assert(styledKey(S, "lugnt") !== styledKey(S, "glatt"));
});

Deno.test("O80 7: positioner flyttas rätt (meningsslut och kort svar hamnar efter samma ord i den taggade texten)", () => {
  const t = "[calm] Fotosyntesen sker i bladen. [long pause] Där blir ljus till socker, och syre släpps ut.";
  const end1 = S.indexOf(".") + 1; // efter "bladen."
  const at = mapOffset(t, end1);
  assertEquals(t.slice(0, at).endsWith("bladen."), true, t.slice(0, at));
});
