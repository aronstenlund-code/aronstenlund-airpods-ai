#!/usr/bin/env python3
"""Oscar QA, O52: "what time is it" in Standardläge (mode auto) vs the real Stockholm time. The model is given the time
and says it in everyday Swedish; this checks the spoken hour and minutes ("tjugo över åtta" = 20:20) against the clock.
Haiku, ~0.005 USD.  python -I scripts/qa/o52_clock_live.py -> reports/qa/data/<stamp>-o52-clock.json"""
import datetime as dt, importlib.util, json, pathlib, sys, time, zoneinfo
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.argv = sys.argv[:1] + ["--tag", "x"]
s = importlib.util.spec_from_file_location("m", ROOT / "scripts/qa/o51_k42_live.py"); M = importlib.util.module_from_spec(s); s.loader.exec_module(M)
Q = ["Lumen, vad är klockan", "Lumen, hur mycket är klockan", "kan du säga vad klockan är", "Lumen, vad är klockan nu", "Lumen, vet du vad klockan är"]


def main():
    tok, rows = M.M.O.signup(), []
    for q in Q:
        time.sleep(3.2)
        now = dt.datetime.now(zoneinfo.ZoneInfo("Europe/Stockholm")).strftime("%H:%M")
        r = M.ask(tok, q)
        rows.append({"question": q, "stockholm_time": now, "said": r["said"], "model": (r.get("usage") or {}).get("model")})
        print(now, "|", q, "|", r["said"][:120], flush=True)
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o52-clock.json")
    out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8"); print(out)


if __name__ == "__main__":
    main()
