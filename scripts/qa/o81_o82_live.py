"""O81 (K99 röster, Blanda, AI-val) + O82 (K98 välkomst/inbjudan) live, Oscar (moln) 2026-11-18.
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o81_o82_live.py
Bara testkonton (x-earmind-test, teströsten), 0 ElevenLabs (ljudet görs tyst, AI-valet är Haiku), inga riktiga köp.
App Attest kan inte göras utan en riktig iPhone: live provas bara nekanden och inbjudningskoderna."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import base64, collections, json, random, time, urllib.request  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
OK = []
RNG = random.Random(time.time())


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:1500], flush=True)


def req(method, fn, body=None, tok=None):
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=json.dumps(body).encode() if body is not None else None, method=method, headers=T.headers(tok, True))
    try:
        with urllib.request.urlopen(r, timeout=180) as x:
            return x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read() or b"{}"
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw[:200].decode(errors="replace")}


def err(j):
    e = j.get("error") or {}
    return {k: v for k, v in {"code": e.get("code"), "message": e.get("message"), "reason": j.get("reason")}.items() if v}


def word():
    return "".join(RNG.choice("bdfghjklmnprstv") + RNG.choice("aeiouy") for _ in range(3))


def sentence(n):
    out = word().capitalize()
    while len(out) < n:
        out += " " + word()
    return out[: n - 1].rstrip() + "."


# ---------------- O81: katalogen ----------------
A = T.signup(True)[0]
s, v = req("GET", "voices", None, A)
cat = v.get("catalog") or []
ids = {c["voice_id"] for c in cat}
field = lambda k: dict(collections.Counter(str(c.get(k)) for c in cat))  # noqa: E731
check("O81 1: /voices: katalogen för ett testkonto, utan review-röster, alla med preview_url, olika kön/ålder/brytning",
      s == 200 and len(cat) >= 10 and not any(c.get("review") for c in cat) and all(c.get("preview_url") for c in cat) and len(field("gender")) >= 2 and len(field("age")) >= 2 and len(field("accent")) >= 2,
      {"antal": len(cat), "kön": field("gender"), "ålder": field("age"), "brytning": field("accent"), "språk": field("language"),
       "namn": [c.get("name") for c in cat], "default_voice": v.get("default_voice"), "nycklar": sorted(v.keys())})

# Blanda röster: tre delar, samma vid omsparning, new_chars 0
parts = [sentence(90), sentence(80), sentence(70), sentence(60)]
body = {"action": "save", "defer_audio": True, "drill": {"kind": "text", "title": "O81 blanda (QA)", "subject": "Historia", "mix_voices": True},
        "items": [{"kind": "para", "text": t} for t in parts]}
sc, c = req("POST", "drill", {**body, "action": "cost"}, A)
s1, j1 = req("POST", "drill", body, A)
d1 = (j1.get("drill") or {}).get("id")
v1 = [i.get("voice_id") for i in j1.get("items") or []]
s2, j2 = req("POST", "drill", {**body, "drill": {**body["drill"], "id": d1}}, A)
v2 = [i.get("voice_id") for i in j2.get("items") or []]
s3, j3 = req("POST", "drill", {"action": "get", "id": d1}, A)
v3 = [i.get("voice_id") for i in j3.get("items") or []]
names = {c["voice_id"]: c.get("name") for c in cat}
check("O81 2: Blanda röster: varje del får en katalogröst, samma vid omsparning och get, new_chars 0, cost som utan blandning",
      s1 == 200 and len(v1) == 4 and all(x in ids for x in v1) and v1 == v2 == v3 and j2.get("new_chars") == 0 and c.get("cost") == sum(len(p) for p in parts),
      {"cost": [sc, c.get("cost"), "väntat", sum(len(p) for p in parts)], "röster": [names.get(x, x) for x in v1], "omsparning": [s2, [names.get(x, x) for x in v2], "new_chars", j2.get("new_chars")],
       "get": [names.get(x, x) for x in v3], "mix_voices": (j1.get("drill") or {}).get("mix_voices"), "olika röster": len(set(v1))})
# ett nytt prov med samma text: kostar 0 bara om samma röst lottas (fröet är drill.id); visa det
s4, j4 = req("POST", "drill", {**body, "drill": {**body["drill"], "title": "O81 blanda 2 (QA)"}}, A)
v4 = [i.get("voice_id") for i in j4.get("items") or []]
print("     nytt prov, samma text:", json.dumps({"röster": [names.get(x, x) for x in v4], "audio.cost": (j4.get("audio") or {}).get("cost"),
      "delar med samma röst som förra": sum(a == b for a, b in zip(v1, v4))}, ensure_ascii=False), flush=True)

# AI-valet: stil utan röst ger en katalogröst (inte review) och voice_reason, redan i cost
styles = ["Lugnt och tydligt", "Glatt och pigg, som en ung tjej", "Djup och allvarlig, som en dokumentär", "med kinesisk brytning"]
picks = {}
for st in styles:
    b = {"action": "cost", "drill": {"kind": "text", "title": "O81 AI (QA)", "subject": "Historia", "style": st}, "items": [{"kind": "para", "text": sentence(80)}]}
    s5, j5 = req("POST", "drill", b, A)
    picks[st] = [s5, names.get(j5.get("voice_id"), j5.get("voice_id")), j5.get("voice_id") in ids, j5.get("voice_reason")]
s6, j6 = req("POST", "drill", {"action": "save", "defer_audio": True, "drill": {"kind": "text", "title": "O81 AI save (QA)", "subject": "Historia", "style": styles[2]}, "items": [{"kind": "para", "text": sentence(80)}]}, A)
d6 = j6.get("drill") or {}
check("O81 3: AI-valet: stil utan röst ger en röst ur katalogen (inte review) och voice_reason, redan i cost; save sparar en katalogröst",
      all(p[0] == 200 and p[2] and p[3] for p in picks.values()) and d6.get("voice_id") in ids,
      {"cost per stil [status, röst, i katalogen, voice_reason]": picks, "save": [s6, names.get(d6.get("voice_id"), d6.get("voice_id")), j6.get("voice_reason")]})

# låsning av katalogröst (O80 fall 6)
if len(cat) >= 2:
    a, b2 = cat[0]["voice_id"], cat[1]["voice_id"]
    s7, j7 = req("POST", "drill", {"action": "save", "defer_audio": True, "drill": {"kind": "text", "title": "O81 röst (QA)", "subject": "Historia", "voice_id": a}, "items": [{"kind": "para", "text": sentence(60)}]}, A)
    d7 = (j7.get("drill") or {}).get("id")
    s8, j8 = req("POST", "drill", {"action": "save", "defer_audio": True, "drill": {"kind": "text", "id": d7, "voice_id": b2}, "items": [{"kind": "para", "text": sentence(60)}]}, A)
    check("O81 4 (O80 6): katalogröst sparas och låses, en annan röst ger 409", s7 == 200 and (j7.get("drill") or {}).get("voice_id") == a and s8 == 409,
          {"save": [s7, names.get((j7.get("drill") or {}).get("voice_id"))], "byt": [s8, err(j8)]})

# ---------------- O82 ----------------
P, Q = T.signup(True)[0], T.signup(True)[0]
s9, ch = req("POST", "purchase", {"action": "attest_challenge"}, P)
fake = base64.b64encode(b"\xa3cfmtoapple-appattest" + bytes(40)).decode()
s10, w = req("POST", "purchase", {"action": "welcome", "key_id": base64.b64encode(bytes(32)).decode(), "challenge": ch.get("challenge"), "attestation": fake}, P)
s11, w2 = req("POST", "purchase", {"action": "welcome", "key_id": base64.b64encode(bytes(32)).decode(), "challenge": "inte-en-utmaning", "attestation": fake}, P)
s12, c1 = req("POST", "purchase", {"action": "invite_code"}, P)
s13, c2 = req("POST", "purchase", {"action": "invite_code"}, P)
code = c1.get("code")
s14, own = req("POST", "purchase", {"action": "invite_claim", "code": code}, P)
s15, nodev = req("POST", "purchase", {"action": "invite_claim", "code": code}, Q)
s16, nf = req("POST", "purchase", {"action": "invite_claim", "code": "zzzzzzzz"}, Q)
s17, bad = req("POST", "purchase", {"action": "invite_claim", "code": "'; drop table x; --"}, Q)
qp = req("POST", "drill", {"action": "quota"}, P)[1]
check("O82 live: utmaning, falsk App Attest nekas (eller 503 utan Team ID), samma inbjudningskod, egna/okända/utan enhet nekas, inga krediter",
      s9 == 200 and ch.get("challenge") and s10 in (422, 503) and s11 in (400, 422, 503) and s12 == s13 == 200 and code and code == c2.get("code")
      and s14 == 409 and s15 == 409 and s16 == 404 and s17 in (400, 404) and not (qp.get("gift") or {}).get("left"),
      {"attest_challenge": [s9, (ch.get("challenge") or "")[:12] + "…"], "welcome falsk": [s10, err(w)], "welcome fel utmaning": [s11, err(w2)],
       "invite_code 1/2": [s12, {k: c1.get(k) for k in ("code", "url", "app_url", "month_rewarded", "month_max", "invite_credits")}, s13, c2.get("code")],
       "egen kod": [s14, err(own)], "utan enhet (Q)": [s15, err(nodev)], "okänd kod": [s16, err(nf)], "konstig kod": [s17, err(bad)],
       "P:s plånbok": {k: qp.get(k) for k in ("purchased", "gift", "monthly_free", "subscription")}})

for tok in (A, P, Q):
    for d in req("POST", "drill", {"action": "list"}, tok)[1].get("drills") or []:
        req("POST", "drill", {"action": "delete", "id": d["id"]}, tok)
print(f"\n=== O81/O82 live {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
