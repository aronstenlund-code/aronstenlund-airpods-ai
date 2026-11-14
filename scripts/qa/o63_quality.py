"""O63: svarskvaliteten i repetitionsläget på sex nya hållout-prov. Skrivet av Oscar (QA).
Läser en o55_grade-drillkörning (--no-judge) och låter domaren (/provlage-eval grade, Sonnet) bedöma varje fråga två
gånger, alltid med studiematerialet i facit (O57: annars underkänns sådant som står i materialet):
  long   rätt fakta (correct), A-nivå för årskursen (a_level), inget påhittat utöver materialet (stod i expect)
  short  är första meningen ensam ett fullgott svar (correct och sufficient)
Via testkonto (qa_testaccount): inga ElevenLabs-anrop. Domaren är Claude, cirka 0,003 USD per anrop.
  python -I -X utf8 scripts/qa/o63_quality.py <drill.json>
Resultat: reports/qa/data/<tid>-o63-quality.json"""
import datetime as dt, json, pathlib, sys, time

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import o55_grade as G  # noqa: E402

LONG_EXPECT = ("Ett A-svar för {grade} på frågan: rätt fakta, förklarar orsaker och samband med ämnesbegrepp, så tydligt "
               "att eleven inte behöver fråga igen. Det får inte påstå något som strider mot studiematerialet eller lägga "
               "till fakta som inte står där och som kan vara fel. Allt som står i studiematerialet räknas som rätt. "
               "Studiematerial:\n{mat}")
SHORT_EXPECT = ("Ett fullgott svar på frågan, ensamt, utan fortsättning: själva svaret (orsak, mekanism, fakta eller "
                "skillnad), inte en inledning. Allt som står i studiematerialet räknas som rätt. Studiematerial:\n{mat}")


class Tok:
    def __init__(self):
        self.n, self.t = 0, None

    def get(self):
        if self.t is None or self.n >= 60:  # domarens dagskvot per konto (O57)
            self.t, _ = T.signup(True)
            self.n = 0
        self.n += 1
        return self.t


def judge(tok, m, q, answer, expect, profile):
    case = {"grade": m["grade"] or "högstadiet", "subject": m["subject"], "q": q, "expect": expect, "profile": profile}
    for _ in range(4):
        time.sleep(1.2)
        s, _, b = T.call("POST", "/functions/v1/provlage-eval", {"action": "grade", "judge": "sonnet", "case": case, "answer": answer}, tok.get())
        if s == 429:
            time.sleep(20)
            continue
        j = json.loads(b or b"{}")
        return j.get("scores", {}), j.get("note", ""), (j.get("usage") or {}).get("est_cost_usd", 0)
    return {}, "429", 0


def main():
    d = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
    tok, rows, cost = Tok(), [], 0.0
    for r in d["results"]:
        eid = r["list"]["id"]
        m = G.M[eid]
        mat = G.material_text(eid)[:3500]
        for it in r["items"]:
            q, short, long_ = it["question"], it["short"], it["long"]
            sl, nl, c1 = judge(tok, m, q, long_, LONG_EXPECT.format(grade=m["grade"] or "högstadiet", mat=mat), "Utförliga förklaringar")
            ss, ns, c2 = judge(tok, m, q, short, SHORT_EXPECT.format(mat=mat), "Korta förklaringar")
            cost += c1 + c2
            chars = len(q) + len(long_)
            row = {"exam": eid, "grade": m["grade"], "question": q, "short": short, "long": long_,
                   "q_words": len(G.words(q)), "short_words": len(G.words(short)), "chars": chars,
                   "length_class": "normal" if chars <= 800 else "longer" if chars <= 1600 else "too_long",
                   "understanding": bool(it.get("understanding")), "outside_code": bool(it.get("outside")),
                   "long_correct": sl.get("correct", 0), "long_a": sl.get("a_level", 0), "long_note": nl,
                   "short_ok": bool(ss.get("correct")) and bool(ss.get("sufficient")), "short_note": ns}
            rows.append(row)
            print(f"{'ok ' if row['long_correct'] and row['long_a'] and row['short_ok'] else 'BAD'} {eid[3:14]:11s} {q[:55]:55s} "
                  f"L{row['long_correct']}{row['long_a']} K{int(row['short_ok'])} {chars}", flush=True)
            if cost > 0.75:
                print("kostnadstak nått, stoppar")
                break
    n = len(rows)
    summ = {"n": n, "long_correct": sum(bool(x["long_correct"]) for x in rows), "long_a": sum(bool(x["long_a"]) for x in rows),
            "short_ok": sum(x["short_ok"] for x in rows), "understanding": sum(x["understanding"] for x in rows),
            "normal": sum(x["length_class"] == "normal" for x in rows), "judge_usd": round(cost, 3)}
    out = G.ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o63-quality.json")
    out.write_text(json.dumps({"summary": summ, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(summ, ensure_ascii=False), "->", out)


if __name__ == "__main__":
    main()
