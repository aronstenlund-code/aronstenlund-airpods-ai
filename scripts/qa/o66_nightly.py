"""O66: nattligt regressionstest av servern efter K61–K69. Skrivet av Oscar (QA) 2026-11-15. Kör varje kväll:
  python -I -X utf8 scripts/qa/o66_nightly.py            -> allt (cirka 0,25 USD Claude, 0 ElevenLabs)
  python -I -X utf8 scripts/qa/o66_nightly.py --fast     -> utan Claude-delarna (help, try, exam, answer)
Bara testkonton (qa_testaccount.install(): testhuvud på varje anrop, direkta ElevenLabs-anrop vägras). Inget anrop
utan testmarkering (därför körs INTE o61_testmode.py här: dess sista steg är ett riktigt tts-anrop).

Delar (varje kontroll blir ok / FEL / känd):
  A  o58_help.py        /help: 30 hur-gör-jag, 10 utanför appen, 4 knepiga (Claude Haiku, cirka 0,03 USD)
  B  o58_import.py      import_text: 36 ChatGPT-varianter (ingen Claude)
  C  o55_drill_server.py spara, dela, importera, ändra, ta bort, RLS
  D  o56_publish.py     publicera, hitta via skolan, hämta, rapportera, avpublicera, ta bort
  E  testlägen          tts/stt-token falska; "slow" (filer väntar), "unavailable" (filer failed, tts 503)
  F  K64                ta bort ett prov med väntande filer -> filerna "unused" (kontrolleras med SQL, se nedan)
  G  D175 kvoten        13 av 15 använda -> exam ger högst 2, spara över kvoten -> 402 med rätt text
  H  D176 längdklass    normal / longer / too_long efter voice_chars och gränserna 800 / 1600
  I  D177 try           /help try räknar 3, spara samma frågor -> generated_questions 0, already_counted, kvoten oförändrad
  J  K65 förhandsvisning publish och search har preview (4 första) och first_audio_url
  K  K66/K67            formler och engelska prov: genererat (appens väg) och fasta fall; screen sparas
  L  K68                /answer auto: frågeord + "?" besvaras, utan "?" och påståenden tysta
Uppläsningstexten (K67) och K64 ligger i databasen, som skriptet inte når: det skriver SQL-frågor i resultatet som
den som kör (Oscar via Supabase MCP) kör efteråt och klistrar in i rapporten.
Resultat: reports/qa/data/<tid>-o66-nightly.json och en sammanfattning på skärmen."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import datetime as dt, glob, json, os, pathlib, re, subprocess, sys, time, urllib.error, urllib.request  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
DATA = ROOT / "reports/qa/data"
FAST = "--fast" in sys.argv
CAP_USD = 0.5
START = dt.datetime.now(dt.timezone.utc)
CHECKS, COST = [], {"claude": 0.0}
# Kvällens egna ord i texterna: en fråga som redan har ljud räknas inte mot kvoten och väntar inte i "slow" (D144),
# så varje körning behöver nya texter. Vanliga ord, inga siffror (siffror blir längre text i uppläsningen).
import random  # noqa: E402
_W = "äpple björk citron dalgång ekorre fjäll gran hassel igelkott jordgubbe kastanj lärk mossa nypon olvon pil rönn sälg tall ugglor vass".split()
_R = random.Random(START.timestamp())
NONCE = " ".join(_R.sample(_W, 3))

# Kända avvikelser som beror på testläget eller är avsiktliga (O61, O62). De räknas inte som fel men listas.
KNOWN = {
    "R5c dela före klart ljud ger 409": "falskt ljud blir klart direkt (O62); testas i E med slow",
    "R5b ändrad fråga ger bara den frågans fil": "testkonton får new_chars 0 (O62)",
    "R5c mottagarens ändring kostar bara den frågan": "testkonton får new_chars 0 (O62)",
    "R12 nekas utan subject": "ämnet tas från provet, avsiktligt (O56)",
    "R12 nekas med tom subject": "ämnet tas från provet, avsiktligt (O56)",
    "R12 nekas när ljudet inte är klart": "falskt ljud blir klart direkt (O62); testas i E med slow",
    "ogiltig rapportorsak nekas": "okänd orsak blir 'annat', avsiktligt (O56)",
}


def check(area, name, ok, detail=""):
    known = (not ok) and name in KNOWN
    CHECKS.append({"area": area, "check": name, "ok": bool(ok), "known": known, "detail": str(detail)[:400]})
    print(f"{'ok   ' if ok else 'känd ' if known else 'FEL  '}{area} {name}" + (f" | {str(detail)[:160]}" if detail else ""), flush=True)


def spend(j):
    u = (j or {}).get("usage") or {}
    COST["claude"] += float(u.get("est_cost_usd") or (u.get("plan") or {}).get("est_cost_usd") or 0)


def over_cap():
    if COST["claude"] > CAP_USD:
        print(f"Kostnadstaket {CAP_USD} USD nått ({COST['claude']:.3f}), hoppar över resten av Claude-delarna", flush=True)
        return True
    return False


def call(path, body, tok, mode=None, timeout=180):
    """POST med testhuvud; mode 'slow' eller 'unavailable' läggs i x-earmind-test. -> (status, json, headers)."""
    extra = {"x-earmind-test": f"oscar-qa {mode}"} if mode else None
    req = urllib.request.Request(T.URL + path, data=json.dumps(body).encode(), method="POST", headers=T.headers(tok, True, extra))
    for _ in range(4):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                raw, h, st = r.read(), {k.lower(): v for k, v in r.headers.items()}, r.status
        except urllib.error.HTTPError as e:
            raw, h, st = e.read(), {k.lower(): v for k, v in e.headers.items()}, e.code
        if st == 429:
            time.sleep(21)
            continue
        try:
            j = json.loads(raw or b"{}")
        except ValueError:
            j = {"_bytes": len(raw), "_content_type": h.get("content-type")}
        return st, j, h
    return st, {}, h


def drill(tok, body, mode=None):
    return call("/functions/v1/drill", body, tok, mode)


def signup():
    for _ in range(5):
        try:
            return T.signup(True)[0]
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            print("  registrering 429, väntar 60 s", flush=True)
            time.sleep(60)
    raise SystemExit("kan inte registrera testkonto")


def item(q, n_chars, tag="x"):
    """En fråga med ett långt svar på ungefär n_chars tecken (vanliga ord, inga siffror)."""
    q = q.rstrip("?") + f", {NONCE}?"  # ny text varje kväll, också frågans egen ljudfil
    s = f"Det här är ett testsvar om {tag}, {NONCE}."
    words = "Ljuset bryts när det går mellan två ämnen och då ändras riktningen lite grann . ".split()
    long_, i = s, 0
    while len(long_) < n_chars - len(q):
        long_ += " " + words[i % len(words)]
        i += 1
    return {"question": q, "short": s, "long": long_.replace(" .", ".")}


# ---------------------------------------------------------------- A–D: befintliga skript
def run_script(area, script, pattern):
    t0 = time.time()
    p = subprocess.run([sys.executable, "-I", "-X", "utf8", str(ROOT / "scripts/qa" / script)], capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=1800)
    files = sorted(f for f in glob.glob(str(DATA / pattern)) if os.path.getmtime(f) >= t0 - 1)
    if not files:
        check(area, f"{script} körde", False, f"exit {p.returncode}, ingen datafil; {p.stderr[-300:]}")
        return None
    return json.loads(pathlib.Path(files[-1]).read_text(encoding="utf-8")), pathlib.Path(files[-1]).name


def part_help():
    r = run_script("A", "o58_help.py", "*-o58-help.json")
    if not r:
        return
    d, name = r
    s = d["summary"]
    COST["claude"] += float(s.get("cost_usd") or 0)
    for k in ("how", "outside", "tricky"):
        a, b = map(int, s[k].split("/"))
        check("A", f"/help {k} {s[k]}", a == b, name)
    for k in ("trap_looks_like_steps", "forbidden_words", "over_length", "errors"):
        check("A", f"/help {k} = 0", s.get(k) == 0, s.get(k))
    old = sum(bool(re.search(r"\bEarmind\b", x.get("answer") or "")) for x in d["rows"])
    check("A", "/help stavar EarMind (K63)", old == 0, f"{old} svar med 'Earmind'")


def part_import():
    r = run_script("B", "o58_import.py", "*-o58-import.json")
    if not r:
        return
    d, name = r
    for row in d["rows"]:
        check("B", f"import {row['name']}", row["ok"], "" if row["ok"] else
              f"http {row.get('http')} antal {row.get('count')}/{row.get('expected')} saknas {row.get('missing')} smutsigt {row.get('dirty')} "
              f"ej hela {row.get('not_full')} kort fel {row.get('bad_short')} fick {[(i.get('question'), i.get('short')) for i in (row.get('response') or {}).get('items', [])[:2]]}")


def part_checks(area, script, pattern):
    r = run_script(area, script, pattern)
    if not r:
        return
    d, name = r
    for c in d["checks"]:
        check(area, c["check"], c["ok"], c.get("detail", ""))
    check(area, f"{script}: ElevenLabs-tecken 0", (d.get("elevenlabs_chars") or 0) == 0, d.get("elevenlabs_chars"))


# ---------------------------------------------------------------- E, F: testlägen och K64
def part_testmode():
    tok = signup()
    st, j, h = call("/functions/v1/tts", {"text": "Hej, det här är ett test.", "language": "sv"}, tok)
    check("E", "tts testkonto: falskt ljud", st == 200 and h.get("x-earmind-fake") == "1", f"{st} fake={h.get('x-earmind-fake')}")
    st, j, h = call("/functions/v1/tts", {"text": "Hej.", "language": "sv"}, tok, "unavailable")
    check("E", "tts unavailable: 503 tts_unavailable", st == 503, f"{st} {(j.get('error') or {}).get('code')}")
    req = urllib.request.Request(T.URL + "/functions/v1/stt-token", method="GET", headers=T.headers(tok))
    j = json.load(urllib.request.urlopen(req, timeout=60))
    check("E", "stt-token testkonto: fake, ingen ws_url", j.get("fake") is True and not j.get("ws_url"), {k: v for k, v in j.items() if k != "token"})
    two = [item("Varför bryts ljuset i vatten?", 300, "ljus"), item("Vad är en lins?", 300, "lins")]
    st, j, _ = drill(tok, {"action": "save", "drill": {"title": "O66 slow (QA)"}, "items": two}, "slow")
    did = (j.get("drill") or {}).get("id")
    a = j.get("audio") or {}
    check("E", "slow: filerna väntar efter spara", st == 200 and a.get("done", 0) == 0 and a.get("total") == 4, f"{st} {a}")
    st, j, _ = drill(tok, {"action": "share", "id": did}, "slow")
    check("E", "slow: dela före klart ljud ger 409", st == 409, f"{st} {(j.get('error') or {}).get('message')}")
    st, j, _ = drill(tok, {"action": "delete", "id": did}, "slow")
    check("F", "K64: ta bort provet med väntande filer", st == 200, st)
    st, j, _ = drill(tok, {"action": "save", "drill": {"title": "O66 unavailable (QA)"},
                           "items": [item("Hur fungerar en spegel?", 300, "spegel")]}, "unavailable")
    did = (j.get("drill") or {}).get("id")
    a = {}
    for _ in range(10):
        time.sleep(3)
        st2, j2, _ = drill(tok, {"action": "status", "id": did}, "unavailable")
        a = j2.get("audio") or {}
        if a.get("failed", 0) + a.get("done", 0) >= a.get("total", 1):
            break
    check("E", "unavailable: filerna failed", a.get("failed") == a.get("total") and a.get("total"), a)
    drill(tok, {"action": "delete", "id": did})


# ---------------------------------------------------------------- G, H, I: kvoten, längdklass, try
def part_quota_length():
    tok = signup()
    st, q0, _ = drill(tok, {"action": "quota"})
    check("G", "quota nytt konto: 15 kvar, suggest 15", q0.get("left") == 15 and q0.get("suggest") == 15, q0)
    rows = [item(f"Testfråga {w} om ljus?", 300, w) for w in _W[:10]]
    rows += [item("En normal fråga om linser?", 700, "normal"), item("En längre fråga om linser?", 1200, "längre"),
             item("En för lång fråga om linser?", 1900, "för lång")]
    st, j, _ = drill(tok, {"action": "save", "drill": {"title": "O66 D175 D176 (QA)"}, "items": rows})
    check("G", "spara 13 frågor", st == 200 and j.get("generated_questions") == 13, f"{st} generated {j.get('generated_questions')}")
    lim = {"normal": 800, "longer": 1600}
    bad = []
    for it in j.get("items", []):
        vc, lc = it.get("voice_chars"), it.get("length_class")
        want = "normal" if vc <= lim["normal"] else "longer" if vc <= lim["longer"] else "too_long"
        if lc != want:
            bad.append((it["question"][:30], vc, lc))
    classes = [i.get("length_class") for i in j.get("items", [])][-3:]
    check("H", "D176: klassen följer voice_chars (800/1600)", not bad and j.get("items"), bad or classes)
    check("H", "D176: normal, longer och too_long förekommer", classes == ["normal", "longer", "too_long"], classes)
    did = (j.get("drill") or {}).get("id")
    st, q1, _ = drill(tok, {"action": "quota"})
    check("G", "quota efter 13: 2 kvar", q1.get("left") == 2, q1)
    if not FAST and not over_cap():
        text = ("Fysik åk 8. Hastighet är sträcka delat med tid. Kraft mäts i newton. Tyngdkraften är massan gånger g. "
                "Friktion bromsar rörelse mellan två ytor. Tryck är kraft per area och mäts i pascal. Snöskor har stor yta. "
                "På månen är g mindre än på jorden, men massan är densamma.")
        st, e, _ = call("/functions/v1/exam", {"action": "drill", "text": text, "questions": 20, "answers": False}, tok)
        spend(e)
        check("G", "D175: exam med 2 kvar ger högst 2 frågor", st == 200 and len(e.get("items", [])) <= 2,
              f"{st} {len(e.get('items', []))} frågor, quota {e.get('quota')}")
    st, j, _ = drill(tok, {"action": "save", "drill": {"title": "O66 över kvoten (QA)"},
                           "items": [item(f"Ny fråga om speglar och {w}?", 200, w) for w in _W[10:13]]})
    msg = (j.get("error") or {}).get("message", "")
    check("G", "D175: spara över kvoten ger 402", st == 402, f"{st} {msg[:120]}")
    check("G", "402-texten nämner 'av 15' och inte 'Köp'", "av 15" in msg and "Köp" not in msg, msg[:160])
    drill(tok, {"action": "delete", "id": did})
    # I: D177
    if FAST or over_cap():
        return
    tok2 = signup()
    text = ("Fotosyntes är när växter gör socker av koldioxid och vatten med hjälp av solljus. Syre bildas som en restprodukt. "
            "Klorofyllet i bladen fångar ljuset. Växterna är producenter och grunden i näringskedjan.")
    st, t, _ = call("/functions/v1/help", {"action": "try", "text": text}, tok2)
    spend(t)
    its = t.get("items", [])
    check("I", "D177: try ger 3 frågor och räknar 3", st == 200 and len(its) == 3 and (t.get("quota") or {}).get("used") == 3,
          f"{st} {len(its)} frågor, quota {t.get('quota')}")
    if its:
        st, j, _ = drill(tok2, {"action": "save", "drill": {"title": "O66 D177 (QA)"},
                                "items": [{k: i[k] for k in ("question", "short", "long")} for i in its]})
        check("I", "D177: spara try-frågorna räknas inte igen", st == 200 and j.get("generated_questions") == 0 and j.get("already_counted") == len(its),
              f"{st} generated {j.get('generated_questions')} already_counted {j.get('already_counted')}")
        st, q, _ = drill(tok2, {"action": "quota"})
        check("I", "D177: kvoten fortfarande 3 använda", q.get("used") == 3, q)
        drill(tok2, {"action": "delete", "id": (j.get("drill") or {}).get("id")})


# ---------------------------------------------------------------- J: K65
def part_preview():
    tok, tok2 = signup(), signup()
    rows = [item(f"Förhandsvisningens fråga om magneter och {w}?", 300, w) for w in _W[13:19]]
    st, j, _ = drill(tok, {"action": "save", "drill": {"title": "O66 K65 (QA)", "subject": "Fysik", "grade": "åk 8"}, "items": rows})
    did = (j.get("drill") or {}).get("id")
    for _ in range(10):
        st2, j2, _ = drill(tok, {"action": "status", "id": did})
        a = j2.get("audio") or {}
        if a.get("done") == a.get("total"):
            break
        time.sleep(3)
    st, sc, _ = drill(tok, {"action": "schools", "q": "Katedral"})
    school = (sc.get("schools") or [{}])[0].get("code")
    date = (dt.date.today() + dt.timedelta(days=7)).isoformat()
    st, pub, _ = drill(tok, {"action": "publish", "id": did, "school_code": school, "subject": "Fysik", "exam_date": date})
    p = pub.get("publication") or {}
    pv = p.get("preview") or pub.get("preview") or []
    fa = p.get("first_audio_url") if "first_audio_url" in p else pub.get("first_audio_url")
    check("J", "K65: publish har preview med 4 frågor", st == 200 and len(pv) == 4 and all(x.get("question") and x.get("short") for x in pv),
          f"{st} {len(pv)} rader")
    check("J", "K65: publish har first_audio_url", bool(fa), str(fa)[:60])
    found = None
    for _ in range(20):
        st, s, _ = drill(tok2, {"action": "search", "school_code": school})
        found = next((r for r in s.get("results", []) if r.get("id") == p.get("id")), None)
        if found:
            break
        time.sleep(0.5)
    check("J", "hitta via skolan (search)", bool(found), school)
    if found:
        check("J", "K65: search har preview och first_audio_url", len(found.get("preview") or []) == 4 and found.get("first_audio_url"),
              f"{len(found.get('preview') or [])} rader, länk {bool(found.get('first_audio_url'))}")
        check("J", "K65: 'och N frågor till' = items - 4", found.get("items") == 6, found.get("items"))
    st, _, _ = drill(tok, {"action": "unpublish", "id": did})  # unpublish tar provets id (handler: owned(user, b.id))
    check("J", "avpublicera", st == 200, st)
    drill(tok, {"action": "delete", "id": did})


# ---------------------------------------------------------------- K: K66, K67
FIXED_SV = [
    ("Hur räknar man ut hastighet med formeln v = s / t?", "Man delar sträckan med tiden, v = s / t.", "Man delar sträckan med tiden, v = s / t. Arean är A = b · h / 2."),
    ("Vad är 3/4 i decimalform?", "3/4 är 0,75.", "3/4 är 0,75, och tryck är p = F/A."),
    ("Kan man svara ja/nej eller och/eller?", "Ja, och/eller fungerar.", "Ja, och/eller fungerar, och svaret är ja/nej."),
]
FIXED_EN = [
    ("What happened in 1850?", "Since about 1850 the temperature has risen by roughly 1.2 degrees.", "Since about 1850 the temperature has risen by roughly 1.2 degrees. About 25 % of the ice is gone."),
    ("What is the formula for speed?", "Speed is v = s / t.", "Speed is v = s / t, so 18 km in 1.5 hours is 12 km/h, and 3/4 of the trip is done."),
]
# vad rösten ska få (K67), och vad den inte får innehålla; kontrolleras med SQL efteråt
EXPECT_VOICE = [("v är lika med s delat med t", True), ("b gånger h delat med två", True), ("tre fjärdedelar", True),
                ("F delat med A", True), ("och/eller", True), ("ja delat med nej", False), ("artonhundrafemtio", False),
                ("v equals s divided by t", True), ("25 percent", True), ("km divided by h", False), ("3 divided by 4", False)]
MATERIAL_RE = re.compile(r"(?<![^\W\d_])(materialet|i texten|enligt texten|anteckningarna|the material|the notes|the text says|according to the text)(?![^\W\d_])", re.I)


def part_formulas():
    tok = signup()
    for subj, rows in (("Matematik", FIXED_SV), ("Engelska", FIXED_EN)):
        its = [{"question": q, "short": s, "long": l} for q, s, l in rows]
        st, j, _ = drill(tok, {"action": "save", "drill": {"title": f"O66 K67 {subj} (QA)", "subject": subj}, "items": its})
        check("K", f"K67 fasta fall {subj} sparas", st == 200, st)
        drill(tok, {"action": "delete", "id": (j.get("drill") or {}).get("id")})
    if FAST or over_cap():
        return
    import o55_grade as G  # noqa: PLC0415  (läser materialbanken; installerar samma D180-skydd)
    for eid, n in (("h4-fy-hastighet", 6), ("h3-en-climate", 4)):
        if over_cap():
            return
        t2 = signup()
        pages, text = G.drill_material(eid, t2)
        st, plan, _ = call("/functions/v1/exam", {"action": "drill", "pages": pages, "text": text, "answers": False, "questions": n}, t2)
        spend(plan)
        if st != 200:
            check("K", f"{eid}: exam drill", False, f"{st} {plan.get('error')}")
            continue
        st, ans, _ = call("/functions/v1/exam", {"action": "drill_answers", "items": plan["items"], "notes": plan["notes"],
                                                 "subject": plan["summary"]["subject"], "grade": plan["summary"]["grade"]}, t2)
        spend(ans)
        items = ans.get("items", [])
        eng = eid.startswith("h3-en")
        check("K", f"{eid}: ämne {plan['summary']['subject']}", plan["summary"]["subject"] == ("Engelska" if eng else "Fysik"), plan["summary"])
        meta = [i for i in items if MATERIAL_RE.search(f"{i.get('short', '')} {i.get('long', '')}")]
        check("K", f"{eid}: inga svar om 'materialet'/'the notes'", not meta, [i["question"][:50] for i in meta])
        if eng:
            sv = [i["question"] for i in items if re.search(r"\b(och|är|det|som|vad|varför|hur)\b", i["question"] + " " + i.get("long", ""), re.I)]
            check("K", "D182: engelskt prov på engelska", not sv and items, sv[:3])
        else:
            spoken_digits = [i["question"] for i in items if re.search(r"\d|[=/²·]", i["question"])]
            check("K", "K66: svenska frågor utan siffror/formeltecken i uppläsningen", not spoken_digits, spoken_digits[:3])
            sc = [i for i in items if i.get("screen")]
            check("K", "K66: visningstext finns för tal och formler", len(sc) >= 1, f"{len(sc)}/{len(items)}")
            slash = any("/" in json.dumps(i.get("screen"), ensure_ascii=False) for i in sc)
            check("K", "K67: visningstexten behåller '/'", slash, "")
        st, j, _ = drill(t2, {"action": "save", "drill": {"title": f"O66 {eid} (QA)", "subject": plan["summary"]["subject"]},
                              "items": [{k: i[k] for k in ("question", "short", "long") if k in i} | ({"screen": i["screen"]} if i.get("screen") else {})
                                        for i in items]})
        back = sum(bool(i.get("screen")) for i in j.get("items", []))
        sent = sum(bool(i.get("screen")) for i in items)
        check("K", f"{eid}: screen sparas och kommer tillbaka", st == 200 and back == sent, f"{back}/{sent}")
        drill(t2, {"action": "delete", "id": (j.get("drill") or {}).get("id")})


# ---------------------------------------------------------------- L: K68
K68 = [("Hur länge har hallar funnits?", True), ("Vad betyder inflation?", True), ("Why is the sky blue?", True),
       ("hur länge har han funnits", False), ("Jag tror det regnar i morgon.", False)]


def answer(tok, frag, lang):
    body = {"fragment": frag, "mode": "auto", "language": lang, "persona": "tutor", "context": {"recent_qa": []}}
    req = urllib.request.Request(T.URL + "/functions/v1/answer", data=json.dumps(body).encode(), method="POST", headers=T.headers(tok))
    out, ev, done = "", None, None
    with urllib.request.urlopen(req, timeout=90) as r:
        for line in r:
            line = line.decode("utf8", "replace").rstrip("\r\n")
            if line.startswith("event: "):
                ev = line[7:]
            elif line.startswith("data: "):
                try:
                    d = json.loads(line[6:])
                except ValueError:
                    continue
                if ev == "delta" and d.get("text"):
                    out += d["text"]
                if ev == "done":
                    done = d
    spend(done)
    return out, (done or {}).get("answered")


def part_k68():
    if FAST or over_cap():
        return
    tok = signup()
    for frag, want in K68:
        got = [answer(tok, frag, "en" if frag.startswith("Why") else "sv") for _ in range(2)]
        ok = all(bool(a) == want for _, a in got)
        check("L", f"K68 auto: {frag!r} {'besvaras' if want else 'tyst'}", ok, [(a, t[:50]) for t, a in got])


# ---------------------------------------------------------------- main
def main():
    parts = [("A", part_help, True), ("B", part_import, False), ("C", lambda: part_checks("C", "o55_drill_server.py", "*-o55-drill-server.json"), False),
             ("D", lambda: part_checks("D", "o56_publish.py", "*-o56-publish.json"), False), ("E", part_testmode, False),
             ("G", part_quota_length, False), ("J", part_preview, False), ("K", part_formulas, False), ("L", part_k68, True)]
    for area, fn, claude in parts:
        if claude and FAST:
            continue
        print(f"--- {area}", flush=True)
        try:
            fn()
        except Exception as e:  # noqa: BLE001  (en trasig del får inte stoppa resten)
            check(area, f"del {area} kraschade", False, f"{type(e).__name__}: {e}")
    end = dt.datetime.now(dt.timezone.utc)
    sql = {
        "elevenlabs": ("select voice_id, count(*), sum(coalesce(credits,0)) from drill_audio_files "
                       f"where created_at between '{START.isoformat()}' and '{end.isoformat()}' group by 1;"),
        "k64_unused": ("select status, left(error, 60), count(*) from drill_audio_files "
                       f"where created_at between '{START.isoformat()}' and '{end.isoformat()}' group by 1, 2;"),
        "k67_voice": ("select kind, text from drill_audio_files where text ~ '(delat med|divided by|fjärdedel|percent|och/eller|1850)' "
                      f"and created_at between '{START.isoformat()}' and '{end.isoformat()}';"),
        "expect_voice": EXPECT_VOICE,
        "logs": ("select count(*), countIf(positionCaseInsensitive(event_message, 'elevenlabs') > 0) from logs where source = 'function_logs' "
                 f"-- iso_timestamp_start {START.isoformat()} end {end.isoformat()}"),
    }
    n = len(CHECKS)
    fel = [c for c in CHECKS if not c["ok"] and not c["known"]]
    known = [c for c in CHECKS if c["known"]]
    summ = {"start": START.isoformat(timespec="seconds"), "end": end.isoformat(timespec="seconds"), "fast": FAST, "checks": n,
            "ok": n - len(fel) - len(known), "known": len(known), "fail": len(fel), "claude_usd": round(COST["claude"], 3),
            "by_area": {a: f"{sum(c['ok'] for c in CHECKS if c['area'] == a)}/{sum(c['area'] == a for c in CHECKS)}"
                        for a in sorted({c["area"] for c in CHECKS})}}
    out = DATA / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o66-nightly.json")
    out.write_text(json.dumps({"summary": summ, "checks": CHECKS, "sql": sql}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("\n=== Sammanfattning", json.dumps(summ, ensure_ascii=False))
    for c in fel:
        print(f"FEL  {c['area']} {c['check']} | {c['detail'][:200]}")
    print("SQL efteråt (Supabase MCP):")
    for k in ("elevenlabs", "k64_unused", "k67_voice"):
        print(f"  {k}: {sql[k]}")
    print("->", out)
    sys.exit(1 if fel else 0)


if __name__ == "__main__":
    main()
