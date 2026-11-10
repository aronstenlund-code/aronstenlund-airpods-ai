// Oscar QA, O17b: a new independent set for Kevin's K21b two-layer crisis filter (answer/crisis.ts), offline and free
// in Node 24 with the deployed file. Prints the code layer's level per case (strong = answered in code, weak = the
// Haiku yes/no check decides, null = the normal path, the model) and checks that no case is in Kevin's tests.
//   node scripts/qa/o17b_offline.mjs > reports/qa/data/<stamp>-o17b-offline.json
import { readFileSync } from "node:fs";
import { aboutOther, crisisLevel } from "../../backend/supabase/functions/answer/crisis.ts";

const C = JSON.parse(readFileSync(new URL("./o17b_cases.json", import.meta.url), "utf8"));
const K = JSON.parse(readFileSync(new URL("../k21-crisis-cases.json", import.meta.url), "utf8"));
const seen = new Set(Object.values(K).flat().map((s) => String(s).toLowerCase().trim()));
const all = [...C.crisis.map((x) => x[1]), ...C.other, ...C.false, ...C.border];
const overlap = all.filter((t) => seen.has(t.toLowerCase().trim()));

const row = (kind, group, t) => ({ kind, group, t, level: crisisLevel(t), other: aboutOther(t) });
const rows = [
  ...C.crisis.map(([g, t]) => row("crisis", g, t)),
  ...C.other.map((t) => row("other", "other", t)),
  ...C.false.map((t) => row("false", "false", t)),
  ...C.border.map((t) => row("border", "border", t)),
];
const count = (k) => {
  const r = rows.filter((x) => x.kind === k);
  return { n: r.length, strong: r.filter((x) => x.level === "strong").length, weak: r.filter((x) => x.level === "weak").length, none: r.filter((x) => !x.level).length };
};
const byGroup = {};
for (const r of rows.filter((x) => x.kind === "crisis")) {
  const g = (byGroup[r.group] ??= { n: 0, strong: 0, weak: 0, none: 0 });
  g.n++; g[r.level ?? "none"]++;
}
console.log(JSON.stringify({ overlap_with_kevin: overlap, crisis: count("crisis"), crisis_by_group: byGroup, other: count("other"), false: count("false"), border: count("border"),
  crisis_not_strong: rows.filter((r) => r.kind !== "false" && r.kind !== "border" && r.level !== "strong"),
  false_hits: rows.filter((r) => r.kind === "false" && r.level), rows }, null, 1));
