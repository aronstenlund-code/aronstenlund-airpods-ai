"""K108 (D238, Kevin moln): three questions about the present, once each, as an app would ask them. Checks that each
searched (done.usage.web_searches >= 1), has a source (done.source) and never says "cirka det senaste jag vet".
Test accounts (qa_testaccount), so it uses 3 units of the test web cap; 0 ElevenLabs. Run after 00:00 UTC and well
before the nightly eval (about 10 UTC, needs about 29 of 50). Usage: python -X utf8 scripts/k108-now.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, re, time, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
QS = ["vem är Sveriges statsminister just nu", "vad är vädret idag i Stockholm", "kolla scb.se hur många bor i Sverige"]


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
    good = web >= 1 and bool(done.get("source")) and not re.search(r"\bcirka det senaste|det senaste jag vet", text, re.I) and not done.get("web_cap_test")
    ok += good
    print(json.dumps({"q": q, "ok": good, "web_searches": web, "source": done.get("source"), "searching_ms": searching,
                      "web_cap_test": done.get("web_cap_test", False), "svar": text[:220]}, ensure_ascii=False), flush=True)
print(f"=== K108 nuläge: {ok} av {len(QS)} sökte, har källa och gissar inte")
_s.exit(0 if ok == len(QS) else 1)
