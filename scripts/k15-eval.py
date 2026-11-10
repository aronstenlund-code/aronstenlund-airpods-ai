#!/usr/bin/env python3
"""K15 live-eval: two practice exams written for Lumen (scripts/k15-practice-exams.json: NP-like maths Åk 9 with
points and part of the facit, and history study questions without points or facit) against the deployed /exam.
  1. parse from text: the right tasks in the right order (3a/3b), points, facit vs "eget svar", own answers right
     where code can check them (maths);
  2. nav: "fråga 7" / "fråga sju" / "uppgift 3b" / "nästa" land on the right task;
  3. grade with practice: right answers get points, wrong ones none (as D87: correct = right, and explained).
  python -X utf8 -I scripts/k15-eval.py --tokens FILE -> reports/eval/k15-<date>.json"""
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
EXAMS = json.load(open(ROOT / "scripts/k15-practice-exams.json", encoding="utf-8"))


def exam(tok, body):
    o = D.call("POST", "/functions/v1/exam", body, tok, timeout=180)
    return o["status"], D.jbody(o) or {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", required=True)
    a = ap.parse_args()
    tok = PE.signup(a.tokens, 3)
    out = {}
    total_cost = 0.0
    for key, ex in EXAMS.items():
        st, j = exam(tok, {"action": "parse", "text": ex["text"], "subject": ex["subject"], "grade": ex["grade"]})
        tasks = j.get("tasks", [])
        total_cost += (j.get("usage") or {}).get("est_cost_usd", 0)
        nos = [t["no"] for t in tasks]
        r = {"status": st, "nos": nos, "split_ok": nos == ex["expect_nos"]}
        r["points_ok"] = {no: [t["points"]["E"], t["points"]["C"], t["points"]["A"]] == want
                          for no, want in ex.get("points", {}).items() for t in tasks if t["no"] == no}
        r["sources"] = {t["no"]: t.get("answer_source") for t in tasks}
        r["own_ok"] = {}
        for no, want in ex.get("no_facit", {}).items():
            t = next((t for t in tasks if t["no"] == no), None)
            r["own_ok"][no] = bool(t and t.get("answer_source") == "eget svar" and want.replace(",", ".") in t["answer"].replace(",", ".").replace(" ", ""))
        r["spoken_sample"] = tasks[0].get("spoken") if tasks else None
        r["topics"] = [t.get("topic") for t in tasks]
        # nav
        navs = []
        for utt, want in [("fråga 7", "7"), ("fråga sju", "7"), ("uppgift 3b", "3b"), ("nästa", None), ("hoppa över", None), ("upprepa", None)]:
            if want and want not in nos:
                continue
            st2, n = exam(tok, {"action": "nav", "utterance": utt, "current": 2, "nos": nos})
            got = nos[n["index"]] if "index" in n and n.get("index") is not None and n["index"] < len(nos) else None
            ok = (got == want) if want else n.get("action") in ("next", "skip", "repeat")
            navs.append({"utterance": utt, "got": n, "ok": ok})
        r["nav"] = navs
        # grade (practice)
        grades = []
        for no, ans, right in ex["grade"]:
            t = next((t for t in tasks if t["no"] == no), None)
            if not t:
                grades.append({"no": no, "missing": True, "ok": False})
                continue
            time.sleep(1.0)
            st3, g = exam(tok, {"action": "grade", "practice": True, "task": t, "answer": ans})
            total_cost += (g.get("usage") or {}).get("est_cost_usd", 0)
            got = (g.get("total") or 0) > 0
            grades.append({"no": no, "answer": ans, "right": right, "total": g.get("total"), "feedback": g.get("feedback"), "ok": got == right})
            print(key, "grade", no, right, g.get("total"), "|", (g.get("feedback") or "")[:120], flush=True)
        r["grades"] = grades
        r["grade_ok"] = f"{sum(x['ok'] for x in grades)}/{len(grades)}"
        out[key] = r
        print(key, json.dumps({k: v for k, v in r.items() if k in ("status", "split_ok", "points_ok", "own_ok", "grade_ok")}, ensure_ascii=False), flush=True)
        print(" nav", [(x["utterance"], x["ok"]) for x in navs], flush=True)
    out["cost_usd"] = round(total_cost, 4)
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    json.dump(out, open(ROOT / "reports" / "eval" / f"k15-{date}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("cost", out["cost_usd"])


if __name__ == "__main__":
    sys.exit(main())
