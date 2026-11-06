#!/usr/bin/env python3
"""Turns one round's raw data + Oscar's score file into the Markdown table for the report.

  python -I scripts/qa/score.py reports/qa/data/2026-11-06-1737-full.json

The score file is <round>-scores.json and lists deductions only; anything not listed is a 5.
"""
import json
import pathlib
import statistics as st
import sys

DIMS = ["k", "a", "l", "f", "u", "s"]
HEAD = "| Kategori | Turer | Korrekt | Avsikt | Längd | Ingen utfyllnad | Uppläsbar | Sammanhang | Snitt | Under 4 | Första text p50 (ms) |"


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    path = pathlib.Path(sys.argv[1])
    data = json.loads(path.read_text(encoding="utf-8"))
    scores = json.loads(path.with_name(path.stem + "-scores.json").read_text(encoding="utf-8"))
    cats = {}
    for r in data["rows"]:
        cats.setdefault(r["cat"], []).append(r)
    cats["TOTALT"] = data["rows"]
    print(HEAD)
    print("|---|" + "---:|" * 10)
    for cat, rows in cats.items():
        mean = {d: st.mean(scores.get(r["key"], {}).get(d, 5) for r in rows) for d in DIMS}
        overall = st.mean(mean.values())
        low = sum(1 for r in rows if min(scores.get(r["key"], {}).get(d, 5) for d in DIMS) < 4)
        ttft = st.median(r["ttft_ms"] for r in rows if r["ttft_ms"])
        cols = " | ".join(f"{mean[d]:.2f}" for d in DIMS)
        print(f"| {cat} | {len(rows)} | {cols} | {overall:.2f} | {low} | {ttft:.0f} |")


if __name__ == "__main__":
    main()
