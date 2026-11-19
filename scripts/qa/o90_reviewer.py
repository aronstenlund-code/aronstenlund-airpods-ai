"""O90 (D238): granskarens väg live med ett nytt anonymt testkonto, Oscar (moln) 2026-11-19.
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o90_reviewer.py
Bara testkonton (qa_testaccount: x-earmind-test + script-UA), tyst testljud, 0 ElevenLabs, inga köp.
Claude: ett prov från text (exam drill + drill_answers, cirka 0,05 USD) och Haiku för stil och röstval.

Steg som en granskare: nytt konto -> krediter -> välkomsten (App Attest, utan Team ID) -> Säg i AirPods (text, said, start,
spelas om = gratis) -> prov från text med 12 frågor -> Hur ska det låta? (stil) -> en röst ur katalogen (inte review)
-> Radera konto. Först förhandsvisas varje steg med serverns action "cost" (drar inget), sedan görs stegen på riktigt i
ordning, och kvoten läses efter varje steg. Alla svar söks igenom efter testläge, admin och interna namn."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
_s.path.insert(0, str(_p.Path(__file__).resolve().parent / "o79"))
import qa_testaccount as T  # noqa: E402
T.install()
import base64, json, re, time, urllib.error, urllib.request, uuid  # noqa: E402
from o79_materials import O79  # noqa: E402

sys = _s
sys.stdout.reconfigure(encoding="utf-8")
SEEN = []  # (steg, svar) for the word scan


def req(method, fn, body=None, tok=None, step="", timeout=240):
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=json.dumps(body).encode() if body is not None else None, method=method,
                               headers=T.headers(tok, True))
    for attempt in range(3):
        try:
            with urllib.request.urlopen(r, timeout=timeout) as x:
                st, j = x.status, json.loads(x.read() or b"{}")
        except urllib.error.HTTPError as e:
            raw = e.read() or b"{}"
            try:
                st, j = e.code, json.loads(raw)
            except ValueError:
                st, j = e.code, {"raw": raw[:300].decode(errors="replace")}
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            print("  nätfel:", e, flush=True)
            time.sleep(5)
            continue
        if st in (502, 503, 504) and fn in ("exam",) and attempt < 2:
            time.sleep(15)
            continue
        break
    SEEN.append((step or fn, j))
    return st, j


def quota(tok, step):
    s, q = req("POST", "drill", {"action": "quota"}, tok, step + " quota")
    return s, {k: q.get(k) for k in ("limit", "used", "remaining", "monthly_free", "purchased", "gift", "subscription", "unlimited", "resets")}


def err(j):
    e = j.get("error") or {}
    return {k: v for k, v in {"code": e.get("code"), "message": e.get("message")}.items() if v}


def nums(j):
    a = j.get("audio") or {}
    d = j.get("drill") or {}
    return {k: v for k, v in {"cost": j.get("cost"), "audio.cost": a.get("cost"), "new_chars": j.get("new_chars"), "enough": j.get("enough"),
                              "remaining": j.get("remaining"), "voice": d.get("voice_id") or j.get("voice_id"), "voice_reason": j.get("voice_reason"),
                              "style": d.get("style"), "audio_started": d.get("audio_started"), "error": err(j) or None}.items() if v is not None}


SAY = ("Kom ihåg att ta med gympakläder på tisdag och lämna in svenskuppsatsen senast fredag. "
       "Glosförhöret i engelska är på onsdag, kapitel fyra, och matteprovet flyttas till nästa vecka. "
       "Ring mormor på söndag och fråga om hon vill följa med på bio.")
STYLE_TEXT = ("Fotosyntesen sker i växternas gröna blad. Med hjälp av solljus gör växten socker av vatten och koldioxid, "
              "och syre släpps ut som en restprodukt. Sockret används som energi och som byggmaterial när växten växer.")
VOICE_TEXT = ("Andra världskriget började den första september nittonhundratrettionio när Tyskland anföll Polen. "
              "Kriget slutade i Europa i maj nittonhundrafyrtiofem och i Asien i september samma år.")


def text_drill(title, txt, **extra):
    return {"kind": "text", "title": title, "subject": "Svenska", "said": True, "client_id": str(uuid.uuid4()), **extra}


A = T.signup(True)[0]
print("=== 1. Nytt anonymt konto", flush=True)
s, q0 = quota(A, "1")
print("     kvot:", json.dumps([s, q0], ensure_ascii=False), flush=True)

print("=== 2. Välkomsten (App Attest; utan Team ID)", flush=True)
s1, ch = req("POST", "purchase", {"action": "attest_challenge"}, A, "2 attest_challenge")
fake = base64.b64encode(b"\xa3cfmtoapple-appattest" + bytes(40)).decode()
s2, w = req("POST", "purchase", {"action": "welcome", "key_id": base64.b64encode(bytes(32)).decode(), "challenge": ch.get("challenge"), "attestation": fake}, A, "2 welcome")
s, q1 = quota(A, "2")
print("     attest_challenge:", s1, "challenge" if ch.get("challenge") else err(ch), "| welcome:", s2, json.dumps(err(w) or w, ensure_ascii=False)[:300], flush=True)
print("     kvot efter:", json.dumps(q1, ensure_ascii=False), flush=True)

print("=== 3. Röstkatalogen", flush=True)
sv, v = req("GET", "voices", None, A, "3 voices")
cat = v.get("catalog") or []
pick = next((c for c in cat if not c.get("review")), None)
print("     ", sv, len(cat), "röster, review:", sum(bool(c.get("review")) for c in cat), "vald:", pick and {k: pick.get(k) for k in ("voice_id", "name", "gender", "age", "accent")}, flush=True)

print("=== 4. Exam: prov från text, 12 frågor (Claude)", flush=True)
m = O79["o79-bi-ekosystem"]
full = "\n\n".join(f"{h}\n\n{p}" for h, p in m["parts"])
se, plan = req("POST", "exam", {"action": "drill", "answers": False, "questions": 12, "subject": m["subject"], "pages": [], "text": full}, A, "4 exam drill")
qitems = []
if se == 200:
    sa, ans = req("POST", "exam", {"action": "drill_answers", "items": plan["items"], "notes": plan.get("notes"), "subject": plan["summary"]["subject"],
                                   "grade": plan["summary"]["grade"]}, A, "4 exam answers")
    qitems = ans.get("items") or plan["items"]
    print("     exam:", se, sa, len(qitems), "frågor, kvot i exam-svaret:", json.dumps(plan.get("quota"), ensure_ascii=False), flush=True)
else:
    print("     exam FEL:", se, err(plan), flush=True)
save_items = [{k: it[k] for k in ("question", "short", "long", "display") if it.get(k)} for it in qitems]
exam_chars = sum(len(i["question"]) + len(i.get("long") or "") for i in save_items)
s, q2 = quota(A, "4")
print("     frågor + långa svar (visade tecken, räknat här):", exam_chars, "| kvot efter exam:", json.dumps(q2, ensure_ascii=False), flush=True)

steps = [
    ("Säg i AirPods", {"drill": text_drill("Kom ihåg (QA)", SAY), "items": [{"kind": "para", "text": SAY}]}),
    ("Prov från text, 12 frågor", {"drill": {"title": "Ekosystem (QA)", "subject": "Biologi", "client_id": str(uuid.uuid4())}, "items": save_items}),
    ("Hur ska det låta?", {"drill": text_drill("Fotosyntes lugnt (QA)", STYLE_TEXT, style="Lugnt och tydligt, som en lärare"), "items": [{"kind": "para", "text": STYLE_TEXT}]}),
    ("Röst ur katalogen", {"drill": text_drill("Kriget (QA)", VOICE_TEXT, **({"voice_id": pick["voice_id"]} if pick else {})), "items": [{"kind": "para", "text": VOICE_TEXT}]}),
]

print("\n=== 5. Förhandsvisning (action cost, drar inget)", flush=True)
pre = {}
for name, b in steps:
    if not b["items"]:
        print("     ", name, "hoppas över (inga frågor)", flush=True)
        continue
    s, j = req("POST", "drill", {"action": "cost", **b}, A, f"5 cost {name}")
    pre[name] = j.get("cost")
    print(f"     {name}: {s} {json.dumps(nums(j), ensure_ascii=False)}", flush=True)
s, q3 = quota(A, "5")
print("     summa förhandsvisad:", sum(v or 0 for v in pre.values()), "| kvot (oförändrad?):", json.dumps(q3, ensure_ascii=False), flush=True)

print("\n=== 6. Stegen på riktigt (save + start), kvoten efter varje", flush=True)
rows = []
prev = q3
for name, b in steps:
    if not b["items"]:
        continue
    s, j = req("POST", "drill", {"action": "save", "defer_audio": True, **b}, A, f"6 save {name}")
    did = (j.get("drill") or {}).get("id")
    s2, j2 = req("POST", "drill", {"action": "start", "id": did}, A, f"6 start {name}") if did else (None, {})
    s3, j3 = req("POST", "drill", {"action": "start", "id": did}, A, f"6 start igen {name}") if did and s2 == 200 else (None, {})
    _, qn = quota(A, "6 " + name)
    used = (qn.get("used") or 0) - (prev.get("used") or 0)
    rows.append({"steg": name, "förhandsvisat": pre.get(name), "save": s, "start": s2, "start igen (spela om)": s3, "drogs": used,
                 "kvar": qn.get("remaining"), "save-svar": nums(j), "start-svar": nums(j2), "igen-svar": nums(j3)})
    print(f"     {name}: save {s} start {s2} igen {s3} | drogs {used}, kvar {qn.get('remaining')} | {json.dumps(nums(j), ensure_ascii=False)[:300]} | start {json.dumps(nums(j2), ensure_ascii=False)[:200]}", flush=True)
    prev = qn

print("\n=== 7. Radera konto", flush=True)
sd, jd = req("POST", "account/delete", {"confirm": True}, A, "7 delete")
sq, jq = req("POST", "drill", {"action": "quota"}, A, "7 quota efter")
print("     radera:", sd, json.dumps({k: jd.get(k) for k in ("deleted", "removed", "subscription", "notice")}, ensure_ascii=False)[:400], "| quota efteråt:", sq, err(jq), flush=True)

print("\n=== 8. Ord i svaren (testläge, admin, interna namn)", flush=True)
BAD = re.compile(r"test|admin|oscar|kevin|angela|deangelo|\bqa\b|debug|intern|supabase|elevenlabs|eleven_|haiku|sonnet|claude|anthropic|openai|"
                 r"\b[DKOA]\d{2,3}\b|lumen", re.I)
SKIP_KEYS = {"url", "preview_url", "challenge", "id", "client_id", "voice_id", "hash", "question_hash", "long_hash", "drill_id", "path", "audio_path"}
hits = []


def walk(step, o, path=""):
    if isinstance(o, dict):
        for k, v in o.items():
            if k in SKIP_KEYS or k.endswith("_url") or k.endswith("_id") or k.endswith("_hash"):
                continue
            walk(step, v, f"{path}.{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o):
            walk(step, v, f"{path}[{i}]")
    elif isinstance(o, str):
        for mm in BAD.finditer(o):
            hits.append({"steg": step, "fält": path, "ord": mm.group(0), "text": o[max(0, mm.start() - 60): mm.end() + 60]})
    # numbers/bools ignored


for step, j in SEEN:
    walk(step, j)
keys_seen = sorted({p.split("[")[0] for p in [h["fält"] for h in hits]})
print("     träffar:", len(hits), "fält:", keys_seen, flush=True)
for h in hits[:80]:
    print("     ", json.dumps(h, ensure_ascii=False)[:400], flush=True)
# also the raw keys (field names) the app gets, in case a name itself is internal
names = set()


def keys(o):
    if isinstance(o, dict):
        for k, v in o.items():
            names.add(k)
            keys(v)
    elif isinstance(o, list):
        for v in o:
            keys(v)


for _, j in SEEN:
    keys(j)
print("     fältnamn som innehåller test/admin/debug:", sorted(n for n in names if re.search(r"test|admin|debug|intern", n, re.I)), flush=True)

print("\n=== O90 sammanfattning", json.dumps({"kvot nytt konto": q0, "welcome": [s2, err(w)], "kvot efter welcome": q1, "katalog": [sv, len(cat)],
      "exam frågor": len(qitems), "exam visade tecken": exam_chars, "förhandsvisat": pre, "steg": [{k: r[k] for k in ("steg", "förhandsvisat", "save", "start", "start igen (spela om)", "drogs", "kvar")} for r in rows],
      "radera": [sd, jd.get("deleted")], "quota efter radering": [sq, err(jq)], "ordträffar": len(hits)}, ensure_ascii=False), flush=True)
