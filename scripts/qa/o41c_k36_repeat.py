#!/usr/bin/env python3
"""Oscar QA, O41c/O42: flaky K36 cases three times each (ring Bris, spela musik, ring mamma in Auto). ~0.003 USD.
  python -I scripts/qa/o41c_k36_repeat.py -> reports/qa/data/<stamp>-o41c-k36-repeat.json"""
import importlib.util, json, pathlib, sys, time, datetime as dt
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path("/home/user/aronstenlund-airpods-ai")
spec = importlib.util.spec_from_file_location("o41", ROOT / "scripts/qa/o41_k36_live.py"); M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
tok = M.O.signup(); rows = []
for frag, mode in (("ring Bris", "push_to_talk"), ("spela musik", "push_to_talk"), ("spela musik", "auto"), ("Lumen, spela musik", "auto"), ("ring mamma", "auto")):
    for i in range(3):
        time.sleep(3.2)
        st, ev, err = M.answer(tok, frag, mode)
        tool = next((d for n, d in ev if n == "tool_call"), None)
        said = "".join(d.get("text", "") for n, d in ev if n == "delta")
        rows.append({"mode": mode, "fragment": frag, "try": i + 1, "status": st, "tool": tool and tool["name"], "input": (tool or {}).get("input"), "said": said})
        print(mode, "|", frag, i + 1, "->", st, tool and tool["name"], (tool or {}).get("input"), "| said:", said[:80], flush=True)
out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M") + "-o41c-k36-repeat.json")
out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8"); print(out)
