#!/usr/bin/env python3
"""Oscar QA: independent review of D87 (Provläge test bank). 40 random cases (seed 8711) from Kevin's haiku-baseline run were
graded by hand BEFORE looking at Kevin's judge scores (my grades are the MINE table below, written from blind.txt which
holds only profile, earlier turns, what was said, the bank's expectation and the answer). This script then compares.
  python -I scripts/qa/d87_review.py > reports/qa/data/2026-11-08-d87-compare.txt"""
import json, pathlib, random, sys
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
rows = json.loads((ROOT / "reports/eval/provlage-2026-11-08-haiku-baseline.json").read_text(encoding="utf-8"))["rows"]
random.seed(8711)
sample = sorted(random.sample(rows, 40), key=lambda r: r["id"])
DIM = ["correct", "a_level", "sufficient", "natural", "length_ok"]
# my grades, case number 1..40 in sample order: correct, a_level, sufficient, natural, length_ok
MINE = {1: "11111", 2: "11111", 3: "11110", 4: "11101", 5: "11111", 6: "11111", 7: "11111", 8: "11111", 9: "11110", 10: "11111",
        11: "11110", 12: "11110", 13: "11111", 14: "11111", 15: "11111", 16: "11101", 17: "11111", 18: "11110", 19: "11110", 20: "11110",
        21: "11111", 22: "11111", 23: "00000", 24: "11111", 25: "11100", 26: "01101", 27: "11100", 28: "01110", 29: "11110", 30: "01100",
        31: "00000", 32: "11111", 33: "11111", 34: "11110", 35: "11110", 36: "01111", 37: "11111", 38: "11110", 39: "11110", 40: "11111"}
agree = {d: 0 for d in DIM}
tab = {d: [0, 0, 0, 0] for d in DIM}  # mine1/k1, mine1/k0, mine0/k1, mine0/k0
first = [0, 0, 0, 0]
dis = []
for i, r in enumerate(sample, 1):
    ks = r["scores"] if isinstance(r["scores"], dict) else json.loads(r["scores"].replace("'", '"'))
    kv = [int(ks[d]) for d in DIM]
    mv = [int(c) for c in MINE[i]]
    for j, d in enumerate(DIM):
        agree[d] += kv[j] == mv[j]
        tab[d][(0 if mv[j] else 2) + (0 if kv[j] else 1)] += 1
    mf, kf = int(mv[0] and mv[2]), int(kv[0] and kv[2])  # Kevin's 'first answer is enough' = correct and sufficient (checked over all 179 rows)
    first[(0 if mf else 2) + (0 if kf else 1)] += 1
    if mv != kv:
        dis.append((i, r["id"], r["kind"], "".join(map(str, mv)), "".join(map(str, kv)), r.get("note", "")))
print("n=40; order of digits: correct a_level sufficient natural length_ok")
for d in DIM:
    a, b, c, e = tab[d]
    n = 40
    po = (a + e) / n
    pm, pk = (a + b) / n, (a + c) / n
    pe = pm * pk + (1 - pm) * (1 - pk)
    kappa = (po - pe) / (1 - pe) if pe < 1 else float("nan")
    print(f"{d:10s} agree {agree[d]}/40 ({po:.0%}); mine ok {a + b}, Kevin ok {a + c}; both ok {a}, only I ok {c}... (mine1/k0={b}, mine0/k1={c}), both fail {e}; kappa {kappa:.2f}")
print("first answer enough (correct AND sufficient, Kevin's definition): both yes %d, I yes Kevin no %d, I no Kevin yes %d, both no %d; agreement %d/40" % (first[0], first[1], first[2], first[3], first[0] + first[3]))
print("mine first-ok %.1f%%, Kevin first-ok %.1f%% (this sample)" % (100 * (first[0] + first[1]) / 40, 100 * (first[0] + first[2]) / 40))
print("\nDISAGREEMENTS (no, id, kind, mine, Kevin, Kevin's note)")
for x in dis:
    print(x[0], x[1], x[2], x[3], x[4], "|", x[5][:230])
