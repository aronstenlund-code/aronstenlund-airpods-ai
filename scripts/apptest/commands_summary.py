"""T6 (Toby): summary of the voice command test. Reads <dir>/**/commands-<mode>.json, writes Markdown to stdout.

    python3 -I scripts/apptest/commands_summary.py apptest-out/commands

Simulator only: never a verification on a device.
"""
import json
import pathlib
import sys
from collections import defaultdict

MODES = ["standard", "prov", "interview", "social", "rizz"]
NAMES = {"standard": "Frågor", "prov": "Provläge", "interview": "Intervju", "social": "Socialt", "rizz": "Rizz"}


def group(case_id: str) -> str:
    return case_id.rsplit("-", 1)[0] if case_id.rsplit("-", 1)[-1].isdigit() else case_id


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "apptest-out/commands")
    results = {}
    for path in sorted(root.rglob("commands-*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        results[data["mode"]] = data
    if not results:
        print("No T6 results found.")
        return

    print("# T6: röstkommandon i simulatorn (inte verifierat på enhet)\n")
    print("| Läge | Fall | Rätt | Varav bara från hörda ord | Fel åtgärd / ingen | Ej hört | Falska träffar (av vanliga meningar) | Stannade |")
    print("|---|---|---|---|---|---|---|---|")
    totals = defaultdict(int)
    for mode in MODES:
        data = results.get(mode)
        if not data:
            continue
        cases = data["cases"]
        ok = [c for c in cases if c["verdict"].startswith("ok")]
        inferred = [c for c in ok if "heard words" in c["verdict"]]
        negatives = [c for c in cases if c["expect"] == "none"]
        false_hits = [c for c in negatives if c["verdict"].startswith("false-hit")]
        not_heard = [c for c in cases if c["verdict"] == "not heard"]
        wrong = [c for c in cases if not c["verdict"].startswith("ok") and c["verdict"] != "not heard" and c["expect"] != "none"]
        stopped = "; ".join(data.get("stoppedEarly", [])) or "–"
        print(f"| {NAMES[mode]} | {len(cases)} | {len(ok)} | {len(inferred)} | {len(wrong)} | {len(not_heard)} | "
              f"{len(false_hits)} av {len(negatives)} | {stopped} |")
        for key, value in [("cases", len(cases)), ("ok", len(ok)), ("false", len(false_hits)), ("neg", len(negatives))]:
            totals[key] += value
    print(f"\n**Totalt:** {totals['ok']} av {totals['cases']} rätt, {totals['false']} falska träffar av {totals['neg']} "
          "vanliga meningar och universella ord utanför sina lägen.\n")

    # Per command group across modes.
    print("## Per kommando (rätt / fall, alla lägen)\n")
    print("| Kommando | Väntat | " + " | ".join(NAMES[m] for m in MODES if m in results) + " |")
    print("|---|---|" + "---|" * len([m for m in MODES if m in results]))
    groups: dict[str, dict[str, list]] = defaultdict(lambda: defaultdict(list))
    expects: dict[str, set] = defaultdict(set)
    order: list[str] = []
    for mode in MODES:
        for case in results.get(mode, {}).get("cases", []):
            name = group(case["id"])
            if name.startswith("sw"):
                name = "switch"
            if name not in order:
                order.append(name)
            groups[name][mode].append(case)
            expects[name].add(case["expect"])
    for name in order:
        cells = []
        for mode in MODES:
            if mode not in results:
                continue
            items = groups[name].get(mode, [])
            if not items:
                cells.append("–")
                continue
            ok = sum(1 for c in items if c["verdict"].startswith("ok"))
            cells.append(f"{ok}/{len(items)}" + ("" if ok == len(items) else " ⚠"))
        shown = ", ".join(sorted(expects[name]))
        if len(shown) > 40:
            shown = "flera"
        print(f"| {name} | {shown} | " + " | ".join(cells) + " |")

    print("\n## Allt som inte blev rätt\n")
    print("Orsak: **STT** = Scribe hörde inte frasen så att den matchar, **app** = orden hördes rätt men appen gjorde "
          "något annat, **matcher** = appens matchning tog en vanlig mening som ett kommando.\n")
    print("| Läge | Fall | Sagt | Väntat | Appen gjorde | Scribe hörde | Utfall | Orsak |")
    print("|---|---|---|---|---|---|---|---|")
    for mode in MODES:
        for case in results.get(mode, {}).get("cases", []):
            if case["verdict"].startswith("ok"):
                continue
            heard = " / ".join(case["heard"]) or "–"
            did = ", ".join(case["actions"]) or "–"
            print(f"| {NAMES[mode]} | {case['id']} | {case['text']} | {case['expect']} | {did} | {heard} | "
                  f"{case['verdict']} | {case['cause'] or '–'} |")

    print("\n## Terminala kommandon: läget efteråt\n")
    print("| Läge | Fall | Sagt | Väntat | Utfall | Efteråt |")
    print("|---|---|---|---|---|---|")
    for mode in MODES:
        for case in results.get(mode, {}).get("cases", []):
            if case.get("after"):
                print(f"| {NAMES[mode]} | {case['id']} | {case['text']} | {case['expect']} | {case['verdict']} | "
                      f"{case['after']} |")


if __name__ == "__main__":
    main()
