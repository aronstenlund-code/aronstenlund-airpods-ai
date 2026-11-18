import { assertEquals, assertRejects } from "jsr:@std/assert@1.0.8";
import { memo } from "./memo.ts";

Deno.test("K100 memo: one read per minute; a failure is not kept", async () => {
  let t = 0, reads = 0, fail = false;
  const m = memo(() => (reads++, fail ? Promise.reject(new Error("x")) : Promise.resolve(reads)), 60_000, () => t);
  assertEquals([await m(), await m()], [1, 1]);
  t = 59_999;
  assertEquals(await m(), 1);
  t = 60_000;
  assertEquals(await m(), 2);
  fail = true;
  t = 200_000;
  await assertRejects(() => m());
  fail = false;
  assertEquals(await m(), 4, "read again after a failure");
});
