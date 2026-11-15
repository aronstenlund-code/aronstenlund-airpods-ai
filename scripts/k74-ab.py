#!/usr/bin/env python3
"""K74 part 3: A/B listening test, Multilingual v2 against v4 and v4 with one pause tag between question and answer.
Five ordinary A answers (question + short answer, made with the drill's voice text, rules version 2) from
backend/testdata/voice/k74-ab-texts.json, read by the app's default voice through /voice-lab "sample" (service role).
15 files, about 3 050 ElevenLabs characters. The names are shuffled (1A, 1B, 1C ...); which is which goes only to
FACIT.md (for Deangelo), as in the K48 blind test.

D180: ElevenLabs is never used for testing without Aron's explicit yes. This script does NOTHING unless both hold:
  --yes-from-aron "<Aron's words and the time, copied from the chat>"   and   K74_AB_CONFIRM=aron-ja
It refuses when the total is over 3 200 characters. NOT RUN by Kevin (2026-11-15).
  K74_AB_CONFIRM=aron-ja python3 scripts/k74-ab.py --yes-from-aron "Aron 18:02: ja, kör A/B" --out docs/rost-ab-k74
Needs SUPABASE_SERVICE_ROLE_KEY (a GitHub secret; run it in a workflow like voice-blindtest.yml)."""
import argparse, base64, datetime, json, os, pathlib, random, sys, urllib.request

URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
HERE = pathlib.Path(__file__).resolve().parent
TEXTS = HERE.parent / "backend" / "testdata" / "voice" / "k74-ab-texts.json"
MAX_TOTAL = 3200


def plan():
    d = json.loads(TEXTS.read_text(encoding="utf-8"))
    jobs = []
    for n, it in enumerate(d["items"], 1):
        jobs += [(n, "v2", "eleven_multilingual_v2", it["plain"]), (n, "v4", "eleven_v4", it["plain"]), (n, "v4+tag", "eleven_v4", it["tagged"])]
    return d, jobs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yes-from-aron", default="")
    ap.add_argument("--out", default="docs/rost-ab-k74")
    ap.add_argument("--dry-run", action="store_true", help="print the plan and the characters; no call")
    a = ap.parse_args()
    d, jobs = plan()
    total = sum(len(t) for *_, t in jobs)
    print(f"{len(jobs)} files, {total} characters (cap {MAX_TOTAL}), pause tag {d['pause_tag']!r}")
    if a.dry_run:
        for n, label, model, text in jobs:
            print(f"  {n} {label:7} {model:24} {len(text):4}  {text[:70]}")
        return 0
    if os.environ.get("K74_AB_CONFIRM") != "aron-ja" or len(a.yes_from_aron.strip()) < 8:
        print("D180: not run. Needs Aron's yes in chat: --yes-from-aron \"...\" and K74_AB_CONFIRM=aron-ja.")
        return 2
    if total > MAX_TOTAL:
        print("over the character cap, not run")
        return 3
    svc = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not svc:
        print("SUPABASE_SERVICE_ROLE_KEY missing")
        return 1
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    facit, spent = [], 0
    for n in sorted({j[0] for j in jobs}):
        group = [j for j in jobs if j[0] == n]
        letters = random.sample("ABC", 3)
        for (n_, label, model, text), letter in zip(group, letters):
            req = urllib.request.Request(URL + "/functions/v1/voice-lab", method="POST",
                                         data=json.dumps({"action": "sample", "text": text, "model": model}).encode(),
                                         headers={"authorization": "Bearer " + svc, "content-type": "application/json"})
            with urllib.request.urlopen(req, timeout=120) as r:
                j = json.load(r)
            name = f"{n}{letter}.mp3"
            (out / name).write_bytes(base64.b64decode(j["audio_base_64"]))
            spent += int(j.get("character_cost") or len(text))
            facit.append(f"- {name}: {label} ({model}), {len(text)} tecken, kostnad {j.get('character_cost')}")
    (out / "FACIT.md").write_text(f"# K74 A/B facit ({datetime.date.today()})\n\nGodkänt: {a.yes_from_aron}\n\n" + "\n".join(facit) + f"\n\nTotalt {spent} tecken.\n", encoding="utf-8")
    (out / "README.md").write_text("# Lyssna: 1A–5C\n\nVarje nummer är samma fråga och svar i tre versioner (A, B, C i slumpad ordning). Vilken låter mest naturlig?\n", encoding="utf-8")
    print(f"done, {spent} characters")
    return 0


if __name__ == "__main__":
    sys.exit(main())
