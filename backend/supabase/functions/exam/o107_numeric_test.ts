// O107 F1 (Oscar): numericCheck read "5 miljoner" as 1 000 000 (the digit and the scale word apart), "minus 4" as 4,
// and compared two roots ("x = 2 eller x = −4") only against the last one.
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { numericCheck } from "./handler.ts";

Deno.test("O107 F1: a digit with a scale word is one number; 'minus 4' is −4; several roots are left to the scoring rules", () => {
  assertEquals(numericCheck("5 miljoner fler", "fem miljoner")?.equal, true);
  assertEquals(numericCheck("Befolkningen ökade med 5 miljoner.", "det blev fem miljoner fler")?.equal, true);
  assertEquals(numericCheck("2,5 miljarder", "2,5 miljarder")?.equal, true);
  assertEquals(numericCheck("Det kostar 126 kr.", "126")?.equal, true, "a number at the end of a sentence");
  assertEquals(numericCheck("-4", "minus 4")?.equal, true);
  assertEquals(numericCheck("-4", "minus fyra")?.equal, true);
  assertEquals(numericCheck("x = 2 eller x = −4", "x är två"), null, "two roots: no single number to check");
  assertEquals(numericCheck("x₁ = 3, x₂ = -1", "x är tre"), null);
  assertEquals(numericCheck("126 kr", "det blir 126 kronor")?.equal, true, "unchanged");
  assertEquals(numericCheck("126 kr", "125")?.equal, false, "a wrong number is still wrong");
});
