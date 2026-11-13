import { assertEquals } from "jsr:@std/assert@1.0.8";
import { HJALP } from "./hjalp.ts";

Deno.test("K57 the server's copy of the help text equals docs/HJALP.md (run scripts/sync-hjalp.py after editing it)", async () => {
  const doc = await Deno.readTextFile(new URL("../../../../docs/HJALP.md", import.meta.url));
  assertEquals(HJALP.replace(/\r\n/g, "\n"), doc.replace(/\r\n/g, "\n"));
});
