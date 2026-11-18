"""O83 (integritetslöften, Ke78) + omtest O81 (K99 rättelser) + K91 (testspärren för alla testkonton), Oscar (moln) 2026-11-18.
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o83_live.py
Bara testkonton (x-earmind-test), 0 ElevenLabs. Claude: två små exam drill på ett foto (cirka 0,02 USD) och Haikus röstval.
O83: ett foto laddas upp (upload_urls + PUT), används i exam drill och ska sedan vara borta: samma path igen ska inte gå att läsa.
Ett foto som aldrig används ska purge-jobbet ta bort inom cirka 75 min (SQL för Deangelo skrivs ut). Ett foto i ett anrop
som nekas (annat kontos path) ska också tas bort direkt.
K91 sist: ett fejkat kvotfel håller tillbaka all testtrafik i 10 min, så det körs sist."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
_s.path.insert(0, str(_p.Path(__file__).resolve().parent / "repetition_bank"))
import qa_testaccount as T  # noqa: E402
T.install()
import datetime as dt, json, random, tempfile, time, urllib.request  # noqa: E402
from make_files import photo  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
OK = []
RNG = random.Random(time.time())


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:1500], flush=True)


def req(method, fn, body=None, tok=None, mode=None):
    extra = {"x-earmind-test": f"oscar-qa {mode}"} if mode else None
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=json.dumps(body).encode() if body is not None else None, method=method, headers=T.headers(tok, True, extra))
    try:
        with urllib.request.urlopen(r, timeout=240) as x:
            return x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read() or b"{}"
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw[:200].decode(errors="replace")}


def err(j):
    e = j.get("error") or {}
    return {k: v for k, v in {"code": e.get("code"), "message": e.get("message")}.items() if v}


def put(url, data, ctype):
    r = urllib.request.Request(url, data=data, method="PUT", headers={"content-type": ctype, "x-upsert": "false"})
    try:
        with urllib.request.urlopen(r, timeout=60) as x:
            return x.status
    except urllib.error.HTTPError as e:
        return e.code


def jpg(seed):
    with tempfile.TemporaryDirectory() as d:
        photo("Fotosyntesen\nVäxter tar energi från solljuset och bygger socker av koldioxid och vatten. Det sker i bladens kloroplaster, "
              "där klorofyllet fångar ljuset. Syre släpps ut som en restprodukt. Djur och människor behöver syret för att andas.", f"{d}/p.jpg", seed=seed)
        return open(f"{d}/p.jpg", "rb").read()


# ---------------- O83: foton ----------------
t0 = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")
U = T.signup(True)[0]
s1, up = req("POST", "exam", {"action": "upload_urls", "count": 3, "type": "jpg"}, U)
ups = up.get("uploads") or []
put_st = [put(u["url"], jpg(f"o83-{i}"), u["content_type"]) for i, u in enumerate(ups)]
pa, pb, pc = (ups[0]["path"], ups[1]["path"], ups[2]["path"]) if len(ups) == 3 else (None, None, None)
s2, d1 = req("POST", "exam", {"action": "drill", "page_paths": [pa], "text": "", "answers": False, "questions": 4, "subject": "Biologi"}, U)
s3, d2 = req("POST", "exam", {"action": "drill", "page_paths": [pa], "text": "", "answers": False, "questions": 4, "subject": "Biologi"}, U)
other = "00000000-0000-0000-0000-000000000000/" + pc.split("/", 1)[1] if pc else "x"
s4, d3 = req("POST", "exam", {"action": "drill", "page_paths": [pc, other], "text": "", "answers": False, "questions": 4, "subject": "Biologi"}, U)
s5, d4 = req("POST", "exam", {"action": "drill", "page_paths": [pc], "text": "", "answers": False, "questions": 4, "subject": "Biologi"}, U)
check("O83 1: ett foto används en gång och är sedan borta (samma path igen går inte); ett foto i ett nekat anrop tas bort direkt",
      s1 == 200 and put_st == [200, 200, 200] and s2 == 200 and len(d1.get("items") or []) > 0 and s3 != 200 and s4 == 403 and s5 != 200,
      {"upload_urls": [s1, len(ups), up.get("expires_in")], "PUT": put_st, "drill 1": [s2, len(d1.get("items") or []), (d1.get("summary") or {}).get("covers")],
       "samma foto igen": [s3, err(d3) if False else err(d2)], "foto + annat kontos path": [s4, err(d3)], "fotot från det nekade anropet igen": [s5, err(d4)],
       "path som aldrig används (purge)": pb, "tid": t0})
print(f"     SQL för Deangelo (kör tidigast 75 min efter {t0}; väntat 0 rader för alla tre):")
print(f"     select name, created_at from storage.objects where bucket_id = 'drill_material' and name in ('{pa}', '{pb}', '{pc}');", flush=True)
print("     select count(*) as filer, min(created_at) as aldsta from storage.objects where bucket_id = 'drill_material' and created_at < now() - interval '90 minutes';", flush=True)


# ---------------- omtest O81 ----------------
def word():
    return "".join(RNG.choice("bdfghjklmnprstv") + RNG.choice("aeiouy") for _ in range(3))


def sentence(n):
    out = word().capitalize()
    while len(out) < n:
        out += " " + word()
    return out[: n - 1].rstrip() + "."


A = T.signup(True)[0]
cat = req("GET", "voices", None, A)[1].get("catalog") or []
names = {c["voice_id"]: c.get("name") for c in cat}
parts = [sentence(90), sentence(80), sentence(70), sentence(60)]
body = {"action": "save", "defer_audio": True, "drill": {"kind": "text", "title": "O83/O81 blanda (QA)", "subject": "Historia", "mix_voices": True}, "items": [{"kind": "para", "text": t} for t in parts]}
s6, j6 = req("POST", "drill", body, A)
s7, j7 = req("POST", "drill", {**body, "drill": {**body["drill"], "title": "O83/O81 blanda 2 (QA)"}}, A)
v6 = [i.get("voice_id") for i in j6.get("items") or []]
v7 = [i.get("voice_id") for i in j7.get("items") or []]
s8, j8 = req("POST", "drill", {"action": "cost", "drill": {"kind": "text", "title": "x", "subject": "Historia", "style": "med kinesisk brytning"}, "items": [{"kind": "para", "text": sentence(80)}]}, A)
check("O81 omtest: samma text i ett nytt prov får samma röster och kostar 0; voice_reason säger när ingen röst passar",
      v6 and v6 == v7 and (j7.get("audio") or {}).get("cost") == 0 and "finns" in (j8.get("voice_reason") or ""),
      {"prov 1": [s6, [names.get(x, x) for x in v6], (j6.get("audio") or {}).get("cost")], "prov 2 samma text": [s7, [names.get(x, x) for x in v7], (j7.get("audio") or {}).get("cost")],
       "kinesisk brytning": [s8, names.get(j8.get("voice_id"), j8.get("voice_id")), j8.get("voice_reason")]})

for tok in (A, U):
    for d in req("POST", "drill", {"action": "list"}, tok)[1].get("drills") or []:
        req("POST", "drill", {"action": "delete", "id": d["id"]}, tok)

# ---------------- K91 sist: fejkat kvotfel håller tillbaka alla testkonton ----------------
E = T.signup(True)[0]
s9, j9 = req("POST", "drill", {"action": "save", "drill": {"kind": "text", "title": "K91 fejk (QA)", "subject": "Historia"}, "items": [{"kind": "para", "text": sentence(200)}]}, E, "unavailable")
did = (j9.get("drill") or {}).get("id")
for _ in range(15):
    a = (req("POST", "drill", {"action": "status", "id": did}, E, "unavailable")[1].get("audio") or {})
    if a.get("total") and a.get("done", 0) + a.get("failed", 0) >= a["total"]:
        break
    time.sleep(2)
req("POST", "drill", {"action": "delete", "id": did}, E)  # K91: borttaget prov ska inte släppa spärren
held = {}
for name in ("A", "B"):
    tok = T.signup(True)[0]
    q0 = req("POST", "drill", {"action": "quota"}, tok)[1].get("used")
    st, j = req("POST", "drill", {"action": "save", "drill": {"kind": "text", "title": f"K91 {name} (QA)", "subject": "Historia"}, "items": [{"kind": "para", "text": sentence(150)}]}, tok)
    q1 = req("POST", "drill", {"action": "quota"}, tok)[1].get("used")
    held[name] = {"status": st, "audio_unavailable": j.get("audio_unavailable"), "cost": j.get("cost"), "used före/efter": [q0, q1]}
    for d in req("POST", "drill", {"action": "list"}, tok)[1].get("drills") or []:
        req("POST", "drill", {"action": "delete", "id": d["id"]}, tok)
    time.sleep(20)
check("K91 omtest: efter ett fejkat kvotfel (och borttaget prov) hålls både A och B tillbaka utan dragning",
      all(h["audio_unavailable"] is True and h["used före/efter"][0] == h["used före/efter"][1] for h in held.values()),
      {"fejk": [s9, (j9.get("audio") or {}).get("cost")], "A och B": held})
print(f"\n=== O83 live {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
