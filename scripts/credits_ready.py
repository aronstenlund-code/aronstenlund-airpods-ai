#!/usr/bin/env python3
"""K18 part 2 and K6 in one run, for when the ElevenLabs credits are back (run by the "Credits ready" workflow).
  1. Are the credits back? One 4-character /tts request; still `provider_quota` = stop here (exit 0, nothing spent).
  2. K18: scripts/k18-pronunciation.py (30 subject terms read by /tts, transcribed by Scribe) -> the misheard terms.
  3. K6: Voice Design previews for the five characters in scripts/k6-voices.json (/voice-lab, service role) ->
     MP3 files in --out (uploaded as an artifact for Aron to listen to). No voice is saved to the account.
Needs SUPABASE_SERVICE_ROLE_KEY for step 3 (without it, step 3 is skipped). About 7 000 ElevenLabs characters.
  python3 scripts/credits_ready.py --out /tmp/credits [--tag before|after]"""
import argparse, base64, datetime, importlib.util, json, os, pathlib, subprocess, sys, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def credits_back(tok: str) -> bool:
    req = urllib.request.Request(URL + "/functions/v1/tts", data=json.dumps({"text": "Hej.", "language": "sv"}).encode(), method="POST",
                                 headers={"apikey": KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=30).read()
        return True
    except urllib.error.HTTPError as e:
        body = e.read()[:200].decode("utf-8", "replace")
        print(f"/tts {e.code}: {body}")
        return False


def previews(out: pathlib.Path, svc: str) -> list[dict]:
    chars = json.load(open(ROOT / "scripts" / "k6-voices.json", encoding="utf-8"))["characters"]
    rows = []
    for c in chars:
        req = urllib.request.Request(URL + "/functions/v1/voice-lab", method="POST",
                                     data=json.dumps({"action": "previews", "voice_description": c["description"], "text": c["text"]}).encode(),
                                     headers={"authorization": "Bearer " + svc, "content-type": "application/json"})
        try:
            j = json.loads(urllib.request.urlopen(req, timeout=120).read())
        except urllib.error.HTTPError as e:
            rows.append({"id": c["id"], "error": e.code})
            print(c["id"], "error", e.code)
            continue
        for i, p in enumerate(j.get("previews", [])):
            f = out / f"k6-{c['id']}-{i + 1}.mp3"
            f.write_bytes(base64.b64decode(p["audio_base_64"]))
            rows.append({"id": c["id"], "name": c["name"], "file": f.name, "generated_voice_id": p.get("generated_voice_id"),
                         "duration_secs": p.get("duration_secs")})
            print(c["id"], f.name, p.get("duration_secs"))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/credits")
    ap.add_argument("--tag", default="before", help="K18 measurement: before (first run) or after (once aliases are in)")
    ap.add_argument("--tokens", default=None)
    ap.add_argument("--only", choices=["all", "k18", "k6"], default="all", help="k6 = only the voice previews (K18 is measured)")
    a = ap.parse_args()
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    PE = load("pe", ROOT / "scripts/provlage-eval.py")
    tok = PE.signup(a.tokens, 4)
    if not credits_back(tok):
        print("::warning::ElevenLabs credits are still out: nothing run, nothing spent")
        return 0
    date = datetime.date.today().isoformat()
    summary = {"date": date}
    # 2. K18
    r = None if a.only == "k6" else subprocess.run([sys.executable, str(ROOT / "scripts/k18-pronunciation.py"), "--tag", a.tag] + (["--tokens", a.tokens] if a.tokens else []),
                       capture_output=True, text=True, encoding="utf-8")
    if r is not None:
        print(r.stdout[-3000:], r.stderr[-1000:])
        try:
            summary["k18"] = json.loads(r.stdout.strip().splitlines()[-1])
        except Exception:
            summary["k18"] = {"error": "see the log"}
    # 3. K6
    svc = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if svc and a.only != "k18":
        print("::add-mask::" + svc)
        summary["k6"] = previews(out, svc)
    else:
        print("::warning::no SUPABASE_SERVICE_ROLE_KEY: K6 previews skipped")
    json.dump(summary, open(ROOT / "reports" / "eval" / f"credits-ready-{date}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(json.dumps({k: v for k, v in summary.items() if k != "k6"}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
