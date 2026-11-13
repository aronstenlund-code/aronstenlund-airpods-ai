"""O57 (D162): är första meningen (det korta svaret) ensam ett fullgott svar, och hur många ord har den?
Skrivet av Oscar (QA). Läser frågor och svar ur o55_grade.py-körningar (reports/qa/data/*-o55-drill-*.json) och låter
domaren (/provlage-eval grade, Sonnet) bedöma BARA det korta svaret, med studiematerialet i facit så att domaren inte
underkänner sådant som står i materialet (felet i O55). Fullgott = correct och sufficient.
Krav (oscar.md O57): 95/100 fullgoda, median högst 20 ord.
  python -I -X utf8 scripts/qa/o57_first_sentence.py <data.json> [<data.json> ...]
Resultat: reports/qa/data/<tid>-o57-first-sentence.json"""
import datetime as dt, json, pathlib, re, sys, time

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import o55_grade as G  # noqa: E402  (samma session, samma anrop, banken inklusive hållout)

INTRO = re.compile(r"^(det finns (flera|många)|det här är|detta är|.{0,40}\b(är en viktig|handlar om)\b)", re.I)


def first_sentence(s):
    m = re.match(r"(.+?[.!?])(\s|$)", s.strip(), re.S)
    return m.group(1) if m else s.strip()


def main():
    files = sys.argv[1:]
    rows = []
    for f in files:
        d = json.loads(pathlib.Path(f).read_text(encoding="utf-8"))
        for r in d["results"]:
            eid = r["list"]["id"]
            for it in r["items"]:
                rows.append((eid, it["question"], it["short"], it["long"]))
    out = G.ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o57-first-sentence.json")
    res = []
    import os
    if os.environ.get("O57_PREV"):  # fortsätt efter avbrott (domaren 429 vid dagskvoten): återanvänd redan bedömda
        res = [r for r in json.loads(pathlib.Path(os.environ["O57_PREV"]).read_text(encoding="utf-8"))["rows"]]
    done = {(r["exam"], r["question"]) for r in res}
    for eid, q, short, long_ in rows:
        if (eid, q) in done:
            continue
        m = G.M[eid]
        fs = first_sentence(short)
        expect = ("Ett fullgott svar på frågan, ensamt, utan någon fortsättning: själva svaret (orsak, mekanism, fakta "
                  "eller skillnad), inte en inledning. Allt som står i studiematerialet räknas som rätt. Studiematerial:\n"
                  + G.material_text(eid)[:3000])
        case = {"grade": m["grade"] or "högstadiet", "subject": m["subject"], "q": q, "expect": expect,
                "profile": "Korta förklaringar"}
        time.sleep(1.6)
        j, _ = G.call("/functions/v1/provlage-eval", {"action": "grade", "judge": "sonnet", "case": case, "answer": short}, G.S.token())
        G.COST["judge"] += j.get("usage", {}).get("est_cost_usd", 0)
        s = j.get("scores", {})
        ok = bool(s.get("correct")) and bool(s.get("sufficient"))
        row = {"exam": eid, "question": q, "short": short, "first_sentence": fs, "short_words": len(G.words(short)),
               "first_words": len(G.words(fs)), "sentences": len(re.findall(r"[.!?](?:\s|$)", short.strip())) or 1,
               "intro_rule": bool(INTRO.match(short.strip())), "d145": long_.startswith(short.strip()),
               "correct": s.get("correct", 0), "sufficient": s.get("sufficient", 0), "a_level": s.get("a_level", 0),
               "fullgott": ok, "note": j.get("note", "")}
        res.append(row)
        print(f"{'ok ' if ok else 'BAD'} {row['short_words']:2d} ord | {q[:45]:45s} | {short[:70]}", flush=True)
        out.write_text(json.dumps({"rows": res}, ensure_ascii=False, indent=1), encoding="utf-8")
    n = len(res)
    sw = sorted(r["short_words"] for r in res)
    fw = sorted(r["first_words"] for r in res)
    summ = {"n": n, "fullgott": sum(r["fullgott"] for r in res), "correct": sum(bool(r["correct"]) for r in res),
            "sufficient": sum(bool(r["sufficient"]) for r in res), "short_words_p50": sw[n // 2], "short_words_max": sw[-1],
            "first_words_p50": fw[n // 2], "le20": sum(x <= 20 for x in sw), "le25": sum(x <= 25 for x in sw),
            "two_sentences": sum(r["sentences"] >= 2 for r in res), "intro_rule": sum(r["intro_rule"] for r in res),
            "d145": sum(r["d145"] for r in res), "judge_usd": round(G.COST["judge"], 3)}
    out.write_text(json.dumps({"summary": summ, "rows": res}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(summ, ensure_ascii=False), "->", out)


if __name__ == "__main__":
    main()
