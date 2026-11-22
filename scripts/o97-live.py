"""O97 (Kevin moln 2026-11-22): while Anthropic's credits are gone, /exam and /answer both answer 503 provider_quota
(fallback true) with a message for the user, in English or Swedish after the chosen language. Test accounts; the
calls fail before any model work, so they cost nothing (0 ElevenLabs). When the credits are back the script says so
(200) instead of failing. Usage (kevin-live.yml): python -X utf8 scripts/o97-live.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, urllib.error, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
res = {}
EN, SV = "EarMind is down for a moment. Try again later.", "EarMind är nere en stund. Försök igen senare."


def call(fn, body, lang):
    tok = T.signup()[0]
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=json.dumps(body).encode(), method="POST", headers=T.headers(tok, True, {"x-earmind-lang": lang}))
    try:
        with urllib.request.urlopen(r, timeout=120) as x:
            return x.status, x.read()[:300].decode(errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")[:400]


TEXT = "Fotosyntesen sker i växternas blad. Med ljus, vatten och koldioxid bildar växten glukos och syre."
for fn, body in (("exam", {"action": "drill", "text": TEXT, "questions": 3, "answers": False}),
                 ("answer", {"fragment": "vad är fotosyntes", "mode": "push_to_talk", "language": "sv", "context": {}})):
    for lang, want in (("en", EN), ("sv", SV)):
        st, raw = call(fn, body, lang)
        if st == 200:
            print(f"INFO {fn} {lang}: 200 – the credits are back", flush=True)
            res[f"{fn} {lang}"] = True
            continue
        try:
            err = json.loads(raw).get("error") or {}
        except ValueError:
            err = {}
        good = st == 503 and err.get("code") == "provider_quota" and err.get("fallback") is True and err.get("message") == want
        res[f"{fn} {lang}"] = good
        print(("PASS " if good else "FAIL ") + f"{fn} {lang}", json.dumps({"status": st, "error": err or raw[:200]}, ensure_ascii=False), flush=True)
n = sum(res.values())
print(f"=== O97: {n} av {len(res)}")
_s.exit(0 if n == len(res) else 1)
