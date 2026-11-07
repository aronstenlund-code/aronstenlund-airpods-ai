#!/usr/bin/env python3
"""Round-to-round comparison: python -I scripts/qa/compare.py <old-round.json> <new-round.json>
Per turn: better / same / worse from the mean of the six grades (threshold 0.2) or a change in the minimum grade.
Prints category table (grades, ttft p50, cost per answer) and the turn list."""
import json, pathlib, statistics as st, sys

DIMS = "kalfus"
def load(p):
    p = pathlib.Path(p)
    d = json.loads(p.read_text(encoding="utf-8"))
    s = json.loads(p.with_name(p.stem + "-scores.json").read_text(encoding="utf-8"))
    return d, s
def g(s, key): return {x: s.get(key, {}).get(x, 5) for x in DIMS}
def mean(s, key): return st.mean(g(s, key).values())
def mn(s, key): return min(g(s, key).values())
def ttft(rows):
    v = [r["ttft_ms"] for r in rows if r["ttft_ms"]]
    return st.median(v) if v else 0

def main():
    sys.stdout.reconfigure(encoding="utf-8")
    d1, s1 = load(sys.argv[1]); d2, s2 = load(sys.argv[2])
    r1 = {r["key"]: r for r in d1["rows"]}
    verdict = {}
    for r in d2["rows"]:
        k = r["key"]
        if k not in r1: verdict[k] = "ny"; continue
        dm = mean(s2, k) - mean(s1, k); dn = mn(s2, k) - mn(s1, k)
        verdict[k] = "bättre" if (dm >= 0.2 or dn >= 1) and dn >= 0 else "sämre" if (dm <= -0.2 or dn <= -1) and dn <= 0 else "lika"
    json.dump(verdict, open(pathlib.Path(sys.argv[2]).with_name("2round-verdict.json"), "w"), ensure_ascii=False, indent=1)
    cats = {}
    for r in d2["rows"]: cats.setdefault(r["cat"], []).append(r)
    cats1 = {}
    for r in d1["rows"]: cats1.setdefault(r["cat"], []).append(r)
    print("| Kategori | Turer | Snitt runda 1 | Snitt runda 2 | Bättre | Lika | Sämre | Under 4 (1→2) | p50 första text ms (1→2) | Kostnad/svar USD (1→2) |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    def row(name, rows2, rows1):
        m2 = st.mean(mean(s2, r["key"]) for r in rows2)
        paired = [r for r in rows2 if r["key"] in r1]
        m1 = st.mean(mean(s1, r["key"]) for r in rows1) if rows1 else float("nan")
        c = lambda v: sum(1 for r in rows2 if verdict[r["key"]] == v)
        l2 = sum(1 for r in rows2 if mn(s2, r["key"]) < 4); l1 = sum(1 for r in rows1 if mn(s1, r["key"]) < 4)
        c1 = st.mean(r["cost_usd"] for r in rows1) if rows1 else float("nan"); c2 = st.mean(r["cost_usd"] for r in rows2)
        print(f"| {name} | {len(rows2)} | {m1:.2f} | {m2:.2f} | {c('bättre')} | {c('lika')} | {c('sämre')} | {l1}→{l2} | {ttft(rows1):.0f}→{ttft(rows2):.0f} | {c1:.5f}→{c2:.5f} |")
    for k, rows in cats.items(): row(k, rows, cats1.get(k, []))
    same = [r for r in d2["rows"] if r["key"] in r1]
    row("TOTALT (de 146 jämförbara)", same, d1["rows"])
    print()
    for r in d2["rows"]:
        k = r["key"]; print(k, verdict[k], round(mean(s1, k), 2) if k in r1 else "-", round(mean(s2, k), 2), (s2.get(k) or {}).get("note", ""))
if __name__ == "__main__": main()
