#!/usr/bin/env python3
"""K18: in Provläge the answer uses the course's own subject terms, also when the student asks in everyday words.
10 questions in everyday words, each with the subject term(s) a good answer at the grade uses (any of them counts).
  python -X utf8 -I scripts/k18-subject-terms.py --tokens FILE --tag before|after -> reports/eval/k18-terms-<tag>-<date>.json"""
import argparse, datetime, importlib.util, json, pathlib, re, sys, time

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


PE = load("pe", ROOT / "scripts/provlage-eval.py")
D = load("demo", ROOT / "scripts/qa/demo.py")
CASES = [
    ["Biologi", "hur gör växter mat", r"fotosyntes"],
    ["Fysik", "vad är det som gör att saker faller ner", r"gravitation|tyngdkraft"],
    ["Geografi", "varför har vi sommar och vinter", r"jordaxel|axelns lutning|lutar|solinstrålning"],
    ["Kemi", "vad händer om man blandar en syra med en bas", r"neutralis"],
    ["Biologi", "hur får man sin ögonfärg från föräldrarna", r"gen(?:er|en)?|allel|arv|ärftlig"],
    ["Biologi", "varför blir man andfådd när man springer", r"cellandning|syrebrist|mjölksyra|syreskuld"],
    ["Fysik", "varför blir vatten till is", r"fryspunkt|stelnar|fasövergång|aggregationsform"],
    ["Samhällskunskap", "hur bestämmer riksdagen nya lagar", r"lagförslag|proposition|vot|motion|beslut"],
    ["Kemi", "varför rostar en cykel", r"oxid|oxidation|korrosion|syre"],
    ["Biologi", "vad är det i blodet som skyddar mot bakterier", r"vita blodkroppar|immunförsvar|antikroppar|lymfocyt|fagocyt"],
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", required=True)
    ap.add_argument("--tag", default="before")
    a = ap.parse_args()
    tok = PE.signup(a.tokens, 5)
    rows = []
    for subject, q, term in CASES:
        setup = f"Prov i {subject} nästa vecka. Årskurs: Åk 8. Ämne: {subject}."
        r = D.ask(tok, {"fragment": q, "mode": "tutor", "language": "sv", "persona": "tutor", "persona_setup": setup, "context": {}})
        ans = r.get("text", "")
        ok = bool(re.search(term, ans, re.I))
        rows.append({"subject": subject, "q": q, "term": term, "ok": ok, "answer": ans[:500]})
        print("ok " if ok else "BAD", subject, "|", q, "|", ans[:110].replace("\n", " "), flush=True)
    s = {"n": len(rows), "uses_term": sum(r["ok"] for r in rows)}
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    json.dump({"summary": s, "rows": rows}, open(ROOT / "reports" / "eval" / f"k18-terms-{a.tag}-{date}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(json.dumps(s))


if __name__ == "__main__":
    sys.exit(main())
