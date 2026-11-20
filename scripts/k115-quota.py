"""Angela Fable A154 (Kevin moln 2026-11-20): /drill quota with long_words answers exam {per_question, min_questions,
long_words} (K110's upper bound) and suggest 12. 0 ElevenLabs, 0 Claude. Usage (kevin-live.yml)."""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
tok = T.signup()[0]
out, ok = {}, True
for lw, want in ((90, 642), (130, 894), (None, 642)):
    body = {"action": "quota", **({"long_words": lw} if lw else {})}
    r = urllib.request.Request(T.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST", headers=T.headers(tok, True))
    q = json.loads(urllib.request.urlopen(r, timeout=60).read())
    out[str(lw)] = {"exam": q.get("exam"), "suggest": q.get("suggest"), "remaining": q.get("remaining")}
    ok &= (q.get("exam") or {}).get("per_question") == want and q.get("suggest") == 12
print(json.dumps(out, ensure_ascii=False))
print("=== A154 quota exam:", ok)
_s.exit(0 if ok else 1)
