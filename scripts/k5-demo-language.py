#!/usr/bin/env python3
"""K5: the demo's answers are the first impression. 10 typical demo questions (source "demo", Frågor), each answer
graded by Sonnet (provlage-eval "grade": correct, natural incl. language) plus a code check for Swedish slips seen
before (wrong gender on common nouns, invented words from Oscar's list). Demo caps: 5 per visitor, 20 per network,
so four test users take turns.
  python -X utf8 -I scripts/k5-demo-language.py --tokens FILE --tag haiku|sonnet -> reports/eval/k5-demo-<tag>-<date>.json"""
import argparse, datetime, importlib.util, json, pathlib, re, sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


PE = load("pe", ROOT / "scripts/provlage-eval.py")
D = load("demo", ROOT / "scripts/qa/demo.py")
QS = ["vad är fotosyntes", "varför är himlen blå", "hur fungerar en vaccin", "vem var Gustav Vasa", "vad är skillnaden mellan väder och klimat",
      "hur räknar man ut procent", "varför har vi skottår", "vad är en atom", "hur uppstår regnbågar", "vad betyder demokrati"]
# slips seen in demo answers (Oscar 2026-11-08 finding 3) and common gender errors
SLIPS = re.compile(r"\b(?:oprätt|ett kapplöpning|en vaccin|ett kubikdecimeter|en kommunfullmäktige|ett atom|en skottår|ett regnbåge|en klimat|ett demokrati)\b", re.I)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", required=True)
    ap.add_argument("--tag", default="haiku")
    ap.add_argument("--slots", default="0,1,2,3", help="four token slots (demo: 5 questions per visitor and day)")
    a = ap.parse_args()
    toks = [PE.signup(a.tokens, int(i)) for i in a.slots.split(",")]
    rows = []
    for i, q in enumerate(QS):
        tok = toks[i // 3 % 4]
        r = D.ask(tok, {"fragment": q, "mode": "push_to_talk", "language": "sv", "context": {}, "source": "demo"})
        ans = r.get("text", "")
        case = {"grade": "", "subject": "", "kind": "demo", "profile": "", "context": [], "q": q,
                "expect": "Ett kort, korrekt svar på naturlig svenska för en besökare på en demosida (2-3 meningar)."}
        g = PE.post(tok, {"action": "grade", "judge": "sonnet", "case": case, "answer": ans}) if ans else {}
        sc = g.get("scores") or {}
        rows.append({"q": q, "status": r["status"], "answer": ans, "model": ((r.get("done") or {}).get("usage") or {}).get("model"),
                     "correct": sc.get("correct"), "natural": sc.get("natural"), "lang_ok": sc.get("lang_ok"),
                     "slip": bool(SLIPS.search(ans)), "note": g.get("note", ""), "cost": r.get("cost"), "ms": r.get("first_ms")})
        print(r["status"], rows[-1]["model"], sc.get("correct"), sc.get("natural"), rows[-1]["slip"], "|", q, "|", ans[:90], "|", (g.get("note") or "")[:80], flush=True)
    ok = [x for x in rows if x["status"] == 200 and x["answer"]]
    s = {"n": len(rows), "answered": len(ok), "correct": sum(x["correct"] == 1 for x in ok), "natural": sum(x["natural"] == 1 for x in ok),
         "slips": sum(x["slip"] for x in ok), "cost_mean_usd": round(sum(x["cost"] or 0 for x in ok) / max(1, len(ok)), 5),
         "first_ms_p50": sorted(x["ms"] or 0 for x in ok)[len(ok) // 2] if ok else None}
    json.dump({"summary": s, "rows": rows}, open(ROOT / "reports" / "eval" / f"k5-demo-{a.tag}-{datetime.date.today()}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(json.dumps(s))


if __name__ == "__main__":
    sys.exit(main())
