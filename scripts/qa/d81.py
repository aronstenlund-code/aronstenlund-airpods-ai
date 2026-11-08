#!/usr/bin/env python3
"""Oscar QA: Kevin's D81-D84 live (speaker labels, CV + job ad, study cards, /study-profile, subject-led reading,
texts and quotes, exam grading, D82 silence on echo/noise, D83 level per grade).

  python -I scripts/qa/d81.py [section ...]     sections: social interview cards profile subject echo level texts exam

Budget 0.30 USD; costs are computed from tokens (high side) via demo.py. Anonymous sign-ins: one user per section
group (new-session cap: 20 answers in the first 10 minutes). Writes reports/qa/data/<stamp>-d81-d84.json.
"""
import base64, datetime as dt, importlib.util, io, json, pathlib, subprocess, sys, time

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("demo", ROOT / "scripts/qa/demo.py")
D = importlib.util.module_from_spec(spec)
spec.loader.exec_module(D)
log = []
extra_cost = 0.0


def rec(test, **kw):
    kw["at"] = dt.datetime.now().strftime("%H:%M:%S")
    log.append({"test": test, **kw})
    print(test, json.dumps(kw, ensure_ascii=False, default=str)[:900], flush=True)


def backend_state():
    try:
        subprocess.run(["git", "-C", str(ROOT), "fetch", "-q"], capture_output=True)
        r = subprocess.run(["git", "-C", str(ROOT), "log", "-1", "--format=%h %cd", "--date=format:%H:%M", "origin/main", "--", "backend/supabase/functions"],
                           capture_output=True, text=True).stdout.strip()
        return r
    except Exception as e:
        return repr(e)


def A(tok, body):
    r = D.ask(tok, body)
    u = ((r.get("done") or {}).get("usage") or {})
    return {"status": r["status"], "text": r.get("text", ""), "sugg": r.get("suggestions"), "preview": r.get("preview"),
            "answered": (r.get("done") or {}).get("answered"), "retract": (r.get("done") or {}).get("retract"),
            "status_str": (r.get("done") or {}).get("status"), "calib": (r.get("done") or {}).get("calibration"),
            "meta": r.get("meta"), "first_ms": r.get("first_ms"), "ms": r.get("ms"), "model": u.get("model"),
            "cost": round(r.get("cost", 0), 5), "err": r.get("err")}


def P(tok, path, body, wait=1.5):
    global extra_cost
    time.sleep(wait)
    o = D.call("POST", "/functions/v1/" + path, body, tok, timeout=120)
    j = D.jbody(o)
    u = (j or {}).get("usage") if isinstance(j, dict) else None
    if u:
        pi, po = D.PRICES.get(u.get("model"), D.PRICES["claude-haiku-5-5"])
        c = (u.get("input_tokens") or 0) * 1.25 * pi / 1e6 + (u.get("output_tokens") or 0) * po / 1e6
        c = max(c, u.get("est_cost_usd") or 0)
        extra_cost += c
    return o["status"], j, o["ms"], o["headers"].get("retry-after")


# ---------------------------------------------------------------- social
def social(tok):
    base = lambda **k: {"fragment": k.pop("fragment", ""), "mode": "tutor", "language": "sv", "persona": "social",
                        "social": dict({"style": "social", "trigger": "other_spoke"}, **k)}
    convo = [
        {"speaker": "Talare 1", "text": "Jag springer ett lopp på lördag, är lite nervös."},
        {"speaker": "Du", "text": "Det går säkert bra, du har tränat ju."},
        {"speaker": "Talare 2", "text": "Jag har konsertbiljetter på lördag kväll, hoppas jag hinner."},
        {"speaker": "Talare 3", "text": "Jag ska bara sova hela helgen."},
    ]
    cases = [
        ("S1 Talare 1 frågar (x3)", dict(transcript=convo, speaker="Talare 1", fragment="Ska du komma och heja på mig?"), 3),
        ("S2 Talare 2 frågar (x3)", dict(transcript=convo, speaker="Talare 2", fragment="Vad ska vi göra efter då?"), 3),
        ("S3 Talare 3 (x1)", dict(transcript=convo, speaker="Talare 3", fragment="Ni är så energiska, hur orkar ni?"), 1),
        ("S4 Du sa sist, ingen ny fråga (stall)", dict(transcript=convo, trigger="stall"), 1),
    ]
    for name, soc, n in cases:
        for i in range(n):
            b = base(**dict(soc))
            r = A(tok, b)
            rec(name, i=i, sugg=r["sugg"], status=r["status"], status_str=r["status_str"], first_ms=r["first_ms"], cost=r["cost"], err=r["err"])
    # without labels: unchanged behaviour ("other")
    old = [{"speaker": "other", "text": "Jag springer ett lopp på lördag."}, {"speaker": "user", "text": "Fett, hur långt?"}]
    r = A(tok, dict(base(transcript=old), fragment="Tio kilometer, ska du heja?"))
    rec("S5 utan etiketter (other/user)", sugg=r["sugg"], status=r["status"], cost=r["cost"])
    # flirt with labels + adult confirmed
    b = base(style="flirt", transcript=convo, speaker="Talare 2", fragment="")
    b["social"].pop("fragment", None)
    b["fragment"] = "Jag gillar att du frågar, vad gör du annars?"
    b["adult_confirmed"] = True
    r = A(tok, b)
    rec("S6 Rizz med etiketter", sugg=r["sugg"], status=r["status"], cost=r["cost"], err=r["err"])
    # flirt without confirmation, with labels: still 403
    b2 = dict(b)
    b2.pop("adult_confirmed")
    r = A(tok, b2)
    rec("S7 Rizz utan 18+", status=r["status"], err=r["err"])


# ---------------------------------------------------------------- interview
CV = ("Namn: Alex. Utbildning: Ekonomiprogrammet, Polhemsgymnasiet, Lund, 2021-2024. Arbete: Kafébiträde, Kafé Solen, Lund, "
      "2023-2024, kassa, servering, stängning. Sommarjobb: lagerarbete 2022 (plock och packning). Språk: svenska, engelska, arabiska. "
      "Övrigt: lagkapten i innebandy, volontär på ungdomsgård.")
AD = ("Jobbannons: Butiksmedarbetare, Systembolaget i Malmö. Du hjälper kunder, arbetar i kassa, plockar varor och har gott "
      "bemötande. Vi söker dig som är minst 20 år, ansvarsfull och serviceinriktad. Kvällar och helger.")


def interview(tok):
    iv = {"mode": "tutor", "language": "sv", "persona": "interview", "persona_setup": AD + " CV: " + CV, "context": {}, "turn": "question"}
    qs = ["berätta om dig själv", "vilka språk talar du", "har du jobbat i kassa förut", "har du körkort",
          "vad gjorde du på ICA", "hur gammal är du", "varför vill du jobba här", "vad har du för utbildning",
          "berätta om en gång du hanterat en arg kund", "har du jobbat med alkohol förut"]
    for q in qs:
        r = A(tok, dict(iv, fragment=q))
        rec("I " + q, text=r["text"], status=r["status"], cost=r["cost"], first_ms=r["first_ms"], err=r["err"])
    # interrupted answer, not repeated
    a = "Fotosyntes är processen där växter använder ljusenergi för att bygga socker av koldioxid och vatten"
    r = A(tok, {"fragment": "fortsätt", "mode": "tutor", "language": "sv",
                "context": {"recent_qa": [{"q": "förklara fotosyntesen", "a": a, "interrupted": True}]}})
    rec("I-int interrupted fortsätt", text=r["text"], status=r["status"], cost=r["cost"])


# ---------------------------------------------------------------- cards
SUMMARY = ("Fotosyntesen sker i kloroplasterna. Växten tar upp koldioxid genom klyvöppningarna och vatten genom rötterna. "
           "Med ljusenergi bildas druvsocker och syre. Cellandningen sker i mitokondrierna och är motsatsen: socker och syre blir energi, "
           "koldioxid och vatten.")


def cards(tok):
    for name, body in [("C1 åk7", {"summary": SUMMARY, "profile": "Årskurs: Åk 7. Förklaringar: korta.", "cards": 6}),
                       ("C2 utan profil, 3 kort", {"summary": SUMMARY, "cards": 3}),
                       ("C3 kort summary", {"summary": "Mitokondrien gör energi i cellen.", "cards": 4})]:
        st, j, ms, ra = P(tok, "study-cards", body)
        rec(name, status=st, ms=ms, n_cards=len((j or {}).get("cards", [])), n_test=len((j or {}).get("test", [])),
            cards=(j or {}).get("cards"), tests=(j or {}).get("test"), err=None if st == 200 else j, ra=ra)
    st, j, ms, ra = P(tok, "study-cards", {"summary": ""})
    rec("C4 tom summary", status=st, body=j)
    st, j, ms, ra = P(tok, "study-cards", {"summary": "x" * 7000})
    rec("C5 för lång summary", status=st, body=j)


# ---------------------------------------------------------------- profile
def profile(tok):
    cases = ["jag går i nian och har prov i biologi på fredag",
             "jag går tvåan på gymnasiet, kursen kemi 2, provet är på fredag",
             "jag pluggar på högskolan, anatomi, tentan är den femte december",
             "jag går i sjuan, historia, inget prov just nu",
             "jag går i åttan och har prov imorgon i matte",
             "bla bla vad blir det till middag"]
    for t in cases:
        st, j, ms, ra = P(tok, "study-profile", {"text": t})
        rec("P " + t, status=st, ms=ms, profile=(j or {}).get("profile"), n_terms=len((j or {}).get("terms", [])),
            terms=((j or {}).get("terms") or [])[:50], err=None if st == 200 else j)
    st, j, ms, ra = P(tok, "study-profile", {"text": "och kemi", "profile": {"grade": "y9", "course": "", "subject": "Biologi", "exam_date": None}})
    rec("P-upd uppdatera med befintlig profil", status=st, profile=(j or {}).get("profile"))


# ---------------------------------------------------------------- subject + echo + level
def prov(setup, extra=None):
    return dict({"mode": "tutor", "language": "sv", "persona": "tutor", "persona_setup": setup, "context": {}}, **(extra or {}))


BIO9 = "Prov i Biologi fredag 13 november (om 5 dagar). Årskurs: Åk 9. Kontrollfrågor: inga. Förklaringar: korta."
KEM9 = "Prov i Kemi fredag 13 november (om 5 dagar). Årskurs: Åk 9."


def subject(tok):
    terms = ["fotosyntes", "mitokondrie", "cellandning", "enzym", "ribosom", "kloroplast", "replikation", "meios"]
    for f in ["syntes", "fo syntes", "mito", "mitokondrien gör vad", "kloro plast", "enn simer", "dna replika tion", "meios"]:
        b = prov(BIO9)
        b["fragment"] = f
        b["context"] = {"prep_terms": terms}
        r = A(tok, b)
        rec("SU bio9 '%s'" % f, text=r["text"], answered=r["answered"], status=r["status"], cost=r["cost"])
    b = prov(KEM9)
    b["fragment"] = "syntes"
    b["context"] = {"prep_terms": ["atom", "molekyl", "jon", "syra", "bas", "kemisk reaktion"]}
    r = A(tok, b)
    rec("SU kem9 'syntes'", text=r["text"], answered=r["answered"], cost=r["cost"])


def echo(tok):
    # Provläge: first a real question, then echoes/noise
    p = prov(BIO9)
    p["fragment"] = "förklara fotosyntesen"
    r1 = A(tok, p)
    ans = r1["text"]
    rec("E0 fråga", text=ans, cost=r1["cost"])
    words = ans.split()
    tail = " ".join(words[-9:])
    mid = " ".join(words[3:12])
    rq = [{"q": "förklara fotosyntesen", "a": ans}]
    cases = [("E1 eko av svaret (slut)", tail), ("E2 eko mitt i", mid), ("E3 eko + brus", "hmm " + mid + " ö"), ("E4 bara brus", "bla hmm ö"),
             ("E5 reaktion", "okej kom igen"), ("E6 kontroll: ny fråga", "och vad är klorofyll"),
             ("E7 eko + ny fråga", tail + " och vad händer i mörker")]
    for name, frag in cases:
        b = prov(BIO9)
        b["fragment"] = frag
        b["context"] = {"recent_qa": rq}
        r = A(tok, b)
        rec(name + " [Provläge]", frag=frag, text=r["text"], answered=r["answered"], status_str=r["status_str"], retract=r["retract"], cost=r["cost"])
    for name, frag in [("E8 eko [Auto]", tail), ("E9 eko+brus [Auto]", "hmm " + mid), ("E10 brus [Auto]", "mm ja okej"), ("E11 ny fråga [Auto]", "vad är mitokondrier")]:
        b = {"fragment": frag, "mode": "auto", "language": "sv", "context": {"recent_qa": rq}}
        r = A(tok, b)
        rec(name, frag=frag, text=r["text"], answered=r["answered"], status_str=r["status_str"], retract=r["retract"], cost=r["cost"])


def level(tok):
    pairs = [("förklara fotosyntesen", "Prov i Biologi imorgon. Årskurs: Åk 7. Kontrollfrågor: inga.", "Prov i Biologi 2 imorgon. Årskurs: Gymnasiet 3, kurs Biologi 2. Kontrollfrågor: inga."),
             ("vad är en derivata", "Prov i Matte imorgon. Årskurs: Åk 8.", "Prov i Matte 4 imorgon. Årskurs: Gymnasiet 3, kurs Matte 4.")]
    for q, lo, hi in pairs:
        for tag, setup in (("åk", lo), ("gy3", hi)):
            b = prov(setup)
            b["fragment"] = q
            r = A(tok, b)
            rec("L %s [%s]" % (q, tag), text=r["text"], words=len(r["text"].split()), cost=r["cost"], first_ms=r["first_ms"])
    b = prov("Prov i Kemi imorgon. Årskurs: Åk 8. Kontrollfrågor: inga. Förklaringar: korta.")
    b["fragment"] = "förklara vad en atom är"
    r = A(tok, b)
    rec("L-inga/korta", text=r["text"], words=len(r["text"].split()), has_q="?" in r["text"], cost=r["cost"])
    b = prov("Prov i Kemi imorgon. Årskurs: Åk 8. Kontrollfrågor: ja–nej. Förklaringar: utförliga.")
    b["fragment"] = "förklara vad en atom är"
    r = A(tok, b)
    rec("L-ja/utf", text=r["text"], words=len(r["text"].split()), has_q="?" in r["text"], cost=r["cost"])


# ---------------------------------------------------------------- texts
def texts(tok):
    qs = ["sjung helan går", "sjung en snapsvisa", "citera Strindberg om kärlek", "sjung Tattoo med Loreen",
          "vad är texten till Dancing Queen", "recitera Du gamla du fria", "citera Astrid Lindgren ur Pippi Långstrump"]
    for q in qs:
        r = A(tok, {"fragment": q, "mode": "push_to_talk", "language": "sv", "context": {}})
        u = r["meta"]
        rec("T " + q, text=r["text"], model=r["model"], first_ms=r["first_ms"], ms=r["ms"], cost=r["cost"], status=r["status"], err=r["err"])


# ---------------------------------------------------------------- exam
def make_pages():
    from PIL import Image, ImageDraw, ImageFont
    f = lambda s: ImageFont.truetype("C:/Windows/Fonts/arial.ttf", s)
    fb = lambda s: ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", s)
    pages = []

    def new():
        im = Image.new("RGB", (1100, 1500), "white")
        return im, ImageDraw.Draw(im)

    im, d = new()
    d.text((60, 50), "Matematik 1b - Delprov B - Provet", font=fb(34), fill="black")
    y = 130
    for t in ["1. Beräkna 15 % av 240.   (1/0/0)",
              "2. Ett par skor kostar 800 kr. På rean är priset sänkt med 25 %.\n    Vad kostar skorna på rean?   (1/1/0)",
              "3. Lös ekvationen 3x - 7 = 14.   (1/1/0)",
              "4. Tabellen visar antal besökare i en butik.\n    Beräkna medelvärdet av antalet besökare per dag.   (1/1/0)"]:
        for ln in t.split("\n"):
            d.text((60, y), ln, font=f(26), fill="black")
            y += 40
        y += 25
    # table for task 4
    x0, y0 = 120, y
    rows = [("Dag", "Besökare"), ("Måndag", "12"), ("Tisdag", "18"), ("Onsdag", "15"), ("Torsdag", "21")]
    for i, (a, b) in enumerate(rows):
        d.rectangle([x0, y0 + i * 44, x0 + 200, y0 + i * 44 + 44], outline="black", width=2)
        d.rectangle([x0 + 200, y0 + i * 44, x0 + 360, y0 + i * 44 + 44], outline="black", width=2)
        d.text((x0 + 12, y0 + i * 44 + 8), a, font=f(24), fill="black")
        d.text((x0 + 212, y0 + i * 44 + 8), b, font=f(24), fill="black")
    y = y0 + 5 * 44 + 40
    d.text((60, y), "5. Figuren visar en rektangel. Beräkna rektangelns area och omkrets.   (1/1/1)", font=f(26), fill="black")
    y += 60
    d.rectangle([160, y, 560, y + 200], outline="black", width=4)
    d.text((330, y + 210), "8 cm", font=f(24), fill="black")
    d.text((580, y + 90), "5 cm", font=f(24), fill="black")
    y += 290
    d.text((60, y), "6. Visa att summan av tre på varandra följande heltal alltid är delbar med 3.   (0/0/2)", font=f(26), fill="black")
    pages.append(im)

    im, d = new()
    d.text((60, 50), "Bedömningsanvisningar - Delprov B", font=fb(34), fill="black")
    y = 130
    for t in ["Uppgift 1: Rätt svar 36. 1 E-poäng.",
              "Uppgift 2: Rätt svar 600 kr. 1 E-poäng för att räkna ut rabatten (200 kr), 1 C-poäng för rätt pris.",
              "Uppgift 3: Rätt svar x = 7. 1 E-poäng för att addera 7 på båda sidor, 1 C-poäng för rätt x.",
              "Uppgift 4: Rätt svar 16,5. 1 E-poäng för summan 66, 1 C-poäng för rätt medelvärde.",
              "Uppgift 5: Area 40 cm2, omkrets 26 cm. 1 E-poäng area, 1 C-poäng omkrets,",
              "    1 A-poäng för rätt enheter (cm2 och cm) och tydlig redovisning.",
              "Uppgift 6: Tre tal n, n+1, n+2 har summan 3n+3 = 3(n+1). 1 A-poäng för uttrycket,",
              "    1 A-poäng för slutsatsen att det är delbart med 3.",
              "",
              "Betygsgränser: E: 4 poäng. C: 7 poäng varav minst 2 poäng på minst C-nivå.",
              "A: 10 poäng varav minst 3 poäng på A-nivå."]:
        d.text((60, y), t, font=f(24), fill="black")
        y += 44
    pages.append(im)
    out = []
    for im in pages:
        b = io.BytesIO()
        im.save(b, "JPEG", quality=80)
        out.append({"media_type": "image/jpeg", "data": base64.b64encode(b.getvalue()).decode()})
    return out


def exam(tok):
    pages = make_pages()
    st, j, ms, ra = P(tok, "exam", {"action": "parse", "pages": pages, "subject": "Matematik 1b"})
    rec("X parse", status=st, ms=ms, body=j, kb=[len(p["data"]) // 1024 for p in pages])
    tasks = (j or {}).get("tasks") if isinstance(j, dict) else None
    bounds = (j or {}).get("boundaries") if isinstance(j, dict) else None
    # ground truth tasks (independent of the parse result) for grading
    T = {
        "2": {"no": "2", "text": "ett par skor kostar 800 kr. På rean är priset sänkt med 25 %. Vad kostar skorna på rean?", "points": {"E": 1, "C": 1, "A": 0},
              "answer": "600 kr", "assessment": "1 E-poäng för att räkna ut rabatten (200 kr), 1 C-poäng för rätt pris 600 kr."},
        "3": {"no": "3", "text": "Lös ekvationen 3x - 7 = 14.", "points": {"E": 1, "C": 1, "A": 0}, "answer": "x = 7",
              "assessment": "1 E-poäng för att addera 7 på båda sidor, 1 C-poäng för rätt x."},
        "4": {"no": "4", "text": "Beräkna medelvärdet av besökare: 12, 18, 15, 21.", "points": {"E": 1, "C": 1, "A": 0}, "answer": "16,5",
              "assessment": "1 E-poäng för summan 66, 1 C-poäng för rätt medelvärde."},
        "5": {"no": "5", "text": "Rektangel 8 cm och 5 cm. Beräkna area och omkrets.", "points": {"E": 1, "C": 1, "A": 1}, "answer": "area 40 cm2, omkrets 26 cm",
              "assessment": "1 E area, 1 C omkrets, 1 A för rätt enheter och tydlig redovisning."},
    }
    grade_cases = [("2", "det blir sexhundra kronor"), ("2", "25 % av 800 är 200, så 800 - 200 = 600 kr"), ("2", "jag tar 800 delat med 0,75 och får 1067"),
                   ("2", "500"), ("2", "600,5 kr"), ("3", "x = 7"), ("3", "3x = 21 så x är sju"), ("3", "x = 21"), ("3", "7 = x"),
                   ("4", "66 delat med 4 är 16,5"), ("4", "ungefär 16"), ("4", "16,6"),
                   ("5", "area 40 cm2 och omkrets 26 cm"), ("5", "area 40, omkrets 13 cm"), ("5", "40 och 26")]
    for no, ans in grade_cases:
        st, j, ms, ra = P(tok, "exam", {"action": "grade", "task": T[no], "answer": ans})
        rec("X grade %s '%s'" % (no, ans), status=st, points=(j or {}).get("points"), numeric=(j or {}).get("numeric"), feedback=(j or {}).get("feedback"), err=None if st == 200 else j)
    for lvl in (1, 2, 3):
        st, j, ms, ra = P(tok, "exam", {"action": "hint", "task": T["2"], "level": lvl})
        rec("X hint %d" % lvl, status=st, hint=(j or {}).get("hint"))
    res = [{"no": "1", "points": {"E": 1, "C": 0, "A": 0}}, {"no": "2", "points": {"E": 1, "C": 1, "A": 0}}, {"no": "3", "points": {"E": 1, "C": 1, "A": 0}},
           {"no": "4", "points": {"E": 1, "C": 0, "A": 0}}, {"no": "5", "points": {"E": 1, "C": 1, "A": 0}}]
    bd = [{"grade": "E", "total": 4}, {"grade": "C", "total": 7, "min_ca": 2}, {"grade": "A", "total": 10, "min_a": 3}]
    st, j, ms, ra = P(tok, "exam", {"action": "summary", "results": res, "boundaries": bd})
    rec("X summary (C-gräns 7: 5E+3C=8 poäng)", status=st, body=j)
    st, j, ms, ra = P(tok, "exam", {"action": "bogus"})
    rec("X okänd action", status=st, body=j)
    st, j, ms, ra = P(tok, "exam", {"action": "parse", "pages": [{"media_type": "image/gif", "data": "AAAA"}]})
    rec("X parse fel format", status=st, body=j)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    secs = sys.argv[1:] or ["social", "interview", "cards", "profile", "subject", "echo", "level", "texts", "exam"]
    st0 = backend_state()
    rec("backend", at_start=st0)
    toks = {}
    fn = {"social": social, "interview": interview, "cards": cards, "profile": profile, "subject": subject, "echo": echo, "level": level,
          "texts": texts, "exam": exam}
    grp = {"social": "a", "interview": "a", "cards": "b", "profile": "b", "exam": "b", "subject": "c", "level": "c", "echo": "d", "texts": "e"}
    for s in secs:
        g = grp[s]
        if g not in toks:
            toks[g] = D.signup()
        rec("== " + s)
        try:
            fn[s](toks[g])
        except Exception as e:
            rec("ERROR " + s, err=repr(e))
        rec("spent so far", answer=round(D.spent, 4), other=round(extra_cost, 4), backend=backend_state())
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    out = ROOT / "reports/qa/data" / (stamp + "-d81-d84.json")
    out.write_text(json.dumps({"backend_start": st0, "backend_end": backend_state(), "spent": round(D.spent + extra_cost, 4), "log": log}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("saved", out, "total", round(D.spent + extra_cost, 4))


if __name__ == "__main__":
    main()
