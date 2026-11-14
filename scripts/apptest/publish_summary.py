#!/usr/bin/env python3
"""T19 (Toby 1): summary.md from apptest-out/publish/publish.json.  python3 -I publish_summary.py <out dir>"""
import json
import os
import sys

path = os.path.join(sys.argv[1], "publish.json")
print("# T19: Publicera prov med två konton (simulatorn, inte enhet)\n")
if not os.path.exists(path):
    print("Inga resultat (bygget eller testet stoppade före första steget).")
    sys.exit(0)
with open(path, encoding="utf-8") as f:
    steps = json.load(f)
print("| Steg | Tid | Utfall | Detalj |")
print("|---|---|---|---|")
for s in steps:
    print(f'| {s["step"]} | {s["seconds"]:.1f} s | {"ok" if s["ok"] else "**fel**"} | {s["detail"]} |')
print(f'\n**{sum(1 for s in steps if s["ok"])} av {len(steps)} steg ok.**')
