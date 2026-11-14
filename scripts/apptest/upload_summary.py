#!/usr/bin/env python3
"""T20 (Toby 1): summary.md from apptest-out/upload/upload-*.json.  python3 -I upload_summary.py <out dir>"""
import glob
import json
import os
import sys

out = sys.argv[1]
rows = []
for path in sorted(glob.glob(os.path.join(out, "upload-*.json"))):
    with open(path, encoding="utf-8") as f:
        rows.append(json.load(f))

order = {"live-1": 0, "live-4": 1, "live-10": 2, "live-30": 3, "flaky-10": 4}
rows.sort(key=lambda r: (order.get(r["name"], 9), r["name"]))

print("# T20: K53, många foton till frågor (simulatorn, inte enhet)\n")
if not rows:
    print("Inga resultat (bygget eller testet stoppade före första fallet).")
    sys.exit(0)

print("| Fall | Foton | Foton totalt | Största foto | Tid | Frågor | Uppladdningar (PUT 200) | Utfall |")
print("|---|---|---|---|---|---|---|---|")
for r in rows:
    puts_ok = sum(1 for e in r["requests"] if e["kind"].startswith("put") and e["outcome"] == "HTTP 200")
    puts_all = sum(1 for e in r["requests"] if e["kind"].startswith("put"))
    outcome = "ok" if r["ok"] else f'{r.get("error")} → "{r.get("userMessage")}"'
    print(f'| {r["name"]} | {r["photos"]} | {r["photoBytes"] / 1e6:.1f} MB | {r["largestPhotoBytes"] / 1e3:.0f} kB, '
          f'{r["largestPhotoPixels"]} px | {r["seconds"]:.1f} s | {len(r["questions"])} | {puts_ok}/{puts_all} | {outcome} |')

print("\n## Anropen per fall\n")
for r in rows:
    print(f'**{r["name"]}**')
    for e in r["requests"]:
        if e["kind"].startswith("put"):
            continue
        print(f'- {e["kind"]}: {e["outcome"]}, {e["bytes"] / 1e3:.0f} kB skickat, {e["ms"]} ms')
    puts = [e for e in r["requests"] if e["kind"].startswith("put")]
    if puts:
        ms = sorted(e["ms"] for e in puts if e["outcome"] == "HTTP 200")
        other = [e["outcome"] for e in puts if e["outcome"] != "HTTP 200"]
        if ms:
            print(f'- PUT: {len(ms)} ok, {ms[0]}–{ms[-1]} ms var' + (f'; övriga: {", ".join(other)}' if other else ""))
        elif other:
            print(f'- PUT: {", ".join(sorted(set(other)))} ({len(other)} försök)')
    print()

print("## Frågorna (live)\n")
for r in rows:
    if r["ok"] and r["questions"]:
        print(f'**{r["name"]}** ({r["subject"]}, {r["grade"]}): {r["covers"]}' + (f' Not: {r["note"]}' if r.get("note") else ""))
        for q in r["questions"]:
            print(f"- {q}")
        print()
