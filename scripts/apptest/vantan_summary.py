"""T15 (Toby): the waiting question. Reads <dir>/retest-vantan.json, writes Markdown to stdout.

    python3 -I scripts/apptest/vantan_summary.py apptest-out/retest

For each turn: heard -> call (the app's own "Turn timing" line), and every A70 line "A question waits 3 s: ..."
word for word. For every answer: when Lumen's voice stopped (the test's speech-end, from speaker.isSpeaking) and the
next "STT input open". Simulator only: never a verification on a device.
"""
import json
import pathlib
import re
import sys


def parse(line: str):
    match = re.match(r"\s*([0-9.]+) (\S+) ?(.*)", line)
    return (float(match.group(1)), match.group(2), match.group(3)) if match else None


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "apptest-out/retest")
    paths = sorted(root.rglob("retest-vantan.json"))
    if not paths:
        print("No retest-vantan.json.")
        return
    data = json.loads(paths[0].read_text(encoding="utf-8"))
    events = [e for e in (parse(line) for line in data["log"]) if e]

    print("# T15: den väntande frågan (simulator, inte enhet)\n")
    cases = data["cases"]
    answered = sum(1 for c in cases if c["answered"])
    print(f"Besvarade {answered} av {len(cases)}. Sessionen: {data['seconds']:.0f} s, `{data['endState']}`.\n")

    print("## Fallen\n")
    print("| Fall | Sagt | Ställt | Svar | Utfall |")
    print("|---|---|---|---|---|")
    for c in cases:
        print(f"| {c['id']} | {c['text']} | {' / '.join(c['asked']) or '–'} | {len(c['answered'])} | {c['verdict']} |")

    print("\n## Hört → anrop per tur (appens `Turn timing`)\n")
    waits = []
    print("| t (s) | hört → anrop (ms) | väg |")
    print("|---|---|---|")
    for t, kind, text in events:
        if kind == "log" and text.startswith("Turn timing"):
            m = re.search(r"heard→call (\d+) ms", text)
            path = text.split("·")[1].strip() if "·" in text else ""
            if m:
                waits.append(int(m.group(1)))
                print(f"| {t:.1f} | {m.group(1)} | {path} |")
    over = sum(1 for w in waits if w > 4000)
    print(f"\n**{over} av {len(waits)} turer väntade över 4 s.**\n")

    print("## A70: \"A question waits 3 s\" (ordagrant)\n")
    lines = [(t, text) for t, kind, text in events if kind == "log" and "A question waits" in text]
    if not lines:
        print("Ingen rad.\n")
    for t, text in lines:
        print(f"- {t:.1f} s: `{text}`")

    print("\n## Röstens slut → mikrofonen öppen\n")
    print("| röst slut (s) | STT input open (s) | skillnad (s) |")
    print("|---|---|---|")
    gaps = []
    for i, (t, kind, _) in enumerate(events):
        if kind != "speech-end":
            continue
        # The gate this speech closed, and the first opening after it (it can come before the voice reports its end).
        gated = max((e[0] for e in events[:i] if e[1] == "log" and e[2].startswith("STT input gated")), default=None)
        if gated is None:
            continue
        opened = next((e[0] for e in events if e[0] > gated and e[1] == "log" and e[2].startswith("STT input open")), None)
        if opened is not None:
            gaps.append(opened - t)
            print(f"| {t:.1f} | {opened:.1f} | {opened - t:.1f} |")
    late = sum(1 for g in gaps if g > 1.0)
    print(f"\n**{late} av {len(gaps)} öppnades mer än 1 s efter rösten.**")


if __name__ == "__main__":
    main()
