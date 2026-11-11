// Stående omgång 3 (Oscar O36/O34): page abbreviations and spelled-out "kronor" with öre.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { numbersToSpeech } from "./svnum.ts";
import { afterNumbers, beforeNumbers } from "./speechsym.ts";

const say = (s: string) => afterNumbers(numbersToSpeech(beforeNumbers(s)));

Deno.test("Standing 3: 's. 23' is 'sidan tjugotre'; '299,50 kronor' has öre; other 's.' stays", () => {
  assertEquals(say("Läs s. 23."), "Läs sidan tjugotre.");
  assertEquals(say("Se sid. 12 i boken."), "Se sidan tolv i boken.");
  assertEquals(say("Det kostar 12,50 kronor."), "Det kostar tolv kronor och femtio öre.");
  assertEquals(say("Det kostar 399,20 kr."), "Det kostar trehundranittionio kronor och tjugo öre.");
  assertEquals(say("Detta är s. vad"), "Detta är s. vad");
});
