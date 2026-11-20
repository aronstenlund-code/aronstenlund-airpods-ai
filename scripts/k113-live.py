"""K113 (D247, Kevin moln 2026-11-20): the question log in Repetitionsläget only for test accounts and for the one who
shares (D57, share_history: true). Live from Actions, where every call is test traffic (K105: CI addresses), so this shows
the test path: a text drill saved without audio (defer_audio, 0 ElevenLabs) and its press statistics answer logged: true.
The ordinary user's path (logged: false) cannot be reached from Actions by design and is verified in drill/handler_test.ts.
Usage (kevin-live.yml): python -X utf8 scripts/k113-live.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, urllib.error, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")


def call(body, tok):
    r = urllib.request.Request(T.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST", headers=T.headers(tok, True))
    r.add_header("x-earmind-test", "kevin-k113")
    try:
        with urllib.request.urlopen(r, timeout=60) as x:
            return x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


tok = T.signup()[0]
st, d = call({"action": "save", "defer_audio": True, "drill": {"kind": "text", "title": "K113 (QA)", "subject": "Historia"},
              "items": [{"kind": "para", "text": "En kort text om Gustav Vasa för K113."}]}, tok)
st2, s = call({"action": "stats", "id": (d.get("drill") or {}).get("id"), "presses": {"1": 1, "2": 0, "3": 0}}, tok)
ok = st == 200 and st2 == 200 and s.get("logged") is True
print(json.dumps({"save": st, "stats": st2, "logged": s.get("logged"), "audio_started": (d.get("drill") or {}).get("audio_started")}, ensure_ascii=False))
print("=== K113 test path logged:", ok)
_s.exit(0 if ok else 1)
