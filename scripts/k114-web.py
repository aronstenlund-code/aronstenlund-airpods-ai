"""O91 N5 (Kevin moln 2026-11-20): Oscar's two long web answers, once each: at most 80 spoken words, a source, searched.
(Built on k108-now.py.)
Test accounts (qa_testaccount), so it uses 3 units of the test web cap; 0 ElevenLabs. Run after 00:00 UTC and well
before the nightly eval (about 10 UTC, needs about 29 of 50). Usage: python -X utf8 scripts/k108-now.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, re, time, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
QS = ["hur byter man däck", "recept på köttbullar"]


def post(path, body, tok=None):
    h = {"apikey": T.KEY, "content-type": "application/json"}
    if tok:
        h["Authorization"] = "Bearer " + tok
    return urllib.request.urlopen(urllib.request.Request(T.URL + path, data=json.dumps(body).encode(), headers=h), timeout=90)


tok = json.load(post("/auth/v1/signup", {}))["access_token"]
ok = 0
for q in QS:
    t0, text, done, searching = time.time(), "", {}, None
    with post("/functions/v1/answer", {"fragment": q, "mode": "text", "language": "sv", "context": {"recent_qa": []}}, tok) as r:
        ev = None
        for line in r:
            line = line.decode().rstrip("\n")
            if line.startswith("event: "):
                ev = line[7:]
            elif line.startswith("data: "):
                d = json.loads(line[6:])
                if ev == "delta":
                    text += d.get("text", "")
                elif ev == "searching":
                    searching = searching or int((time.time() - t0) * 1000)
                elif ev == "done":
                    done = d
    web = (done.get("usage") or {}).get("web_searches") or 0
    spoken = re.sub(r"\s*Källa:[^.]*\.?\s*$", "", text)
    good = web >= 1 and bool(done.get("source")) and len(spoken.split()) <= 80 and not done.get("web_cap_test")
    ok += good
    print(json.dumps({"q": q, "ok": good, "web_searches": web, "source": done.get("source"), "searching_ms": searching,
                      "web_cap_test": done.get("web_cap_test", False), "words": len(re.sub(r"\s*Källa:[^.]*\.?\s*$", "", text).split()), "svar": text[:300]}, ensure_ascii=False), flush=True)
print(f"=== O91 N5: {ok} av {len(QS)} sökte, har källa och högst 80 ord")
_s.exit(0 if ok == len(QS) else 1)
