"""O101 (Oscar moln, 2026-11-26): Apples granskares väg mot servern i dag, punkt för punkt mot docs/appstore/granskning.md
§3 (Ke84/Ke90). Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o101_reviewer_today.py
Ett nytt anonymt testkonto med "user-path" (D240: serverns uppskattning som för en vanlig användare), falskt ljud,
0 ElevenLabs, inga modellanrop som kostar (krediterna är slut: stil, prov och komprimera ska ge 503 provider_* med text).
Skriver bara ut; varje rad är ett påstående i granskningsanteckningarna."""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE))
import qa_testaccount as T  # noqa: E402
T.install()
import json, time, urllib.error, urllib.request, uuid  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
UP = {"x-earmind-test": "oscar-qa user-path"}
ROWS = []


def req(method, fn, body=None, tok=None, extra=None, timeout=90):
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=json.dumps(body).encode() if body is not None else None,
                               method=method, headers=T.headers(tok, True, {**UP, **(extra or {})}))
    try:
        with urllib.request.urlopen(r, timeout=timeout) as x:
            return x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read() or b"{}"
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw[:200].decode(errors="replace")}


def row(point, claim, verdict, detail):
    ROWS.append((point, claim, verdict))
    print(f"[{verdict}] {point}: {claim}\n     {json.dumps(detail, ensure_ascii=False)[:900]}", flush=True)


def e(j):
    x = j.get("error") or {}
    return {"kod": x.get("code"), "text": x.get("message")}


tok = T.signup(True)[0]
s, q = req("POST", "drill", {"action": "quota"}, tok)
row("intro", "No sign-in is needed (anonymous account)", "stämmer" if s == 200 else "stämmer inte", {"status": s})
row("4", "Every account gets 1,500 free credits per month", "stämmer" if q.get("limit") == 1500 and not (q.get("gift") or {}).get("welcome") else "stämmer inte",
    {k: q.get(k) for k in ("limit", "monthly_free", "used", "remaining", "gift", "exam", "resets")})

# 1. Say in AirPods 10 min, a normal short study text (new text each run)
SAY = f"Fotosyntesen sker i bladen. Växten gör socker av ljus, vatten och koldioxid, och syre släpps ut. ({uuid.uuid4().hex[:6]})"
body = {"drill": {"kind": "text", "title": "O101 Säg (QA)", "said": True, "client_id": str(uuid.uuid4())}, "items": [{"kind": "para", "text": SAY}]}
s, c = req("POST", "drill", {"action": "cost", **body}, tok)
s2, j2 = req("POST", "drill", {"action": "save", "start": True, **body}, tok)
did = (j2.get("drill") or {}).get("id")
done = False
for _ in range(10):
    _, st = req("POST", "drill", {"action": "status", "id": did}, tok)
    a = st.get("audio") or {}
    if a.get("total") and a.get("done") == a.get("total"):
        done = True
        break
    time.sleep(3)
_, q2 = req("POST", "drill", {"action": "quota"}, tok)
row("1/4", "1,500 credits are enough to try Say in AirPods (repeats free)", "stämmer" if s2 == 200 and done and (c.get("cost") or 0) <= 1500 else "stämmer inte",
    {"kostnad före": c.get("cost"), "save": s2, "ljud klart": done, "drogs": (q2.get("used") or 0) - (q.get("used") or 0), "kvar": q2.get("remaining")})
s3, _ = req("POST", "drill", {"action": "start", "id": did}, tok)
_, q3 = req("POST", "drill", {"action": "quota"}, tok)
row("4", "Repeats and existing audio are free", "stämmer" if s3 == 200 and q3.get("used") == q2.get("used") else "stämmer inte",
    {"start igen": s3, "drogs": (q3.get("used") or 0) - (q2.get("used") or 0)})

# 1. "How should it sound?" (style: a model call; the model is down today)
st_body = {"drill": {"kind": "text", "title": "O101 stil (QA)", "said": True, "style": "Lugnt och tydligt, som en lärare", "client_id": str(uuid.uuid4())},
           "items": [{"kind": "para", "text": SAY + " stil"}]}
s, j = req("POST", "drill", {"action": "cost", **st_body}, tok)
row("1", "\"How should it sound?\" lets the user describe a style (model)", "går inte att prova nu" if s in (502, 503) else ("stämmer" if s == 200 else "stämmer inte"),
    {"status": s, **e(j), "cost": j.get("cost")})

# 1. voices: previews free, catalogue
r = urllib.request.Request(T.URL + "/functions/v1/voices", method="GET", headers=T.headers(tok, True, UP))
with urllib.request.urlopen(r, timeout=30) as x:
    v = json.loads(x.read())
cat = v.get("catalog") or []
_, q4 = req("POST", "drill", {"action": "quota"}, tok)
row("1", "The user picks a voice from the voice sheet (previews are free)", "stämmer" if len(cat) >= 10 and all(c.get("preview_url") for c in cat) and q4.get("used") == q3.get("used") else "stämmer inte",
    {"röster": len(cat), "med provljud": sum(1 for c in cat if c.get("preview_url")), "drogs": (q4.get("used") or 0) - (q3.get("used") or 0)})

# 2/4. Start quiz: a quiz from text with 1,500 credits
TXT = ("Fotosyntesen sker i växternas gröna blad. Klorofyllet fångar solljuset. Växten tar upp vatten genom rötterna och "
       "koldioxid genom klyvöppningarna. Av detta bildas glukos och syre. Glukosen används som energi och byggmaterial. ") * 6
s, j = req("POST", "exam", {"action": "drill", "answers": False, "questions": 12, "subject": "Biologi", "pages": [], "text": TXT, "lang": "en"}, tok, {"x-earmind-lang": "en"})
fits = j.get("fits")
row("4", "the quiz screen suggests a number of questions that fits the credits",
    "stämmer inte" if s == 402 and (fits or 0) < (j.get("min_questions") or 3) else ("stämmer" if s == 402 and fits else "går inte att prova nu"),
    {"status": s, **e(j), "fits": fits, "per_question": j.get("per_question"), "min_questions": j.get("min_questions"), "remaining": j.get("remaining")})
s, j = req("POST", "exam", {"action": "drill", "answers": False, "questions": 3, "subject": "Biologi", "pages": [], "text": TXT, "lang": "en"}, tok, {"x-earmind-lang": "en"})
row("2", "Start quiz: text becomes quiz questions (Claude)", "går inte att prova nu" if s in (502, 503) else ("stämmer" if s == 200 else "stämmer inte"),
    {"status": s, **e(j), "fits": j.get("fits")})

# 7. Compress, 9. server can't answer
s, j = req("POST", "exam", {"action": "compress", "text": TXT[:400], "lang": "en"}, tok, {"x-earmind-lang": "en"})
row("7", "Compress: shortened by our server, or the phone's model if the server can't", "stämmer (servern säger nej rätt; telefonens modell provas inte här)" if s == 503 and (j.get("error") or {}).get("code") == "provider_quota" else ("stämmer" if s == 200 else "stämmer inte"),
    {"status": s, **e(j)})
s, j = req("POST", "answer", {"fragment": "what is photosynthesis", "mode": "text", "language": "en", "lang": "en", "context": {"recent_qa": []}}, tok, {"x-earmind-lang": "en"})
row("9", "When our server can't answer, the app uses the phone's model (server gives a clear code)", "stämmer (serverdelen)" if s == 503 and (j.get("error") or {}).get("code", "").startswith("provider_") else "stämmer inte",
    {"status": s, **e(j)})

# 4. invitation and welcome
s, j = req("POST", "purchase", {"action": "invite_code"}, tok)
row("4", "Inviting a friend gives 2,000 credits after the friend plays a first text", "går inte att prova nu" , {"invite_code": s, "kod": bool(j.get("code")), "url": j.get("url"), "status": {k: j.get(k) for k in j if k not in ("code", "url", "app_url")}})
s, j = req("POST", "purchase", {"action": "attest_challenge"}, tok)
row("före inskickning", "Welcome credits (5,000) need Team ID and App Attest", "stämmer (välkomsten är av)" if s == 503 else ("stämmer inte" if s == 200 else "?"), {"status": s, **e(j)})

# 4. purchases verified on our server (fake receipt refused); Sandbox cap only in test
FIX = json.loads((HERE / "o78" / "fixtures.json").read_text())
s, j = req("POST", "purchase", {"action": "verify", "jws": FIX["fake_chain_jws"]}, tok)
row("4", "Purchases are verified on our server", "stämmer" if s == 422 else "stämmer inte", {"falskt kvitto": s, **e(j)})

# 5. Delete account
s, j = req("POST", "account", {"action": "delete", "confirm": True}, tok)
s2, j2 = req("POST", "drill", {"action": "quota"}, tok)
row("5", "The account and everything on the server can be deleted in the app", "stämmer" if s == 200 and s2 in (401, 403) else "stämmer inte",
    {"delete": s, "svar": {k: j.get(k) for k in list(j)[:6]}, "samma token efteråt": s2})

print("\n| punkt | påstående | resultat |\n|---|---|---|")
for p, c, v in ROWS:
    print(f"| {p} | {c} | {v} |")
