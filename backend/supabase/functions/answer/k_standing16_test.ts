// Kevin standing round 16 (live eval 2026-11-11): a spaced range split across chunks was "ett komma fyra – fem till sju".
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { NumberStream } from "./speech.ts";

Deno.test("standing16: a spaced number range is read as one range in every chunk size", () => {
  const s = "öka mellan 1,4 – 5,7 grader. Sidorna 12 – 15 och 2 - 3 timmar, minus 3 - inte mer.";
  for (const step of [1, 2, 3, 5, 7, 11]) {
    const n = new NumberStream();
    let o = "";
    for (let i = 0; i < s.length; i += step) o += n.push(s.slice(i, i + step));
    o += n.finish();
    assertEquals(o, "öka mellan ett komma fyra till fem komma sju grader. Sidorna tolv till femton och två till tre timmar, minus tre - inte mer.", `step ${step}`);
  }
});
