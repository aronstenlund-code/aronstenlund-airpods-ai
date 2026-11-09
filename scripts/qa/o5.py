#!/usr/bin/env python3
"""Oscar QA, O5: "Lumen, förhör mig" six times in a row with context.already_asked (Kevin's K1.4/K7), the Strindberg quote
(O1 finding D, twice) and the exam grading/summary cases (O1 finding E, the same as d81b.exam_rest).
The other O1 findings are re-run with the O1 scripts: o1_level.py 5 (A), d81.py interview subject (B, C; interview twice).
  python -I scripts/qa/o5.py  -> reports/qa/data/<stamp>-o5.json"""
import datetime as dt, importlib.util, json, pathlib, sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
# NOTE: d81b.py runs its whole suite on import (unguarded main()); never import it. d81.py is guarded.
spec = importlib.util.spec_from_file_location("d81", ROOT / "scripts/qa/d81.py")
M = importlib.util.module_from_spec(spec)
spec.loader.exec_module(M)
D, A, rec = M.D, M.A, M.rec

PROFILES = [  # budget: one profile of six in a row (the history profile is kept for a later run)
    ("bio9", "Prov i Biologi på fredag om cellen och fotosyntesen. Årskurs: Åk 9. Ämne: Biologi. Kontrollfrågor: korta frågor. Förklaringar: mellanlånga förklaringar."),
    ("hist8", "Prov i Historia nästa vecka om franska revolutionen. Årskurs: Åk 8. Ämne: Historia. Kontrollfrågor: korta frågor. Förklaringar: korta förklaringar."),
]


def quiz(tok, key, setup):
    asked, qa = [], []
    for i in range(6):
        b = M.prov(setup, {"fragment": "Lumen, förhör mig", "context": {"already_asked": list(asked), "recent_qa": qa[-3:]}})
        r = A(tok, b)
        q = r["text"].strip()
        rec(f"Q {key} #{i + 1}", text=q, status=r["status"], model=r["model"], first_ms=r["first_ms"], cost=r["cost"], err=r["err"],
            repeat_exact=q in asked, ends_q=q.endswith("?"), sentences=q.count(".") + q.count("?") + q.count("!"))
        if q:
            asked.append(q)
            qa.append({"q": "Lumen, förhör mig", "a": q})


def main():
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    rec("backend", state=M.backend_state())
    tok = D.signup()
    quiz(tok, *PROFILES[0])
    # O1 finding A, reduced to 3 + 3 for the budget (O1 ran 5 + 5 + 5 control)
    for setup in ("Prov i Matte imorgon. Årskurs: Åk 8.", "Prov i Matte imorgon. Årskurs: Åk 6."):
        for i in range(3):
            r = A(tok, M.prov(setup, {"fragment": "vad är en derivata"}))
            rec("L derivata " + setup[-6:], i=i, text=r["text"], model=r["model"], cost=r["cost"], status=r["status"], err=r["err"])
    tok2 = D.signup()
    rec("== interview round 2 (O1 findings B, C)")
    M.interview(tok2)
    for i in range(1):  # O1 finding D
        r = A(tok2, {"fragment": "citera Strindberg om kärlek", "mode": "push_to_talk", "language": "sv", "context": {}})
        rec("T citera Strindberg om kärlek", i=i, text=r["text"], model=r["model"], cost=r["cost"], status=r["status"], err=r["err"])
    # O1 finding E (exam) and round 1 of B/C (interview, subject) ran 17:40-17:48 by the accidental d81b import:
    # reports/qa/data/2026-11-09-1740-o5-d81b-pass.txt
    total = D.spent + M.extra_cost
    rec("spent", usd=round(total, 4))
    path = ROOT / "reports/qa/data" / f"{stamp}-o5.json"
    path.write_text(json.dumps(M.log, ensure_ascii=False, indent=1), encoding="utf-8")
    print("->", path)


if __name__ == "__main__":
    main()
