// K70 (D185): Läsläget, the material cleaned for reading aloud. Invented text only, a fake model.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { chunks, countsAs, handleRead, parseRead, sentences } from "./read.ts";
import { DEFAULT_DRILL_CONFIG } from "./drill.ts";
import type { LLMProvider, LLMRequest } from "../answer/llm/types.ts";

Deno.test("K70 sentences: ends at . ! ? before a capital, never after an abbreviation or a number", () => {
  assertEquals(sentences("Växter behöver ljus. Det ger energi! Vad händer då? Inget."), ["Växter behöver ljus.", "Det ger energi!", "Vad händer då?", "Inget."]);
  assertEquals(sentences("Det finns t.ex. Klorofyll i bladen. Se s. 4 om det."), ["Det finns t.ex. Klorofyll i bladen.", "Se s. 4 om det."]);
  assertEquals(sentences("Gustav Vasa kröntes 1523. Han dog 1560."), ["Gustav Vasa kröntes 1523.", "Han dog 1560."]);
  assertEquals(sentences("En mening utan punkt"), ["En mening utan punkt"]);
});

Deno.test("K70 parseRead: headings, paragraphs, lines joined, markdown and running heads gone, long paragraphs split", () => {
  const p = parseRead("# Cellen\n# Cellen\nCellen är livets minsta\ndel. Den har ett membran.\n\n- Kärnan styr.\n\n[oläslig]\n## Celldelning\nMitos ger två celler.");
  assertEquals(p, [
    { kind: "heading", text: "Cellen" },
    { kind: "para", text: "Cellen är livets minsta del. Den har ett membran." },
    { kind: "para", text: "Kärnan styr." },
    { kind: "heading", text: "Celldelning" },
    { kind: "para", text: "Mitos ger två celler." },
  ]);
  const long = parseRead(("Det här är en ganska lång mening om ämnet. ").repeat(60));
  assert(long.length >= 2 && long.every((x) => x.text.length <= 1500));
  assertEquals(long.map((x) => x.text).join(" "), ("Det här är en ganska lång mening om ämnet. ").repeat(60).trim(), "nothing lost or added");
});

Deno.test("K70 chunks and countsAs (every started 800 characters)", () => {
  const t = ("Stycke ett har text.\n\n").repeat(800);
  const c = chunks(t, 6000);
  assert(c.every((x) => x.length <= 6000));
  assertEquals(c.join("\n\n").replace(/\s+/g, " "), t.trim().replace(/\s+/g, " "));
  assertEquals([countsAs(0), countsAs(1), countsAs(800), countsAs(801), countsAs(4000)], [0, 1, 1, 2, 5]);
});

Deno.test("K70 handleRead: chunks in parallel, in order, the model's text to parts; nothing readable = 422", async () => {
  const seen: LLMRequest[] = [];
  const provider: LLMProvider = {
    name: "fake",
    model: "haiku",
    async *stream(req) {
      seen.push(req);
      const m = /<material>\n([\s\S]*)\n<\/material>/.exec(req.user);
      yield { type: "text", text: m ? `# Del\n${m[1].replace(/Sida \d+/g, "")}` : "" };
      yield { type: "usage", inputTokens: 100, outputTokens: 50 };
    },
  };
  const text = Array.from({ length: 3 }, (_, i) => `Kapitel ${i + 1} handlar om något viktigt. Sida ${i + 1}\n\n` + "Mer text här. ".repeat(300)).join("\n\n");
  const r = await handleRead({ text, subject: "Biologi" }, provider, DEFAULT_DRILL_CONFIG);
  assert(seen.length >= 2, "more than one chunk");
  assertEquals(r.steps.length, seen.length);
  const parts = r.body.parts as { kind: string; text: string }[];
  assertEquals(parts[0].kind, "heading");
  assert(parts.some((p) => p.text.startsWith("Kapitel 1")) && parts.findIndex((p) => p.text.startsWith("Kapitel 1")) < parts.findIndex((p) => p.text.startsWith("Kapitel 3")));
  assert(!parts.some((p) => /Sida \d/.test(p.text)));
  assertEquals(r.body.counts_as, Math.ceil((r.body.chars as number) / 800));
  assertEquals(r.body.title, "Del");
  const none: LLMProvider = { name: "f", model: "h", async *stream() { yield { type: "text", text: "[oläslig]" }; } };
  let status = 0;
  await handleRead({ text: "xx" }, none, DEFAULT_DRILL_CONFIG).catch((e) => (status = e.status));
  assertEquals(status, 422);
});

Deno.test("K72 osv./etc./m.m. may end a sentence; t.ex. still does not; the language comes from the text", async () => {
  const { textLanguage } = await import("./read.ts");
  assertEquals(sentences("Kroppen behöver kol, kväve osv. Nästa stycke handlar om energi."), ["Kroppen behöver kol, kväve osv.", "Nästa stycke handlar om energi."]);
  assertEquals(sentences("Det finns järn, zink etc. Sedan kommer vatten."), ["Det finns järn, zink etc.", "Sedan kommer vatten."]);
  assertEquals(sentences("Vi läser t.ex. Strindberg i år."), ["Vi läser t.ex. Strindberg i år."]);
  assertEquals(textLanguage("In 1769 James Watt improved the steam engine, and it was used in the mills of the north. The workers were many.", "Historia"), "English");
  assertEquals(textLanguage("Ångmaskinen förbättrades av James Watt och den var viktig för att fabrikerna kunde växa.", "Engelska"), "");
  assertEquals(textLanguage("kort", "Engelska"), "English", "too little text: the subject decides");
});

Deno.test("T28 (Toby): photos the read prompt calls unreadable are written out the drill way and then read", async () => {
  const seen: string[] = [];
  const provider: LLMProvider = {
    name: "fake",
    model: "haiku",
    async *stream(req) {
      seen.push(req.system.slice(0, 40));
      // the read prompt says "[oläslig]", the transcription prompt writes the page out
      yield { type: "text", text: /READ ALOUD/.test(req.system) ? "[oläslig]" : "Fotosyntes. Växter tillverkar socker av koldioxid och vatten." };
      yield { type: "usage", inputTokens: 10, outputTokens: 5 };
    },
  };
  const png = "iVBORw0KGgo" + "A".repeat(200);
  const r = await handleRead({ pages: [{ media_type: "image/png", data: png }] }, provider, DEFAULT_DRILL_CONFIG);
  assertEquals((r.body.parts as { kind: string }[]).filter((p) => p.kind === "para").length, 1);
  assertEquals(seen.length, 2);
  assertEquals(r.steps.length, 2);
});

Deno.test("T28b (Toby): a photo with no text is 422, never a read-aloud description of the picture", async () => {
  const provider: LLMProvider = {
    name: "fake",
    model: "haiku",
    async *stream(req) {
      yield { type: "text", text: /READ ALOUD/.test(req.system) ? "[oläslig]" : "[Ett vattenfall mellan klippor. Stenarna är täckta av grön och orangefärgad mossa.]" };
      yield { type: "usage", inputTokens: 10, outputTokens: 5 };
    },
  };
  let status = 0;
  await handleRead({ pages: [{ media_type: "image/png", data: "iVBORw0KGgo" + "A".repeat(200) }] }, provider, DEFAULT_DRILL_CONFIG).catch((e) => (status = e.status));
  assertEquals(status, 422);
});
