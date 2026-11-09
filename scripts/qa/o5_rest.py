"""O5, the rest after o5.py stopped on a 90 s read timeout in the 3rd derivata call: Åk 6 derivata x2, interview round 2, Strindberg x1.
  python -I scripts/qa/o5_rest.py -> reports/qa/data/<stamp>-o5-rest.json"""
import datetime as dt, importlib.util, json, pathlib, sys
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("d81", ROOT / "scripts/qa/d81.py")
M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
D, A, rec = M.D, M.A, M.rec
stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
rec("backend", state=M.backend_state())
tok = D.signup()
for i in range(2):
    try:
        r = A(tok, M.prov("Prov i Matte imorgon. Årskurs: Åk 6.", {"fragment": "vad är en derivata"}))
        rec("L derivata Åk 6.", i=i, text=r["text"], model=r["model"], cost=r["cost"], status=r["status"], err=r["err"], first_ms=r["first_ms"], ms=r["ms"])
    except Exception as e:
        rec("L derivata Åk 6.", i=i, exception=repr(e)[:200])
rec("== interview round 2")
M.interview(tok)
r = A(tok, {"fragment": "citera Strindberg om kärlek", "mode": "push_to_talk", "language": "sv", "context": {}})
rec("T citera Strindberg om kärlek", text=r["text"], model=r["model"], cost=r["cost"], status=r["status"], err=r["err"])
rec("spent", usd=round(D.spent + M.extra_cost, 4))
(ROOT / "reports/qa/data" / f"{stamp}-o5-rest.json").write_text(json.dumps(M.log, ensure_ascii=False, indent=1), encoding="utf-8")
