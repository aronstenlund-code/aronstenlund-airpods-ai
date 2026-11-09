"""T5 (Toby): summary of the retest. Reads <dir>/retest-<set>.json, writes Markdown to stdout.

    python3 -I scripts/apptest/retest_summary.py apptest-out/retest

Simulator only: never a verification on a device.
"""
import json
import pathlib
import sys

NAMES = {"fragor": "Frågor: 10 frågor, 3 med fortsättning efter paus",
         "block": "Provläge: 3 frågor och ett önskemål i ett andetag",
         "keyterm": "Provläge: prov med ämnen över 20 tecken"}


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "apptest-out/retest")
    print("# T5: omtest efter A8 och A11 i simulatorn (inte verifierat på enhet)\n")
    found = False
    for name in ["fragor", "block", "keyterm"]:
        paths = sorted(root.rglob(f"retest-{name}.json"))
        if not paths:
            continue
        found = True
        data = json.loads(paths[0].read_text(encoding="utf-8"))
        cases = data["cases"]
        ok = sum(1 for c in cases if c["verdict"].startswith("ok"))
        asked = sum(len(c["asked"]) for c in cases)
        answered = sum(1 for c in cases if c["answered"])
        spoken = sum(1 for c in cases if c["spoken"])
        print(f"## {NAMES[name]}\n")
        print(f"**{ok} av {len(cases)} rätt.** Ställda {asked}, fall med svar {answered}, fall med uppläst svar {spoken}."
              + (f" **Stannade: {data['stoppedEarly']}.**" if data.get("stoppedEarly") else "") + "\n")
        if data.get("endState"):
            print(f"- Läget när sessionen avslutades: `{data['endState']}`\n")
        if name == "keyterm":
            print(f"- Längsta keyterm som skickades: {data.get('longestKeyterm')} tecken")
            print(f"- Scribe vägrade eller bytte till iPhonens igenkänning: "
                  f"{'; '.join(data['refusedOrFellBack']) or 'nej'}")
            for line in data.get("keytermLines", [])[:5]:
                print(f"- `{line}`")
            print()
        print("| Fall | Sagt | Hört | Ställt | Svar | Uppläst | Utfall |")
        print("|---|---|---|---|---|---|---|")
        for c in cases:
            heard = " / ".join(c["heard"]) or "–"
            ask = " / ".join(c["asked"]) or "–"
            print(f"| {c['id']} | {c['text']} | {heard} | {ask} | {len(c['answered'])} | {c['spoken']} | {c['verdict']} |")
        print()
    if not found:
        print("No T5 results found.")


if __name__ == "__main__":
    main()
