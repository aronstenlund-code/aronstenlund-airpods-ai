"""D239 (Toby T24/T28, Kevin moln 2026-11-26), live, no model call, 0 ElevenLabs: a new account's /drill quota prices
the smallest exam (3 questions) so that it fits its free credits (long answers shortened, fitted: true).
Usage (kevin-live.yml): python -X utf8 scripts/d239-live.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, urllib.error, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
tok = T.signup()[0]
r = urllib.request.Request(T.URL + "/functions/v1/drill", data=json.dumps({"action": "quota", "long_words": 90}).encode(), method="POST", headers=T.headers(tok, True))
try:
    with urllib.request.urlopen(r, timeout=60) as x:
        st, j = x.status, json.loads(x.read())
except urllib.error.HTTPError as e:
    st, j = e.code, {"error": e.read()[:200].decode()}
ex, left = j.get("exam") or {}, j.get("remaining")
print("quota", json.dumps({"status": st, "remaining": left, "unlimited": j.get("unlimited"), "exam": ex}, ensure_ascii=False))
fits = bool(ex) and isinstance(left, int) and ex.get("per_question", 10**9) * ex.get("min_questions", 3) <= left
ok = st == 200 and (j.get("unlimited") or fits)
print(("PASS " if ok else "FAIL ") + "D239: the smallest exam fits a new account's free credits", json.dumps({"fitted": ex.get("fitted"), "long_words": ex.get("long_words")}))
print(f"=== D239: {int(ok)} av 1")
_s.exit(0 if ok else 1)
