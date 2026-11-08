"""T1 (Toby): a Markdown summary of apptest-out/chain/*.json (one table per set: spoken vs heard, asked, answered)."""
import json
import sys
from pathlib import Path


def main(out: Path) -> None:
    print("## Ljudkedjan (T1, simulator)\n")
    print("Simulator only, never a verification on a device. Live Scribe and /answer, answers not spoken.\n")
    results = sorted(out.glob("*.json"))
    if not results:
        print("No result files (the test did not get as far as writing them).")
        return
    for path in results:
        r = json.loads(path.read_text(encoding="utf-8"))
        print(f"### {r['set']} ({r['mode']}), {r['seconds']:.0f} s\n")
        print(f"Spoken {len(r['spoken'])} · heard {r['heard']} · asked {r['asked']} · answered {r['answered']}"
              + (" · **stopped by itself**" if r.get("crashedOrStopped") else "") + "\n")
        if r.get("keytermsHeard"):
            terms = ", ".join(f"{k} {'ja' if v else '**nej**'}" for k, v in sorted(r["keytermsHeard"].items()))
            print(f"Ämnesord rätt: {terms}\n")
        print("| t (s) | Händelse | Text |")
        print("|---:|---|---|")
        for e in r["events"]:
            text = e["text"].replace("|", "/").replace("\n", " ")
            if len(text) > 160:
                text = text[:157] + "…"
            extra = f" ({e['firstTextMs']:.0f} ms)" if e.get("firstTextMs") else ""
            print(f"| {e['t']:.1f} | {e['kind']}{extra} | {text} |")
        print("\nSagt (manus):\n")
        for line in r["spoken"]:
            print(f"- {line}")
        print()


if __name__ == "__main__":
    main(Path(sys.argv[1]))
