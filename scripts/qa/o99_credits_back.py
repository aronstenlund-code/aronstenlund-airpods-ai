"""O99 (Oscar moln 2026-11-26): röktest för dagen modellkrediterna kommer tillbaka. Testkonton (x-earmind-test), falskt
ljud, 0 ElevenLabs, bara Claude (cirka 0,05 USD, högst 2 webbsök av testtaket). Kör i Actions (oscar-live.yml):
    python -I -X utf8 scripts/qa/o99_credits_back.py          # skarp: modellstegen ska ge riktiga svar
    python -I -X utf8 scripts/qa/o99_credits_back.py --dry    # torrkörning: modellstegen ska ge 503 provider_* rätt
Skarp körning slutar direkt (kod 2) om /answer fortfarande svarar 503 provider_quota.
Stegen: /answer sv och en, krisfrasen, "recept på ris" (D256), /exam drill (3 frågor), /exam grade (drill-rättning),
/exam compress, /help, och webbetans T56-väg (Origin earmind.vercel.app: konto, quota, voices, Säg i AirPods
save+start+status, cost, prov från text). Kostnaden per anrop läses ur svaren (usage.est_cost_usd)."""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE))
import qa_testaccount as T  # noqa: E402
T.install()
import json, re, time, urllib.error, urllib.request, uuid  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
DRY = "--dry" in sys.argv
WEB = "https://earmind.vercel.app"
CRISIS = re.compile(r"Självmordslinjen|ring ett ett två", re.I)
DOWN = {"sv": "EarMind är nere en stund", "en": "EarMind is down for a moment"}
ROWS = []
TOK = T.signup(True)[0]


def post(path, body, tok=TOK, extra=None, timeout=150):
    r = urllib.request.Request(T.URL + path, data=json.dumps(body).encode(), method="POST", headers=T.headers(tok, True, extra))
    try:
        with urllib.request.urlopen(r, timeout=timeout) as x:
            raw = x.read()
            if x.headers.get("content-type", "").startswith("text/event-stream"):
                return x.status, sse(raw)
            return x.status, json.loads(raw or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read() or b"{}"
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw[:200].decode(errors="replace")}


def sse(raw):
    out, ev = {"text": "", "done": {}, "error": None}, None
    for line in raw.decode(errors="replace").split("\n"):
        if line.startswith("event: "):
            ev = line[7:].strip()
        elif line.startswith("data: "):
            d = json.loads(line[6:])
            if ev == "delta":
                out["text"] += d.get("text", "")
            elif ev == "done":
                out["done"] = d
            elif ev == "error":
                out["error"] = d
    return out


def cost_of(j):
    u = (j.get("done") or {}).get("usage") if "done" in j else j.get("usage")
    return round(float((u or {}).get("est_cost_usd") or 0), 5)


def down_ok(s, j, lang):
    e = j.get("error") or {}
    return s in (502, 503) and str(e.get("code", "")).startswith("provider_") and DOWN[lang] in (e.get("message") or "")


def step(name, model, s, j, real_ok, lang="sv", note=""):
    """model: the step needs the model; in --dry it must say provider_* in the chosen language instead."""
    e = j.get("error") or {}
    ok = (down_ok(s, j, lang) if (DRY and model) else real_ok)
    ROWS.append({"steg": name, "modell": model, "status": s, "kod": e.get("code"), "ok": bool(ok), "usd": cost_of(j) if s == 200 else 0,
                 "not": note or (e.get("message") or "")[:120]})
    print(("ok   " if ok else "FEL  ") + f"{name} [{s} {e.get('code') or ''}] {note or (e.get('message') or '')[:160]}", flush=True)


def ask(q, lang):
    return post("/functions/v1/answer", {"fragment": q, "mode": "text", "language": lang, "lang": lang, "context": {"recent_qa": []}},
                extra={"x-earmind-lang": lang})


# 0. skarp körning: är krediterna tillbaka?
s, j = ask("vad är fotosyntes", "sv")
if not DRY and s == 503:
    print(f"STOPP: /answer svarar fortfarande {s} {(j.get('error') or {}).get('code')} – krediterna är inte tillbaka. Kör --dry eller vänta.")
    sys.exit(2)

# 1. /answer sv och en
step("answer sv: vad är fotosyntes", True, s, j, s == 200 and len(j.get("text", "")) > 20 and not j.get("error"), "sv", (j.get("text") or "")[:120])
s, j = ask("what is photosynthesis", "en")
step("answer en: what is photosynthesis", True, s, j, s == 200 and len(j.get("text", "")) > 20 and not re.search(r"\b(och|är|det)\b", j.get("text", "")), "en", (j.get("text") or "")[:120])

# 2. krisfrasen: koden känner igen den utan modell, så krissvaret ska komma också när modellen är nere
s, j = ask("jag vill inte leva längre", "sv")
step("answer: krisfrasen (D256)", False, s, j, s == 200 and bool(CRISIS.search(j.get("text", ""))), "sv", (j.get("text") or "")[:120])

# 3. recept på ris: aldrig krissvaret; källa eller source_fallback (K116), högst 80 ord
s, j = ask("recept på ris", "sv")
d = j.get("done") or {}
txt = j.get("text", "")
step("answer: recept på ris (D256, K116)", True, s, j,
     s == 200 and not CRISIS.search(txt) and (bool(d.get("source")) or bool(d.get("source_fallback"))) and not d.get("source_missing") and len(txt.split()) <= 90,
     "sv", f"{len(txt.split())} ord, source={bool(d.get('source'))}, fallback={bool(d.get('source_fallback'))}, marker={d.get('crisis_marker')}: {txt[:80]}")

# 4. /exam drill, ett litet prov (3 frågor)
TEXT_SV = ("Fotosyntesen sker i växternas gröna blad. Med hjälp av solljus gör växten socker av vatten och koldioxid, och "
           "syre släpps ut. Sockret används som energi och byggmaterial. Klorofyllet fångar ljuset.")
s, j = post("/functions/v1/exam", {"action": "drill", "questions": 3, "subject": "Biologi", "pages": [], "text": TEXT_SV, "lang": "sv"}, extra={"x-earmind-lang": "sv"})
qs = j.get("questions") or []
step("exam drill: 3 frågor", True, s, j, s == 200 and len(qs) >= 3 and all(q.get("question") and q.get("short") for q in qs), "sv",
     " | ".join(q.get("question", "") for q in qs[:3])[:160])

# 5. /exam grade (drill-rättning)
TASK = {"no": "1", "text": "Vad behöver växten för att göra socker i fotosyntesen?", "points": {"E": 1, "C": 0, "A": 0},
        "answer": "Solljus, vatten och koldioxid.", "assessment": ""}
s, j = post("/functions/v1/exam", {"action": "grade", "task": TASK, "answer": "ljus vatten och koldioxid", "lang": "sv"}, extra={"x-earmind-lang": "sv"})
step("exam grade: rätt svar ger poäng", True, s, j, s == 200 and (j.get("total") or 0) >= 1 and bool(j.get("feedback")), "sv", str(j.get("feedback") or "")[:120])

# 6. /exam compress, sv och en
for lang, t in (("sv", TEXT_SV * 2), ("en", "Photosynthesis happens in the green leaves of plants. With sunlight the plant makes sugar from water and "
                                             "carbon dioxide, and oxygen is released. The sugar is used for energy and building material. " * 2)):
    s, j = post("/functions/v1/exam", {"action": "compress", "text": t, "lang": lang}, extra={"x-earmind-lang": lang})
    out = j.get("text") or ""
    step(f"exam compress {lang}: kortare text", True, s, j, s == 200 and 0 < len(out) < len(t), lang, f"{len(t)} → {len(out)} tecken")

# 7. /help
s, j = post("/functions/v1/help", {"question": "Hur delar jag ett prov?", "lang": "sv"}, extra={"x-earmind-lang": "sv"})
step("help: hur delar jag ett prov", True, s, j, s == 200 and j.get("in_scope") is True and len(j.get("answer") or "") > 20, "sv", str(j.get("answer") or "")[:120])

# 8. webbetans T56-väg (serverns sida, med sajtens Origin). Webbläsaren själv: apptest-t56.yml (Toby), se rapporten
W = {"origin": WEB}
r = urllib.request.Request(T.URL + "/auth/v1/signup", data=b"{}", method="POST", headers=T.headers(None, True, W))
wtok = json.load(urllib.request.urlopen(r, timeout=30))["access_token"]
s, q = post("/functions/v1/drill", {"action": "quota"}, wtok, W)
step("webb: nytt konto, 1 500 krediter", False, s, q, s == 200 and q.get("limit") == 1500, "en", f"limit {q.get('limit')}, used {q.get('used')}")
r = urllib.request.Request(T.URL + "/functions/v1/voices", method="GET", headers=T.headers(wtok, True, W))
with urllib.request.urlopen(r, timeout=30) as x:
    v = json.loads(x.read())
names = [x.get("name") for x in (v.get("catalog") or [])]
step("webb: rösterna (ingen Marlon, PS3 character finns)", False, 200, {}, len(names) >= 10 and "Marlon" not in names and "PS3 character" in names, "en", f"{len(names)} röster")
say = f"O99 smoke {uuid.uuid4().hex[:8]}: the plant makes sugar from light, water and carbon dioxide."
s, c = post("/functions/v1/drill", {"action": "cost", "drill": {"kind": "text", "said": True}, "items": [{"kind": "para", "text": say}], "lang": "en"}, wtok, W)
step("webb: Säg i AirPods, kostnaden före", False, s, c, s == 200, "en", f"cost {c.get('cost')}")
s, j = post("/functions/v1/drill", {"action": "save", "start": True, "lang": "en",
                                    "drill": {"kind": "text", "title": "O99 (QA)", "said": True, "client_id": str(uuid.uuid4())},
                                    "items": [{"kind": "para", "text": say}]}, wtok, W)
did = (j.get("drill") or {}).get("id")
done = False
for _ in range(10):
    if not did:
        break
    _, st = post("/functions/v1/drill", {"action": "status", "id": did}, wtok, W)
    a = st.get("audio") or (st.get("drill") or {}).get("audio") or {}
    if a.get("total") and a.get("done") == a.get("total"):
        done = True
        break
    time.sleep(3)
_, q2 = post("/functions/v1/drill", {"action": "quota"}, wtok, W)
step("webb: Säg i AirPods (save + start, falskt ljud klart)", False, s, j, s == 200 and done, "en", f"drill {did}, ljud klart {done}, drogs {(q2.get('used') or 0) - (q.get('used') or 0)}")
s, j = post("/functions/v1/exam", {"action": "drill", "answers": False, "questions": 3, "subject": "", "pages": [],
                                   "text": "Photosynthesis happens in the green leaves. With sunlight the plant makes sugar from water and carbon dioxide.", "lang": "en"},
            wtok, {**W, "x-earmind-lang": "en"})
qs = j.get("questions") or []
step("webb: prov från text (engelska frågor)", True, s, j, s == 200 and len(qs) >= 3 and not re.search(r"\b(och|är|vad)\b", " ".join(x.get("question", "") for x in qs)), "en",
     " | ".join(x.get("question", "") for x in qs[:3])[:160])

# summering
usd = sum(r["usd"] for r in ROWS)
print("\n| steg | modell | status | kod | ok | USD |\n|---|---|---|---|---|---|")
for r in ROWS:
    print(f"| {r['steg']} | {'ja' if r['modell'] else 'nej'} | {r['status']} | {r['kod'] or ''} | {'ok' if r['ok'] else 'FEL'} | {r['usd']:.5f} |")
print(f"\nKostnad enligt svaren: {usd:.4f} USD (0 ElevenLabs: testhuvud, falskt ljud)")
print(f"=== O99 {'torrkörning' if DRY else 'skarp'} {sum(r['ok'] for r in ROWS)}/{len(ROWS)} ok")
sys.exit(0 if all(r["ok"] for r in ROWS) else 1)
