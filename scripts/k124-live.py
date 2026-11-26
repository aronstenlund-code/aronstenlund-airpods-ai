"""K124 (D267, Kevin moln 2026-11-27), live, 0 ElevenLabs (GET /voices reads the catalog only, no library search):
every voice an ordinary account is offered has a free preview (https preview_url).
Usage (kevin-live.yml): python -X utf8 scripts/k124-live.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
tok = T.signup()[0]
r = urllib.request.Request(T.URL + "/functions/v1/voices", method="GET", headers=T.headers(tok, True))
with urllib.request.urlopen(r, timeout=30) as x:
    j = json.loads(x.read())
cat = j.get("catalog") or []
bad = [v.get("name") for v in cat if not str(v.get("preview_url") or "").startswith("https://")]
print("catalog", len(cat), "voices; without preview:", bad)
ok = len(cat) > 0 and not bad
print(("PASS " if ok else "FAIL ") + "K124: every listed voice has a free preview")
print(f"=== K124: {int(ok)} av 1")
_s.exit(0 if ok else 1)
