"""K1.1 live check of /exam grade with spoken answers (Oscar D81-D84). Requirement: 100 %.

Each case is a task (with scoring rules) and a spoken answer. The check is on the answer point and on the numeric
check: a correct spoken final answer ("x är sju") must get the answer point, a wrong or bare wrong number must not.

Usage: python scripts/exam-grade-eval.py [--only id,id] [--out reports/eval/exam-grade-<date>.md]
"""
import argparse, datetime, json, sys, urllib.request, urllib.error

U = "https://xjczbzfkmbjdebwlccki.supabase.co"
K = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # publishable key (public by design)

EQ = {"no": "1", "text": "Lös ekvationen 3x − 7 = 14.", "points": {"E": 1, "C": 1, "A": 0}, "answer": "x = 7",
      "assessment": "+E för korrekt metod (t.ex. adderar 7 på båda sidor), +C för korrekt svar x = 7"}
MEAN = {"no": "2", "text": "Tabell: Måndag 12, Tisdag 18, Onsdag 15, Torsdag 21. Beräkna medelvärdet.",
        "points": {"E": 1, "C": 1, "A": 0}, "answer": "16,5",
        "assessment": "+E för korrekt metod (summerar och delar med 4), +C för korrekt svar 16,5"}
PCT = {"no": "3", "text": "En jacka kostar 800 kr och sänks med 25 %. Vad kostar den nu?",
       "points": {"E": 2, "C": 0, "A": 0}, "answer": "600 kr",
       "assessment": "+E för korrekt metod (beräknar 25 % av 800), +E för korrekt svar 600 kr"}
FRAC = {"no": "4", "text": "Vad är 1/4 + 1/4 som decimaltal?", "points": {"E": 1, "C": 0, "A": 0}, "answer": "0,5",
        "assessment": "+E för korrekt svar 0,5"}
NEG = {"no": "5", "text": "Lös ekvationen 2x + 9 = 3.", "points": {"E": 1, "C": 1, "A": 0}, "answer": "x = -3",
       "assessment": "+E för korrekt metod, +C för korrekt svar x = −3"}
MIX = {"no": "6", "text": "Hur mycket är 5/2?", "points": {"E": 1, "C": 0, "A": 0}, "answer": "2,5",
       "assessment": "+E för korrekt svar 2,5"}
AREA = {"no": "7", "text": "En rektangel är 8 cm lång och 5 cm bred. Beräkna omkretsen.",
        "points": {"E": 1, "C": 1, "A": 0}, "answer": "26 cm",
        "assessment": "+E för korrekt metod (2·8 + 2·5), +C för korrekt svar 26 cm"}

# (id, task, spoken answer, answer point expected, expect zero total)
CASES = [
    ("eq-sju", EQ, "jag lägger till sju på båda sidor så 3x är 21 så x är sju", True, False),
    ("eq-x-ar-sju", EQ, "x är sju", True, False),
    ("eq-7-lika-x", EQ, "7 = x", True, False),
    ("eq-x-lika-7", EQ, "x = 7", True, False),
    ("eq-lika-med", EQ, "3x minus 7 är 14, 3x är 21, x är lika med sju", True, False),
    ("eq-fel-atta", EQ, "jag lägger till sju så 3x är 21 och x blir åtta", False, False),
    ("eq-bar-fel", EQ, "500", False, True),
    ("eq-coef", EQ, "3x = 21 så x = 21/3 = 7", True, False),
    ("mean-sexton-komma-fem", MEAN, "jag lägger ihop 12 18 15 och 21 som blir 66 och delar med fyra så medelvärdet är sexton komma fem", True, False),
    ("mean-siffror", MEAN, "66 delat med 4 är 16,5", True, False),
    ("mean-fel", MEAN, "66 delat med 4 är 16", False, False),
    ("mean-bar-ungefar", MEAN, "ungefär 16", False, True),
    ("mean-bar-ratt", MEAN, "sexton komma fem", True, False),
    ("mean-fel-decimal", MEAN, "summan är 66 och 66 delat med 4 blir 16,6", False, False),
    ("pct-600", PCT, "25 % av 800 är 200, så 800–200=600", True, False),
    ("pct-sexhundra", PCT, "en fjärdedel av åttahundra är tvåhundra så det blir sexhundra kronor", True, False),
    ("pct-fel-200", PCT, "25 procent av 800 är 200 kronor", False, False),
    ("pct-bar-fel", PCT, "1000", False, True),
    ("pct-600-5", PCT, "800 gånger 0,75 är 600,5 kr", False, False),
    ("frac-en-halv", FRAC, "en fjärdedel plus en fjärdedel är två fjärdedelar alltså en halv", True, False),
    ("frac-noll-komma-fem", FRAC, "det blir noll komma fem", True, False),
    ("frac-fel", FRAC, "det blir två åttondelar", False, True),
    ("neg-minus-tre", NEG, "2x är 3 minus 9 som är minus sex så x blir minus tre", True, False),
    ("neg-siffror", NEG, "2x = -6, x = -3", True, False),
    ("neg-fel-plus", NEG, "2x = 6 så x = 3", False, False),
    ("mix-tva-och-en-halv", MIX, "två och en halv", True, False),
    ("mix-fel", MIX, "det är två", False, True),
    ("area-26", AREA, "två gånger åtta är sexton och två gånger fem är tio så omkretsen blir tjugosex centimeter", True, False),
    ("area-40-fel", AREA, "åtta gånger fem är fyrtio", False, False),
    ("area-vet-inte", AREA, "jag vet inte", False, True),
]


def signup():
    req = urllib.request.Request(U + "/auth/v1/signup", method="POST", data=b"{}",
                                 headers={"apikey": K, "content-type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=30).read())["access_token"]


def grade(tok, task, answer):
    body = {"action": "grade", "task": task, "answer": answer}
    req = urllib.request.Request(f"{U}/functions/v1/exam", method="POST", data=json.dumps(body).encode(),
                                 headers={"apikey": K, "authorization": "Bearer " + tok, "content-type": "application/json"})
    try:
        return 200, json.loads(urllib.request.urlopen(req, timeout=60).read())
    except urllib.error.HTTPError as e:
        return e.code, {"error": e.read().decode("utf-8", "replace")[:200]}


def answer_level(task):
    import re
    m = re.search(r"\+\s*([ECA])[^+]{0,40}?(?:korrekt|rätt|godtagbart)\s+(?:svar|slutsvar)", task["assessment"], re.I)
    return m.group(1).upper() if m else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    only = set(filter(None, a.only.split(",")))
    tok = signup()
    rows, cost = [], 0.0
    for cid, task, ans, want_point, want_zero in CASES:
        if only and cid not in only:
            continue
        code, r = grade(tok, task, ans)
        if code != 200:
            rows.append((cid, ans, False, f"http {code} {r.get('error', '')[:80]}"))
            continue
        cost += r.get("usage", {}).get("est_cost_usd", 0)
        lvl = answer_level(task)
        pts = r["points"]
        got_point = lvl is not None and pts.get(lvl, 0) >= 1
        if task["no"] in ("3",):  # two E points: the second is the answer point
            got_point = pts["E"] >= 2 if want_point else pts["E"] >= 2
        ok = got_point == want_point and (not want_zero or r["total"] == 0)
        note = f"points {pts} numeric {r.get('numeric')}"
        rows.append((cid, ans, ok, note))
        print(("PASS" if ok else "FAIL"), cid, note, file=sys.stderr)
    passed = sum(1 for r in rows if r[2])
    lines = [f"# Exam oral grading, live ({datetime.date.today()})", "",
             f"**{passed}/{len(rows)} pass** · cost {cost:.4f} USD", "", "| Case | Spoken answer | Result | Points |",
             "|---|---|---|---|"]
    for cid, ans, ok, note in rows:
        lines.append(f"| {cid} | {ans} | {'pass' if ok else '**FAIL**'} | {note} |")
    out = "\n".join(lines) + "\n"
    if a.out:
        open(a.out, "w", encoding="utf-8").write(out)
    print(out)
    sys.exit(0 if passed == len(rows) else 1)


if __name__ == "__main__":
    main()
