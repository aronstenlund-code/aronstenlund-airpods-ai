#!/usr/bin/env python3
"""T17 (Toby): summary of apptest-out/wake/wake-<set>.json as Markdown.

    python3 -I wake_summary.py <out dir> <app ref>
"""
import json
import os
import sys
from collections import defaultdict


def main(out, ref):
    print(f"# T17 wake word, app code {ref}\n")
    print("Simulator, synthetic rooms: never a verification on a device.\n")
    for name, krav in (("wake", "krav ≥ 48/50 besvarade"), ("nowake", "krav ≤ 1/50 falska")):
        path = os.path.join(out, f"wake-{name}.json")
        if not os.path.exists(path):
            print(f"## {name}: no result\n")
            continue
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        cases = data["cases"]
        if name == "wake":
            hit = sum(1 for c in cases if c["answered"])
            woke = sum(1 for c in cases if c["woke"])
            print(f"## wake: {hit}/{len(cases)} besvarade, namnet tolkat {woke}/{len(cases)} ({krav})\n")
        else:
            bad = sum(1 for c in cases if not c["verdict"].startswith("ok"))
            print(f"## nowake: {bad}/{len(cases)} falska väckningar eller svar ({krav})\n")
        if data.get("stoppedEarly"):
            print(f"Stopped early: {data['stoppedEarly']}\n")
        per = defaultdict(lambda: [0, 0])
        for c in cases:
            ok = c["verdict"].startswith("ok")
            for key in (c["cond"], f"{c['rate']} ord/min"):
                per[key][0] += ok
                per[key][1] += 1
        print("| Grupp | rätt |\n|---|---|")
        for key, (ok, n) in sorted(per.items()):
            print(f"| {key} | {ok}/{n} |")
        print()
        wrong = [c for c in cases if not c["verdict"].startswith("ok")]
        if wrong:
            print("| id | rum | fart | text | utfall | hört |\n|---|---|---|---|---|---|")
            for c in wrong:
                heard = " / ".join(c["heard"])[:120]
                print(f"| {c['id']} | {c['cond']} | {c['rate']} | {c['text']} | {c['verdict']} | {heard} |")
            print()


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "main")
