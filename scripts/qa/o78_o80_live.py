"""O78 + O80 live (Oscar moln, 2026-11-17). Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o78_o80_live.py
Bara testkonton (x-earmind-test, teströsten earmind-test-silent), 0 ElevenLabs, inga riktiga köp.
O78 (K94): falska JWS (Kevins testpki, scripts/qa/o78/fixtures.json) och skräp nekas live; utan inloggning 401; kontot får inget.
O80 (K95/K96): stil med v3-taggar (Haiku lägger in taggar; teströsten gör tyst ljud), återanvändning, cost, låsning,
/voices med katalog och preview_url. Biblioteket (?library=1) anropar ElevenLabs och provas därför inte (D180).
Taggarnas text syns bara i databasen: skriptet skriver ut drill-id och tid så att Deangelo kan läsa texten med SQL."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import datetime as dt, json, random, time, urllib.request  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
OK = []
RNG = random.Random(time.time())
FIX = json.loads((_p.Path(__file__).resolve().parent / "o78" / "fixtures.json").read_text())


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:1200], flush=True)


def req(method, fn, body=None, tok=None, auth=True):
    h = T.headers(tok, True) if auth else {"apikey": T.KEY, "content-type": "application/json"}
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=json.dumps(body).encode() if body is not None else None, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=180) as x:
            return x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read() or b"{}"
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw[:200].decode(errors="replace")}


def drill(body, tok):
    return req("POST", "drill", body, tok)


def quota(tok):
    q = drill({"action": "quota"}, tok)[1]
    return {k: q.get(k) for k in ("used", "remaining", "limit", "monthly_free", "purchased", "subscription", "unlimited") if k in q}


def err(j):
    e = j.get("error") or {}
    return {k: v for k, v in {"code": e.get("code"), "message": e.get("message"), "reason": j.get("reason")}.items() if v}


# ---------------- O78 ----------------
P = T.signup(True)[0]
q0 = quota(P)
res = {}
res["utan inloggning"] = req("POST", "purchase", {"action": "verify", "jws": FIX["fake_chain_jws"]}, auth=False)
res["falsk kedja (testrot)"] = req("POST", "purchase", {"action": "verify", "jws": FIX["fake_chain_jws"]}, P)
res["falsk kedja, fel signatur"] = req("POST", "purchase", {"action": "verify", "jws": FIX["fake_chain_bad_sig"]}, P)
res["skräp"] = req("POST", "purchase", {"action": "verify", "jws": "a.b.c"}, P)
res["ingen jws"] = req("POST", "purchase", {"action": "verify"}, P)
res["okänd action"] = req("POST", "purchase", {"action": "grant", "credits": 100000}, P)
res["falsk notifiering"] = req("POST", "purchase", {"signedPayload": FIX["fake_notification"]}, auth=False)
res["notifiering skräp"] = req("POST", "purchase", {"signedPayload": "x.y.z"}, auth=False)
q1 = quota(P)
shown = {k: [s, err(j) or j] for k, (s, j) in res.items()}
check("O78 live: falska och trasiga köp nekas, kontot får inget",
      res["utan inloggning"][0] == 401 and res["falsk kedja (testrot)"][0] == 422 and res["falsk kedja (testrot)"][1].get("reason") == "root"
      and res["falsk kedja, fel signatur"][0] == 422 and res["skräp"][0] == 422 and res["ingen jws"][0] == 400 and res["okänd action"][0] == 400
      and res["falsk notifiering"][0] == 422 and res["notifiering skräp"][0] == 422 and q1 == q0,
      {"svar": shown, "kvot före": q0, "kvot efter": q1})


# ---------------- O80 ----------------
def word():
    return "".join(RNG.choice("bdfghjklmnprstv") + RNG.choice("aeiouy") for _ in range(3))


def sentence(n):
    out = word().capitalize()
    while len(out) < n:
        out += " " + word()
    return out[: n - 1].rstrip() + "."


def text_body(action, parts, style=None, did=None, voice=None, title="O80"):
    d = {"kind": "text", "title": f"{title} (QA)", "subject": "Historia"}
    if style is not None:
        d["style"] = style
    if did:
        d["id"] = did
    if voice:
        d["voice_id"] = voice
    b = {"action": action, "drill": d, "items": [{"kind": "para", "text": t} for t in parts]}
    if action == "save":
        b["defer_audio"] = True
    return b


def wait(tok, did):
    a = {}
    for _ in range(40):
        a = drill({"action": "status", "id": did}, tok)[1].get("audio") or {}
        if a.get("total") and a.get("done", 0) + a.get("failed", 0) >= a["total"]:
            break
        time.sleep(3)
    return {k: a.get(k) for k in ("total", "done", "failed")}


def files(tok, did):
    j = drill({"action": "get", "id": did}, tok)[1]
    return {"voice_model": (j.get("drill") or {}).get("voice_model"), "style": (j.get("drill") or {}).get("style"),
            "audio": {k: v for k, v in (j.get("audio") or {}).items() if k in ("chars", "total", "done", "cost")},
            "files": [{"dur": ((i.get("audio") or {}).get("text") or {}).get("duration_ms"), "sentences": len(((i.get("audio") or {}).get("text") or {}).get("sentences") or [])} for i in j.get("items") or []]}


t0 = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
A = T.signup(True)[0]
parts = [sentence(160) + " " + sentence(120), sentence(150)]
n = sum(len(p) for p in parts)
STYLE = "Lugnt och tydligt, med pauser så att man hinner skriva"
s1, c1 = drill(text_body("cost", parts, STYLE), A)
s2, j2 = drill(text_body("save", parts, STYLE, title="O80-1 stil"), A)
d1 = (j2.get("drill") or {}).get("id")
s3, j3 = drill({"action": "start", "id": d1}, A)
w1 = wait(A, d1)
f1 = files(A, d1)
qa = quota(A)
check(f"O80 1: stil: cost {n} före = save = det som dras; eleven_v3; ljudet gjort med teströsten",
      c1.get("cost") == n and (j2.get("audio") or {}).get("cost") == n and j3.get("cost") == n and qa.get("used") == n and f1["voice_model"] == "eleven_v3" and w1.get("done") == w1.get("total"),
      {"cost": [s1, {k: c1.get(k) for k in ("cost", "enough")}], "save": [s2, {"cost": j2.get("cost"), "audio.cost": (j2.get("audio") or {}).get("cost"), "style": (j2.get("drill") or {}).get("style")}],
       "start": [s3, j3.get("cost")], "ljud": w1, "get": f1, "kvot": qa, "drill": d1, "tid": t0})

# samma text utan stil: egna filer (stilen i hashen), och jämförelse av längd: taggar gör rösttexten längre
s4, j4 = drill(text_body("save", parts, None, title="O80-2 utan stil"), A)
d2 = (j4.get("drill") or {}).get("id")
drill({"action": "start", "id": d2}, A)
w2 = wait(A, d2)
f2 = files(A, d2)
check("O80 2: samma text utan stil kostar igen (stilen ingår i hashen); multilingual_v2",
      (j4.get("audio") or {}).get("cost") == n and f2["voice_model"] != "eleven_v3",
      {"save": [s4, {"audio.cost": (j4.get("audio") or {}).get("cost")}], "ljud": w2, "get utan stil": f2, "get med stil": f1})
tag_hint = {"rösttextens tecken med stil": f1["audio"].get("chars"), "utan stil": f2["audio"].get("chars"),
            "längd per fil med/utan (ms)": [[a["dur"], b["dur"]] for a, b in zip(f1["files"], f2["files"])]}
print("     taggar? (längre rösttext med stil = taggar inlagda):", json.dumps(tag_hint, ensure_ascii=False), flush=True)

# återanvändning: samma text och stil (också med andra versaler och blanksteg) kostar 0, på ett annat konto också
B = T.signup(True)[0]
s5, c5 = drill(text_body("cost", parts, "  lugnt OCH tydligt, med pauser så att man hinner skriva "), B)
s6, j6 = drill(text_body("save", parts, STYLE, title="O80-3 B samma stil"), B)
s7, c7 = drill(text_body("cost", parts, "Glatt och snabbt"), B)
check("O80 3: samma text och stil kostar 0 (också på konto B och med andra versaler/blanksteg); en annan stil kostar igen",
      c5.get("cost") == 0 and (j6.get("audio") or {}).get("cost") == 0 and c7.get("cost") == n,
      {"cost versaler": [s5, c5.get("cost")], "B save": [s6, (j6.get("audio") or {}).get("cost")], "annan stil cost": [s7, c7.get("cost")]})

# låsning: ett prov utan stil (multilingual) kan inte få en stil; rösten låst; okänd röst nekas; för lång stil kapas
s8, j8 = drill(text_body("save", parts, STYLE, did=d2), A)
s9, j9 = drill(text_body("save", [sentence(60)], None, voice="abcdefghij0123456789", title="O80-4 okänd röst"), A)
s10, j10 = drill(text_body("save", [sentence(60)], "x" * 200, title="O80-5 lång stil"), A)
check("O80 4: stil på ett prov med annan modell 409; okänd röst nekas; stil över 80 tecken kapas",
      s8 == 409 and s9 in (400, 409) and len((j10.get("drill") or {}).get("style") or "") == 80,
      {"stil på d2": [s8, err(j8)], "okänd röst": [s9, err(j9)], "lång stil": [s10, len((j10.get("drill") or {}).get("style") or "")]})

# /voices
s11, v = req("GET", "voices", None, A)
cat = v.get("catalog")
check("O80 5: /voices svarar med catalog; varje röst har preview_url",
      s11 == 200 and isinstance(cat, list) and all(c.get("preview_url") for c in cat),
      {"status": s11, "nycklar": sorted(v.keys()), "katalog antal": len(cat or []), "första": (cat or [None])[0], "röster (gamla)": len(v.get("voices") or [])})
if cat:
    vid = cat[0]["voice_id"]
    s12, j12 = drill(text_body("save", [sentence(60)], None, voice=vid, title="O80-6 katalogröst"), A)
    d6 = (j12.get("drill") or {}).get("id")
    other = cat[1]["voice_id"] if len(cat) > 1 else "zzzzzzzzzz0123456789"
    s13, j13 = drill(text_body("save", [sentence(60)], None, did=d6, voice=other), A)
    check("O80 6: katalogröst sparas och låses (annan röst 409)", s12 == 200 and (j12.get("drill") or {}).get("voice_id") == vid and s13 == 409,
          {"save": [s12, (j12.get("drill") or {}).get("voice_id")], "byt röst": [s13, err(j13)]})
else:
    print("     O80 6 hoppas över: katalogen är tom (Kevin: fylls när Aron väljer röster)", flush=True)

print(f"\n     SQL för Deangelo (taggad rösttext, test-rösten, eleven_v3, efter {t0}):")
print(f"     select hash, model, status, left(text, 400) from drill_audio_files where voice_id = 'earmind-test-silent' and model = 'eleven_v3' and queued_at >= '{t0}' order by queued_at;", flush=True)
for tok in (A, B, P):
    for d in drill({"action": "list"}, tok)[1].get("drills") or []:
        drill({"action": "delete", "id": d["id"]}, tok)
print(f"\n=== O78/O80 live {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
