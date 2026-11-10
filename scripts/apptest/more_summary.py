"""T7 (Toby): apptest-out/more/more.json -> a Markdown table for the job summary and the report."""
import json
import pathlib
import sys

out = pathlib.Path(sys.argv[1])
path = out / "more.json"
if not path.exists():
    print("No more.json: the test did not get as far as writing it.")
    sys.exit(0)
results = json.loads(path.read_text(encoding="utf-8"))


def sec(value):
    return "-" if value is None else f"{value:.2f}"


def since_open(result, key):
    opened = result.get("windowOpenAt")
    value = result.get(key)
    return None if opened is None or value is None else value - opened


ok = sum(1 for r in results if r["verdict"].startswith("ok"))
print(f"## T7 Mer-fönstret: {ok}/{len(results)} fall rätt (simulator, inte enhet)")
print()
print("| Fall | Ljud | Röst | Fönster | Mikrofonen öppen efter (s) | Stängt efter (s) | Varför | Efter ordet (s): tal / klart | Ord kort → nästa | Domslut |")
print("|---|---|---|---|---|---|---|---|---|---|")
for r in results:
    opened = "öppnades" if r.get("windowOpenAt") is not None else "nej"
    words = f"{r.get('firstAnswerWords') or '-'} → {r.get('answerAfterProbeWords') or '-'}"
    print(f"| {r['id']} | {r['probe']} (+{r['delay']} s) | {r['voice']} | {opened} | {sec(r.get("inputOpenAfterWindow"))} | {sec(since_open(r, "closedAt"))} | "
          f"{r.get('closeReason') or '-'} | {sec(r.get('secondsToSpeech'))} / {sec(r.get('secondsToAnswer'))} | {words} | "
          f"{r['verdict']} |")
print()
for r in results:
    if r.get("enrolled"):
        print(f"- {r['id']}: röstprofil {r['enrolled']}")
