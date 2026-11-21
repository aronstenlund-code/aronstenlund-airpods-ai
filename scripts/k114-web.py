"""K114 (D249, D251; Kevin moln 2026-11-21): the web beta's backend, live. Test accounts, 0 ElevenLabs (no audio is
made: quota reads, one short text answer and one 3-question exam plan; Claude only).
(1) CORS: a preflight from https://earmind.vercel.app (and a Vercel preview URL) is allowed on answer/drill/exam/tts
    and lists x-earmind-lang; another origin is not.
(2) Web guard: calls with the beta's Origin from one network admit 5 accounts a day; the 6th gets 429
    too_many_accounts, in English by default and in Swedish with Accept-Language sv. (Uses the runner's network
    places for the day; nothing else.)
(3) Language: an error message follows Accept-Language / x-earmind-lang; an answer with lang=en is English; an exam
    from an English text has English questions.
Usage (kevin-live.yml): python -X utf8 scripts/k114-web.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, re, time, urllib.error, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")

WEB = "https://earmind.vercel.app"
PREVIEW = "https://earmind-git-angela-beta-aron-cfdc.vercel.app"
results = {}


def req(method, fn, body=None, tok=None, extra=None):
    h = T.headers(tok, True, extra)
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=120) as x:
            return x.status, {k.lower(): v for k, v in x.headers.items()}, x.read()
    except urllib.error.HTTPError as e:
        return e.code, {k.lower(): v for k, v in e.headers.items()}, e.read()


def ok(name, cond, info=None):
    results[name] = bool(cond)
    print(("PASS " if cond else "FAIL ") + name, json.dumps(info, ensure_ascii=False)[:400] if info is not None else "", flush=True)


SV = re.compile(r"\b(och|är|det|som|att|en|ett|på|för|med|inte|vad|hur)\b|[åäö]", re.I)
EN = re.compile(r"\b(the|is|of|and|what|which|how|in|to|a|was|why)\b", re.I)


def english(t):
    return len(EN.findall(t)) >= 2 and len(SV.findall(t)) <= 1


# (1) CORS
for fn in ("answer", "drill", "exam", "tts", "stt-token", "voices"):
    for origin, want in ((WEB, True), (PREVIEW, True), ("https://evil.example", False)):
        st, h, _ = req("OPTIONS", fn, extra={"origin": origin, "access-control-request-method": "POST",
                                             "access-control-request-headers": "authorization,content-type,x-earmind-lang,x-earmind-test"})
        acao = h.get("access-control-allow-origin")
        allowed = acao == origin
        hdrs = (h.get("access-control-allow-headers") or "").lower()
        good = allowed == want and (not want or ("x-earmind-lang" in hdrs and "x-earmind-test" in hdrs))
        ok(f"cors {fn} {origin.split('//')[1][:24]}", good, {"status": st, "acao": acao, "lang_header": "x-earmind-lang" in hdrs})

# (2) web guard: 5 accounts per network and day from the web
codes = []
for i in range(7):
    tok = T.signup()[0]
    lang = {"accept-language": "sv-SE,sv;q=0.9"} if i == 6 else {"accept-language": "en-US,en;q=0.9"}
    st, h, raw = req("POST", "drill", {"action": "quota"}, tok, {"origin": WEB, **lang})
    j = json.loads(raw or b"{}")
    codes.append((st, (j.get("error") or {}).get("code"), (j.get("error") or {}).get("message")))
    time.sleep(1)
print("web guard", json.dumps(codes, ensure_ascii=False))
# The runner's network may already have used places today (an earlier run): the first denial must be too_many_accounts
first_denied = next((k for k, c in enumerate(codes) if c[0] != 200), None)
ok("web guard admits at most 5 accounts", first_denied is not None and first_denied <= 5 and all(c[0] == 200 for c in codes[:first_denied]), codes)
ok("web guard 429 too_many_accounts", all(c[0] == 429 and c[1] == "too_many_accounts" for c in codes[first_denied:]) if first_denied is not None else False)
ok("web guard English by default", first_denied is not None and first_denied < 6 and (codes[first_denied][2] or "").startswith("Too many new accounts"), codes[first_denied] if first_denied is not None else None)
ok("web guard Swedish with Accept-Language sv", (codes[6][2] or "").startswith("För många nya konton"), codes[6])
# The app (no Origin) is not counted
tok = T.signup()[0]
st, _, _ = req("POST", "drill", {"action": "quota"}, tok)
ok("app call (no Origin) not limited", st == 200, {"status": st})

# (3a) error language: the same error in English and in Swedish
for lang, hdr, want in (("en", {"accept-language": "en-GB"}, "en"), ("sv", {"accept-language": "sv-SE"}, "sv"), ("x-earmind-lang en", {"accept-language": "sv-SE", "x-earmind-lang": "en"}, "en")):
    st, _, raw = req("POST", "drill", {"action": "nope"}, "not-a-token", hdr)
    m = ((json.loads(raw or b"{}").get("error") or {}).get("message")) or ""
    is_sv = bool(re.search(r"[åäö]|\b(du|igen|logga)\b", m, re.I))
    ok(f"error message {lang}", (want == "sv") == is_sv and m, {"status": st, "message": m})

# (3b) answer in English
tok = T.signup()[0]
text, done = "", {}
r = urllib.request.Request(T.URL + "/functions/v1/answer", data=json.dumps({"fragment": "what is the capital of france", "mode": "text", "lang": "en", "context": {"recent_qa": []}}).encode(),
                           method="POST", headers=T.headers(tok, True, {"accept-language": "en-US"}))
with urllib.request.urlopen(r, timeout=90) as x:
    ev = None
    for line in x:
        line = line.decode().rstrip("\n")
        if line.startswith("event: "):
            ev = line[7:]
        elif line.startswith("data: "):
            d = json.loads(line[6:])
            if ev == "delta":
                text += d.get("text", "")
            elif ev == "done":
                done = d
ok("answer lang=en is English", "Paris" in text and english(text + " the is"), {"answer": text[:200]})

# (3d) K115 (D253): numbers in the spoken answer follow the chosen language (Claude only, no audio)
def say(q, lang):
    t = T.signup()[0]
    out = ""
    r = urllib.request.Request(T.URL + "/functions/v1/answer", data=json.dumps({"fragment": q, "mode": "text", "lang": lang, "language": lang, "context": {"recent_qa": []}}).encode(),
                               method="POST", headers=T.headers(t, True))
    with urllib.request.urlopen(r, timeout=90) as x:
        ev = None
        for line in x:
            line = line.decode().rstrip("\n")
            if line.startswith("event: "):
                ev = line[7:]
            elif line.startswith("data: ") and ev == "delta":
                out += json.loads(line[6:]).get("text", "")
    return out


en_num = say("how many members does the united states senate have", "en")
ok("K115 English answer keeps digits (no Swedish number words)", re.search(r"\b100\b|one hundred", en_num) and not re.search(r"hundra|ett komma", en_num), {"answer": en_num[:200]})
sv_num = say("hur många ledamöter har riksdagen", "sv")
ok("K115 Swedish answer: the nine apart", "fyrtio nio" in sv_num and "fyrtionio" not in sv_num, {"answer": sv_num[:200]})

# (3c) exam from an English text: English questions
EN_TEXT = ("The Water Cycle\n\nWater moves between the oceans, the air and the land in a cycle. The sun heats the oceans and "
           "water evaporates into the air as water vapour. As the vapour rises it cools and condenses into tiny droplets that "
           "form clouds. When the droplets join and become heavy they fall as precipitation: rain, snow or hail. Some of the "
           "water runs off into rivers and back to the sea, and some soaks into the ground and becomes groundwater. Plants "
           "also release water vapour through their leaves, which is called transpiration.")
tok = T.signup()[0]
st, _, raw = req("POST", "exam", {"action": "drill", "answers": False, "questions": 3, "subject": "", "pages": [], "text": EN_TEXT}, tok, {"accept-language": "en-US"})
plan = json.loads(raw or b"{}")
qs = [i.get("question", "") for i in plan.get("items", [])]
ok("exam from English text has English questions", st == 200 and qs and all(english(q + " the") for q in qs), {"status": st, "questions": qs, "error": plan.get("error")})

passed = sum(results.values())
print(f"=== K114 web: {passed} av {len(results)}")
_s.exit(0 if passed == len(results) else 1)
