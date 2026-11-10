import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { applicable, applyCorrection, covers, describe, detectCorrection, profileOf, type Setting } from "./settings.ts";

Deno.test("K10.2 corrections are read with or without Lumen; ordinary questions are not", () => {
  assertEquals(detectCorrection("Lumen, kortare"), { key: "length", value: "shorter" });
  assertEquals(detectCorrection("det var för långt"), { key: "length", value: "shorter" });
  assertEquals(detectCorrection("för svårt"), { key: "simplicity", value: "simpler" });
  assertEquals(detectCorrection("fler exempel tack"), { key: "examples", value: "more" });
  assertEquals(detectCorrection("det där var fel"), { key: "accuracy", value: "careful" });
  for (const f of ["vad är kortare än en meter", "varför är det fel att stjäla", "ge exempel på däggdjur"]) {
    assertEquals(detectCorrection(f), null, f);
  }
});

Deno.test("K10.2 scope: guessed from the answer, widened by the same correction elsewhere", () => {
  let s: Setting[] = [];
  let r = applyCorrection(s, { key: "length", value: "shorter" }, { mode: "prov", subject: "Geografi", answer_type: "explanation" });
  assertEquals(r.changed.scope, { mode: "prov", subject: "Geografi" }); // K13: the mode is kept (O10 #1)
  assertEquals(describe(r.changed), "Kortare svar i geografi");
  s = r.settings;
  // same subject again: no change
  r = applyCorrection(s, { key: "length", value: "shorter" }, { mode: "prov", subject: "Geografi" });
  assertEquals(r.widened, false);
  // another subject in the same mode -> the mode
  r = applyCorrection(r.settings, { key: "length", value: "shorter" }, { mode: "prov", subject: "Biologi" });
  assertEquals(r.widened, true);
  assertEquals(r.changed.scope, { mode: "prov" });
  // another mode -> global
  r = applyCorrection(r.settings, { key: "length", value: "shorter" }, { mode: "fragor", answer_type: "fact" });
  assertEquals(r.changed.scope, {});
  assertEquals(r.settings.length, 1);
  // maths answers by answer type
  const m = applyCorrection([], { key: "examples", value: "more" }, { mode: "prov", subject: "Matematik", answer_type: "math" });
  assertEquals(m.changed.scope, { mode: "prov", answer_type: "math" });
  // the opposite value replaces it
  const o = applyCorrection(r.settings, { key: "length", value: "longer" }, { mode: "fragor" });
  assert(!o.settings.some((x) => x.value === "shorter"));
});

Deno.test("K10.2-3 only the settings for this context; the profile is at most 300 characters", () => {
  const s: Setting[] = [
    { key: "length", value: "shorter", scope: { subject: "Matematik" } },
    { key: "examples", value: "more", scope: { exam: "Geografiprovet" } },
    { key: "simplicity", value: "simpler", scope: {} },
  ];
  assertEquals(applicable(s, { subject: "Matematik", mode: "prov" }).length, 2);
  assertEquals(applicable(s, { subject: "Biologi", exam: "Geografiprovet" }).length, 2);
  const p = profileOf(s);
  assert(p.length <= 300 && p.includes("kortare svar i matematik"), p);
  const many: Setting[] = Array.from({ length: 30 }, (_, i) => ({ key: "length", value: "shorter", scope: { subject: `Ämne nummer ${i}` } }));
  assert(profileOf(many).length <= 300);
});

Deno.test("K8 memory filter: study subjects are kept, the user's own health facts are not (D113 B5)", async () => {
  const { parseMemoryReply } = await import("./handler.ts");
  const keep = ["Har prov i religionskunskap fredag 13 november 2026.", "Vill ha långa förklaringar.", "Läser företagsekonomi.", "Pluggar partiklar i fysik.", "Har prov i religion på måndag."];
  const drop = ["Har ADHD.", "Tar Elvanse.", "Har astma.", "Har migrän."];
  const r = parseMemoryReply(JSON.stringify({ add: [...keep, ...drop].slice(0, 5) }), []);
  for (const k of keep) assert(r.add.includes(k), k);
  const r2 = parseMemoryReply(JSON.stringify({ add: drop }), []);
  assertEquals(r2.add, []);
});

Deno.test("K13 (O10) corrections in own words, my own variants; ordinary sentences stay questions", () => {
  for (const [t, want] of [
    ["Lumen, mycket kortare tack", "length:shorter"], ["kan du fatta dig kortare", "length:shorter"], ["okej det var alldeles för långt", "length:shorter"],
    ["utveckla det", "length:longer"], ["kan du berätta mer", "length:longer"], ["lite mer utförligt framöver", "length:longer"],
    ["jag fattar inte vad du menar", "simplicity:simpler"], ["förklara som för en femåring", "simplicity:simpler"], ["mindre krångligt tack", "simplicity:simpler"],
    ["ta något exempel", "examples:more"], ["ett exempel skulle vara bra", "examples:more"],
    ["nej det där är inte sant", "accuracy:careful"], ["men det där stämmer inte alls", "accuracy:careful"],
  ]) {
    const r = detectCorrection(t);
    assertEquals(r ? `${r.key}:${r.value}` : null, want, t);
  }
  for (const t of ["vilken är kortare, Göta älv eller Klarälven", "berätta mer om vikingarna", "jag fattar inte matte alls, hjälp mig med ekvationer", "ge exempel på en metafor", "är det fel att ljuga"]) {
    assertEquals(detectCorrection(t), null, t);
  }
});

Deno.test("K13 (O10 #1) a correction in Frågor then in Provläge becomes global and still covers Frågor", () => {
  let r = applyCorrection([], { key: "length", value: "shorter" }, { mode: "fragor", answer_type: "fact" });
  r = applyCorrection(r.settings, { key: "length", value: "shorter" }, { mode: "prov", subject: "Biologi", answer_type: "explanation" });
  assertEquals(r.changed.scope, {});
  assert(covers(r.changed.scope, { mode: "fragor" }) && covers(r.changed.scope, { mode: "prov", subject: "Kemi" }));
});

Deno.test("K13.2 two 'ja' of the last three make the long answer the default; 'kortare' brings short-first back", async () => {
  const { applySignal } = await import("./settings.ts");
  const ctx = { mode: "prov", subject: "Biologi", answer_type: "explanation" as const };
  let r = applySignal([], "yes", ctx);
  assertEquals(r.longFirst, false);
  r = applySignal(r.settings, "no", ctx);
  assertEquals(r.longFirst, false);
  r = applySignal(r.settings, "yes", ctx);
  assertEquals(r.longFirst, true, "y n y");
  assert(r.changed && describe(r.changed) === "Längre, utförligare svar i biologi");
  assert(!applySignal(r.settings, "yes", { mode: "prov", subject: "Kemi", answer_type: "explanation" }).longFirst, "only in Biologi");
  const back = applyCorrection(r.settings, { key: "length", value: "shorter" }, ctx);
  assert(!back.settings.some((s) => s.key === "length" && s.value === "longer"), "kortare replaces it");
  // "no" alone never makes it long
  let n = applySignal([], "no", ctx);
  n = applySignal(n.settings, "no", ctx);
  assertEquals(n.longFirst, false);
});
