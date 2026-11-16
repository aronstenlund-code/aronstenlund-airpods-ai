"""O72: K78 och K79 (D200) live med testkonton och fejkat kvotfel (Oscar moln, 2026-11-16). Kör i Actions:
  python -I -X utf8 scripts/qa/o72_k78_live.py
0 riktiga ElevenLabs-anrop (D180): kvotfelet fejkas med `x-earmind-test: oscar-qa unavailable`, och del D sparar utan ljud.
  A  slut mitt i: spara med fejkat kvotfel -> filerna failed -> status ger tillbaka frågorna en gång (refunded_questions),
     kvoten tillbaka, audio_unavailable + notice, frågor och svar som text
  B  kvotfel nyss: nytt konto sparar och startar -> inget räknas (generated 0, new_chars 0), ostartat, notice, kvoten oförändrad
  C  get på det tillbakahållna provet: frågor och svar som text + notice
  D  testkontrollen via IP (K79): konto utan testhuvud och med appens user agent sparar utan ljud (defer_audio) från
     Actions -> servern ska känna igen GitHub-IP som test (loggen `test_request ... "reason":"ci"`, kontrolleras med SQL)."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import datetime as dt, json, time, urllib.request  # noqa: E402

sys = _s
sys.stdout.reconfigure(encoding="utf-8")
START = dt.datetime.now(dt.timezone.utc)
NOTICE = "Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt."
OK = []
STAMP = START.strftime("%H%M%S")


def check(name, ok, detail=""):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name + (f" | {str(detail)[:300]}" if detail else ""), flush=True)


def call(body, tok, mode=None, test=True):
    extra = {"x-earmind-test": f"oscar-qa {mode}"} if mode else None
    req = urllib.request.Request(T.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST",
                                 headers=T.headers(tok, test, extra))
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def items(tag):
    return [{"question": f"O72 {tag} fråga {i} {STAMP}?", "short": f"Svar {i} {tag}.", "long": f"Svar {i} {tag}. Mer text {STAMP}."} for i in range(1, 4)]


def text_ok(v, its):
    got = [(i.get("question"), i.get("long")) for i in v.get("items") or []]
    return got == [(i["question"], i["long"]) for i in its]


def quota(tok, mode=None):
    return call({"action": "quota"}, tok, mode)[1].get("used")


# A: slut mitt i
t1 = T.signup(True)[0]
q0 = quota(t1)
ia = items("A")
st, s = call({"action": "save", "drill": {"title": f"O72 A {STAMP} (QA)", "subject": "Biologi"}, "items": ia}, t1, "unavailable")
gen = s.get("generated_questions")
held_already = bool(s.get("audio_unavailable")) and gen == 0
check("A spara med fejkat kvotfel 200", st == 200, f"{st} generated {gen} audio_unavailable {s.get('audio_unavailable')}")
if held_already:
    print("  obs: ett fejkat kvotfel fanns redan inom 10 minuter, så A hölls tillbaka direkt (som B)", flush=True)
aid = (s.get("drill") or {}).get("id")
v, refunded = {}, 0
for _ in range(15):
    st, v = call({"action": "status", "id": aid}, t1, "unavailable")
    refunded += v.get("refunded_questions") or 0
    a = v.get("audio") or {}
    if a.get("total") and a.get("done", 0) + a.get("failed", 0) >= a.get("total"):
        break
    time.sleep(2)
st, v2 = call({"action": "status", "id": aid}, t1, "unavailable")
refunded2 = v2.get("refunded_questions") or 0
q1 = quota(t1)
if not held_already:
    check("A filerna failed (fejkat kvotfel)", (v.get("audio") or {}).get("failed", 0) > 0, v.get("audio"))
    check("A refunded_questions = generated, en gång", gen and refunded == gen and refunded2 == 0, f"generated {gen}, refunded {refunded}, sedan {refunded2}")
    check("A kvoten tillbaka", q1 == q0, f"före {q0}, efter {q1}")
check("A status: audio_unavailable + rätt notice", v2.get("audio_unavailable") is True and (v2.get("notice") or {}).get("message") == NOTICE
      and (v2.get("notice") or {}).get("code") == "audio_unavailable", v2.get("notice"))
check("A status: frågor och svar som text", text_ok(v2, ia), len(v2.get("items") or []))

# B: kvotfel nyss -> inget räknas (normalt testläge, inte unavailable)
t2 = T.signup(True)[0]
q0 = quota(t2)
ib = items("B")
st, s = call({"action": "save", "drill": {"title": f"O72 B {STAMP} (QA)", "subject": "Kemi"}, "items": ib}, t2)
bid = (s.get("drill") or {}).get("id")
check("B spara hålls tillbaka: generated 0, new_chars 0", st == 200 and s.get("generated_questions") == 0 and s.get("new_chars") == 0,
      f"{st} generated {s.get('generated_questions')} new_chars {s.get('new_chars')} chars_on_start {s.get('chars_on_start')}")
check("B spara: audio_unavailable + notice", s.get("audio_unavailable") is True and (s.get("notice") or {}).get("message") == NOTICE, s.get("notice"))
check("B spara: ostartat", (s.get("drill") or {}).get("audio_started") is False, (s.get("drill") or {}).get("audio_started"))
st, s = call({"action": "start", "id": bid}, t2)
check("B start hålls tillbaka: generated 0, notice", st == 200 and (s.get("generated_questions") or 0) == 0 and s.get("audio_unavailable") is True,
      f"{st} generated {s.get('generated_questions')} {s.get('notice')}")
check("B kvoten oförändrad", quota(t2) == q0, f"{q0} -> {quota(t2)}")
# C
st, g = call({"action": "get", "id": bid}, t2)
check("C get: frågor och svar som text", st == 200 and text_ok(g, ib), st)
check("C get: ostartat och inga ljudfiler gjorda", (g.get("drill") or {}).get("audio_started") is False, (g.get("drill") or {}).get("audio_started"))
for tok, d in ((t1, aid), (t2, bid)):
    call({"action": "delete", "id": d}, tok)

# D: testkontrollen via IP (inget testhuvud, appens user agent, inget ljud). qa_testaccount lägger testhuvudet på allt
# som går via urllib, så D går med http.client direkt (bara mot vår Supabase; inget ljud görs, defer_audio).
import http.client  # noqa: E402


def raw(method, path, body, tok=None):
    c = http.client.HTTPSConnection(T.URL.split("//", 1)[1], timeout=60)
    h = {"apikey": T.KEY, "content-type": "application/json", "user-agent": T.APP_UA}
    if tok:
        h["authorization"] = "Bearer " + tok
    c.request(method, path, json.dumps(body), h)
    r = c.getresponse()
    return r.status, json.loads(r.read() or b"{}")


st, j = raw("POST", "/auth/v1/signup", {})
t3, uid3 = j.get("access_token"), (j.get("user") or {}).get("id")
check("D konto utan testhuvud", st == 200 and t3, st)
st, s = raw("POST", "/functions/v1/drill", {"action": "save", "defer_audio": True, "drill": {"title": f"O72 D {STAMP} (QA)", "subject": "Fysik"},
            "items": [{"question": f"O72 D fråga {STAMP}?", "short": "Kort.", "long": "Kort. Inget ljud görs (defer_audio)."}]}, t3)
check("D spara utan testhuvud och utan ljud 200", st == 200 and (s.get("new_chars") or 0) == 0, f"{st} new_chars {s.get('new_chars')}")
did = (s.get("drill") or {}).get("id")
if did:
    raw("POST", "/functions/v1/drill", {"action": "delete", "id": did}, t3)
END = dt.datetime.now(dt.timezone.utc)
print(f"\n=== O72 {sum(OK)}/{len(OK)} ok, fönster {START.isoformat()} – {END.isoformat()}, stämpel {STAMP}")
print(f"D användare: {uid3} (loggen ska ha test_request med reason ci för den)")
sys.exit(0 if all(OK) else 1)
