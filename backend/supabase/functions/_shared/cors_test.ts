// K80 (D202): which browser origins may call the functions.
import { assertEquals } from "jsr:@std/assert@1.0.8";

Deno.test("K80 (D202): the Vercel demo page is allowed, GitHub Pages still is, a foreign origin is not", async () => {
  const { originAllowed } = await import("./cors.ts");
  assertEquals(originAllowed("https://earmind.vercel.app"), true);
  assertEquals(originAllowed("https://aronstenlund-code.github.io"), true);
  assertEquals(originAllowed("https://earmind-evil.vercel.app"), false);
  assertEquals(originAllowed("https://example.com"), false);
});
