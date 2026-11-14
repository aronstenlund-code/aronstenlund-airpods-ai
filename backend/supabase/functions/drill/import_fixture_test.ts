import { assertEquals } from "jsr:@std/assert@1.0.8";
import { importText } from "./import_text.ts";

// K60 / A96: the same 20 cases as the app's ChatGPTImport test (Oscar O58, testdata/import/o58-cases.json)
const cases = JSON.parse(Deno.readTextFileSync(new URL("../../../../testdata/import/o58-cases.json", import.meta.url))) as {
  name: string; text: string; status: number; items: { question: string; short: string; long: string }[];
}[];

for (const c of cases) {
  Deno.test(`K60 import fixture ${c.name}`, () => {
    const r = importText(c.text);
    assertEquals(r.items.length ? 200 : 422, c.status);
    assertEquals(r.items.map(({ question, short, long }) => ({ question, short, long })), c.items);
    for (const p of [...r.skipped, ...r.warnings]) assertEquals(typeof p.line === "number" && !!p.reason, true);
  });
}
