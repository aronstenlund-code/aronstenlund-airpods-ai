import importlib.util, json, pathlib, sys, time
"""Oscar QA, O41b: phone tools with the wake word in mode auto (Standardläge) vs tutor (Provläge). ~0.002 USD.
  python -I scripts/qa/o41b_k36_auto.py -> reports/qa/data/<stamp>-o41b-k36-auto.json"""
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path("/home/user/aronstenlund-airpods-ai")
spec = importlib.util.spec_from_file_location("o41", ROOT / "scripts/qa/o41_k36_live.py"); M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
tok = M.O.signup(); rows = []
for mode in ("auto", "tutor"):
    for frag in ("Lumen, ring mamma", "Lumen, sätt en timer på fem minuter", "Lumen, spela lite musik"):
        time.sleep(3.2)
        st, ev, err = M.answer(tok, frag, mode)
        tool = next((d for n, d in ev if n == "tool_call"), None)
        said = "".join(d.get("text", "") for n, d in ev if n == "delta")
        rows.append({"mode": mode, "fragment": frag, "status": st, "tool": tool and tool["name"], "input": (tool or {}).get("input"), "said": said})
        print(mode, "|", frag, "->", st, tool and tool["name"], "| said:", said[:90], flush=True)
import datetime as dt
out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M") + "-o41b-k36-auto.json")
out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8"); print(out)
