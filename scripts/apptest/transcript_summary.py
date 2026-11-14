#!/usr/bin/env python3
"""T17c (Toby 1): summary.md from apptest-out/transcript/transcript-*.json.  python3 -I transcript_summary.py <out dir>"""
import glob
import json
import os
import sys

out = sys.argv[1]
print("# T17c: lyssningen med inspelade och skrivna transkript, 0 ElevenLabs (simulatorn, inte enhet)\n")
files = sorted(glob.glob(os.path.join(out, "transcript-*.json")))
if not files:
    print("Inga resultat.")
    sys.exit(0)
for path in files:
    with open(path, encoding="utf-8") as f:
        r = json.load(f)
    cases = r["cases"]
    wake = [c for c in cases if c["expect"] in ("wake", "pair")]
    nowake = [c for c in cases if c["expect"] == "nowake"]
    answered = sum(1 for c in wake if c["answered"])
    unheard = sum(1 for c in wake if not c["fed"])
    false = sum(1 for c in nowake if not c["verdict"].startswith("ok"))
    empty = sum(1 for c in cases for x in c["failed"] if "empty_answer" in x)
    print(f'## {r["set"]}\n')
    print(f"- Besvarade: **{answered}/{len(wake)}** (varav {unheard} där Scribe inte hörde något i den inspelade körningen)")
    if nowake:
        print(f"- Falska utan namnet: **{false}/{len(nowake)}**")
    print(f"- empty_answer: **{empty}**")
    print(f'- ElevenLabs/Scribe-rader i loggen: **{len(r["elevenLabs"])}**')
    bad = [c for c in cases if not c["verdict"].startswith("ok")]
    if bad:
        print("\n| id | rum | inmatat | utfall |\n|---|---|---|---|")
        for c in bad:
            fed = " / ".join(c["fed"])[:90].replace("|", "/")
            print(f'| {c["id"]} | {c["cond"]} | {fed} | {c["verdict"][:120]} |')
    print()
