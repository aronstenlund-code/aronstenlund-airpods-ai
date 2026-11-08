#!/usr/bin/env python3
"""Oscar QA, pass 2 for D81-D84: re-runs what failed for script reasons (cards, study-profile update, exam grading after the
12/min rate limit, interrupted answer) and repeats the checks Kevin's 14:49 deploy (777b4e4) may have changed (subject-led reading,
interview facts), plus repeats of the song/quote cases. Writes reports/qa/data/<stamp>-d81-d84-pass2.json."""
import importlib.util, json, pathlib, sys, time, datetime as dt
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("d81", ROOT / "scripts/qa/d81.py")
M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
D, A, P, rec = M.D, M.A, M.P, M.rec


def exam_rest(tok):
    T = {"2": {"no": "2", "text": "ett par skor kostar 800 kr. På rean är priset sänkt med 25 %. Vad kostar skorna på rean?", "points": {"E": 1, "C": 1, "A": 0}, "answer": "600 kr", "assessment": "1 E-poäng för att räkna ut rabatten (200 kr), 1 C-poäng för rätt pris 600 kr."},
         "3": {"no": "3", "text": "Lös ekvationen 3x - 7 = 14.", "points": {"E": 1, "C": 1, "A": 0}, "answer": "x = 7", "assessment": "1 E-poäng för att addera 7 på båda sidor, 1 C-poäng för rätt x."},
         "4": {"no": "4", "text": "Beräkna medelvärdet av besökare: 12, 18, 15, 21.", "points": {"E": 1, "C": 1, "A": 0}, "answer": "16,5", "assessment": "1 E-poäng för summan 66, 1 C-poäng för rätt medelvärde."},
         "5": {"no": "5", "text": "Rektangel 8 cm och 5 cm. Beräkna area och omkrets.", "points": {"E": 1, "C": 1, "A": 1}, "answer": "area 40 cm2, omkrets 26 cm", "assessment": "1 E area, 1 C omkrets, 1 A för rätt enheter och tydlig redovisning."}}
    cases = [("4", "16,6"), ("4", "medelvärdet är sexton komma fem"), ("5", "area 40 cm2 och omkrets 26 cm"), ("5", "area 40, omkrets 13 cm"), ("5", "40 och 26"),
             ("3", "x är sju"), ("3", "3x = 14 + 7 = 21, x = 21/3 = 7"), ("2", "jag vet inte")]
    for no, ans in cases:
        st, j, ms, ra = P(tok, "exam", {"action": "grade", "task": T[no], "answer": ans}, wait=6)
        rec("X2 grade %s '%s'" % (no, ans), status=st, points=(j or {}).get("points"), numeric=(j or {}).get("numeric"), feedback=(j or {}).get("feedback"), err=None if st == 200 else j)
    for lvl in (1, 2, 3):
        st, j, ms, ra = P(tok, "exam", {"action": "hint", "task": T["2"], "level": lvl}, wait=6)
        rec("X2 hint %d" % lvl, status=st, hint=(j or {}).get("hint"))
    st, j, ms, ra = P(tok, "exam", {"action": "hint", "task": T["5"], "level": 3, "tried": "area 40"}, wait=6)
    rec("X2 hint 3 task 5", status=st, hint=(j or {}).get("hint"))
    res = [{"no": "1", "points": {"E": 1, "C": 0, "A": 0}}, {"no": "2", "points": {"E": 1, "C": 1, "A": 0}}, {"no": "3", "points": {"E": 1, "C": 1, "A": 0}},
           {"no": "4", "points": {"E": 1, "C": 0, "A": 0}}, {"no": "5", "points": {"E": 1, "C": 1, "A": 0}}]
    bd = [{"grade": "E", "total": 4}, {"grade": "C", "total": 7, "min_ca": 2}, {"grade": "A", "total": 10, "min_a": 3}]
    for name, r in (("8 p", res), ("4 p", res[:2] + [{"no": "3", "points": {"E": 0, "C": 0, "A": 0}}]), ("11 p", res + [{"no": "6", "points": {"E": 0, "C": 0, "A": 2}}] * 1)):
        st, j, ms, ra = P(tok, "exam", {"action": "summary", "results": r, "boundaries": bd}, wait=2)
        rec("X2 summary " + name, status=st, spoken=(j or {}).get("spoken"), body=j)


def cards(tok):
    for name, body in [("C1 åk7", {"summary": M.SUMMARY, "profile": "Årskurs: Åk 7. Förklaringar: korta.", "cards": 6}),
                       ("C2 utan profil, 3 kort", {"summary": M.SUMMARY, "cards": 3}),
                       ("C3 kort summary", {"summary": "Mitokondrien gör energi i cellen.", "cards": 4})]:
        st, j, ms, ra = P(tok, "study-cards", body, wait=16)
        rec(name, status=st, ms=ms, n_cards=len((j or {}).get("cards", [])), n_test=len((j or {}).get("test", [])), cards=(j or {}).get("cards"), tests=(j or {}).get("test"), err=None if st == 200 else j)
    for name, body in (("C4 tom summary", {"summary": ""}), ("C5 för lång summary", {"summary": "x" * 7000})):
        st, j, ms, ra = P(tok, "study-cards", body, wait=16)
        rec(name, status=st, body=j)


def prof_upd(tok):
    time.sleep(10)
    st, j, ms, ra = P(tok, "study-profile", {"text": "och kemi", "profile": {"grade": "y9", "course": "", "subject": "Biologi", "exam_date": None}})
    rec("P-upd uppdatera med befintlig profil", status=st, profile=(j or {}).get("profile"), n_terms=len((j or {}).get("terms", [])))
    st, j, ms, ra = P(tok, "study-profile", {"text": "provet är flyttat till torsdag", "profile": {"grade": "y9", "course": "", "subject": "Biologi", "exam_date": "2026-11-13"}})
    rec("P-upd flytta provet", status=st, profile=(j or {}).get("profile"))


def interrupted(tok):
    a = "Fotosyntes är processen där växter använder ljusenergi för att bygga socker av koldioxid och vatten"
    r = A(tok, {"fragment": "fortsätt", "mode": "tutor", "language": "sv", "context": {"recent_qa": [{"q": "förklara fotosyntesen", "a": a, "interrupted": True}]}})
    rec("I-int interrupted fortsätt", text=r["text"], status=r["status"], cost=r["cost"], err=r["err"])


def songs(tok):
    for q in ["sjung helan går", "sjung helan går", "sjung en snapsvisa", "sjung en snapsvisa", "vad är texten till Dancing Queen", "ge mig texten till Blinding Lights", "sjung Små grodorna"]:
        r = A(tok, {"fragment": q, "mode": "push_to_talk", "language": "sv", "context": {}})
        rec("T2 " + q, text=r["text"], model=r["model"], first_ms=r["first_ms"], cost=r["cost"], status=r["status"], err=r["err"])


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    st0 = M.backend_state()
    rec("backend", start=st0)
    steps = [("exam", exam_rest, "b"), ("cards", cards, "b"), ("prof", prof_upd, "b"), ("interrupted", interrupted, "c"),
             ("interview", M.interview, "d"), ("subject", M.subject, "e"), ("social", M.social, "f"), ("songs", songs, "g")]
    toks = {}
    for name, fn, g in steps:
        if g not in toks:
            toks[g] = D.signup()
        rec("== " + name)
        try:
            fn(toks[g])
        except Exception as e:
            rec("ERROR " + name, err=repr(e))
        rec("spent", answer=round(D.spent, 4), other=round(M.extra_cost, 4), backend=M.backend_state())
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M") + "-d81-d84-pass2.json")
    out.write_text(json.dumps({"backend_start": st0, "backend_end": M.backend_state(), "spent": round(D.spent + M.extra_cost, 4), "log": M.log}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("saved", out, "total", round(D.spent + M.extra_cost, 4))


main()
