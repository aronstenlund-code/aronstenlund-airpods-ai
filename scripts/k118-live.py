"""Toby T56 / Oscar O96 (Kevin moln 2026-11-21): live with test accounts, 0 ElevenLabs.
(1) GET /stt-token with x-earmind-test "… question" gives a fake transcript that is a question (sv; en with
    x-earmind-lang: en), and without "question" the old sentence; never a token. (2) The question is answered by /answer
    (tutor, as the web's listening mode). (3) done carries no crisis_marker for an ordinary question.
Usage (kevin-live.yml): python -X utf8 scripts/k118-live.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
res = {}


def ok(name, cond, info):
    res[name] = bool(cond)
    print(("PASS " if cond else "FAIL ") + name, json.dumps(info, ensure_ascii=False)[:300], flush=True)


tok = T.signup()[0]


def stt(extra):
    r = urllib.request.Request(T.URL + "/functions/v1/stt-token", method="GET", headers=T.headers(tok, True, extra))
    return json.loads(urllib.request.urlopen(r, timeout=30).read())


d = stt({"x-earmind-test": "kevin-k118"})
ok("default transcript unchanged", d.get("fake") and d.get("token") is None and d.get("transcript") == "Det här är en testtranskription.", d)
q_sv = stt({"x-earmind-test": "kevin-k118 question"})
ok("question (sv)", q_sv.get("transcript") == "Vad gör fotosyntesen?" and q_sv.get("token") is None, q_sv)
q_en = stt({"x-earmind-test": "kevin-k118 question", "x-earmind-lang": "en"})
ok("question (en)", q_en.get("transcript") == "What does photosynthesis do?" and q_en.get("language_code") == "eng", q_en)

said, done = "", {}
r = urllib.request.Request(T.URL + "/functions/v1/answer", data=json.dumps({"fragment": q_sv["transcript"], "mode": "tutor", "language": "sv", "lang": "sv", "length": "adaptive", "context": {"recent_qa": []}}).encode(),
                           method="POST", headers=T.headers(tok, True))
with urllib.request.urlopen(r, timeout=90) as x:
    ev = None
    for line in x:
        line = line.decode().rstrip("\n")
        if line.startswith("event: "):
            ev = line[7:]
        elif line.startswith("data: "):
            j = json.loads(line[6:])
            if ev == "delta":
                said += j.get("text", "")
            elif ev == "done":
                done = j
ok("the question is answered (tutor)", done.get("answered") is True and len(said) > 10, {"answered": done.get("answered"), "said": said[:160]})
ok("no crisis_marker on an ordinary question", "crisis_marker" not in done, {"crisis_marker": done.get("crisis_marker")})
n = sum(res.values())
print(f"=== K118: {n} av {len(res)}")
_s.exit(0 if n == len(res) else 1)
