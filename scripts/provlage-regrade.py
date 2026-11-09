#!/usr/bin/env python3
"""K2: grade SAVED answers again with the current judge (rubric v2), so a judge change can be told apart from an
answer change. No new answers are generated.

  python3 scripts/provlage-regrade.py reports/eval/provlage-2026-11-08-haiku-structure2-sample.json --judge opus --tag v2
"""
import argparse, concurrent.futures as cf, importlib.util, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("pe", os.path.join(ROOT, "scripts", "provlage-eval.py"))
pe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pe)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--judge", default="opus", choices=["opus", "sonnet"])
    ap.add_argument("--tag", default="v2")
    ap.add_argument("--tokens", default="")
    ap.add_argument("--users", type=int, default=4)
    a = ap.parse_args()
    old = json.load(open(a.src, encoding="utf-8"))
    rows = [r for r in old["rows"] if "answer" in r]
    keys = ("id", "kind", "grade", "subject", "profile", "context", "q", "expect")
    toks = [pe.signup(a.tokens or None, i) for i in range(a.users)]

    def one(i, r):
        case = {k: r.get(k) for k in keys}
        g = pe.post(toks[i % len(toks)], {"action": "grade", "judge": a.judge, "case": case, "answer": r["answer"]})
        if g.get("error"):
            return {**r, "error": g["error"]}
        return {**r, "scores": g["scores"], "first_ok": g["first_answer_suffices"], "strict": g.get("strict"),
                "empty": g.get("empty", 0), "words": g.get("words"), "rubric": g.get("rubric", 1), "note": g.get("note", ""),
                "judge_cost": float((g.get("usage") or {}).get("est_cost_usd") or 0)}

    with cf.ThreadPoolExecutor(max_workers=6) as ex:
        out = list(ex.map(lambda x: one(*x), enumerate(rows)))
    out.sort(key=lambda r: r["id"])
    s = pe.summary(out, old["summary"].get("model", "?"), a.judge)
    old_s = old["summary"]
    base = a.src[:-5] + f"-regrade-{a.tag}"
    json.dump({"summary": s, "previous_summary": old_s, "rows": out}, open(base + ".json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    lines = [f"# Regrade of `{os.path.basename(a.src)}` with judge {a.judge}, rubric v2", "",
             f"Same answers, new judge. First answer enough: **{old_s['first_answer_suffices_pct']} % → {s['first_answer_suffices_pct']} %** "
             f"of {s['graded']}. Strict (also covers the expected points): {s['strict_pct']} %. Empty answers: {s['empty']}.", "",
             "| correct | A level | sufficient | covers | natural | length (code) | no unasked question (code) |", "|---|---|---|---|---|---|---|",
             f"| {s['correct_pct']} % | {s['a_level_pct']} % | {s['sufficient_pct']} % | {s['covers_pct']} % | {s['natural_pct']} % | {s['length_ok_pct']} % | {s['closing_ok_pct']} % |", "",
             f"Judge cost: {s['judge_cost_total_usd']} USD.", ""]
    open(base + ".md", "w", encoding="utf-8").write("\n".join(lines))
    print(json.dumps({"before": old_s["first_answer_suffices_pct"], **s}, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
