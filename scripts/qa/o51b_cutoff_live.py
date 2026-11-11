#!/usr/bin/env python3
"""Oscar QA, O51b: live check of isCutOff (Kevin's standing round 15) in Auto (Standardläge): complete questions that
end on "är"/"blir"/"har"/"som" without "?" (as Scribe often writes them). Silent (done.cut_off) = wrong. Haiku, ~0.01 USD.
  python -I scripts/qa/o51b_cutoff_live.py -> reports/qa/data/<stamp>-o51b.json"""
import datetime as dt, importlib.util, json, pathlib, sys, time
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o41", ROOT / "scripts/qa/o41_k36_live.py"); M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
CASES = ["kan du säga vad klockan är", "vad tror du att svaret är", "hur svårt tror du provet blir", "kan du kolla hur varmt det blir i morgon",
         "vad betyder ordet och", "hur gammal tror du att jag är", "Lumen, vet du vad klockan är", "när tror du att bussen kommer"]


def main():
    tok, rows = M.O.signup(), []
    for frag in CASES:
        time.sleep(3.2)
        st, ev, err = M.answer(tok, frag, "auto")
        said = "".join(d.get("text", "") for n, d in ev if n == "delta")
        done = next((d for n, d in ev if n == "done"), {}) or {}
        meta = next((d for n, d in ev if n == "meta"), {}) or {}
        rows.append({"fragment": frag, "status": st, "said": said, "cut_off": done.get("cut_off"), "is_question": meta.get("is_question"), "usage": done.get("usage")})
        print(frag, "->", "SILENT cut_off" if done.get("cut_off") else ("silent" if not said.strip() else "answered"), "|", said[:80], flush=True)
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o51b.json")
    out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"silent {sum(not r['said'].strip() for r in rows)}/{len(rows)}, cut_off {sum(bool(r['cut_off']) for r in rows)} ->", out)


if __name__ == "__main__":
    main()
