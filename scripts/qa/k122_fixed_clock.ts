// O108 (Oscar): runs a K122 script with a fixed clock, so the regression suite gives the same result every run
// (dates, weekdays, "i går", the time in other cities). The time comes from K122_NOW (ISO), default below.
// Usage: deno run --no-lock --allow-read --allow-write --allow-env scripts/qa/k122_fixed_clock.ts <script.ts> [args…]
const FIXED = Date.parse(Deno.env.get("K122_NOW") ?? "2026-11-27T08:00:00Z");
const Real = Date;
class FixedDate extends Real {
  constructor(...a: unknown[]) {
    // deno-lint-ignore no-explicit-any
    if (a.length === 0) super(FIXED); else super(...(a as [any]));
  }
  static override now() { return FIXED; }
}
(globalThis as { Date: DateConstructor }).Date = FixedDate as unknown as DateConstructor;
const [script, ...rest] = Deno.args;
if (!script) { console.error("give the script to run"); Deno.exit(2); }
// the script reads Deno.args: hand it its own arguments
Object.defineProperty(Deno, "args", { value: rest, configurable: true });
const url = new URL(script, `file://${Deno.cwd()}/`).href;
await import(url);
