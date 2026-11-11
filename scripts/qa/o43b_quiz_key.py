#!/usr/bin/env python3
"""Oscar QA, O43b: does /answer give done.quiz_key (K40) when Lumen asks a check question ("förhör mig" in Provläge)?
Checks: present, the answer fits the spoken question, 3-5 alternatives, the [[SVAR]] line is never in the spoken text.
~0.02 USD per call (Provläge model).
  python -I scripts/qa/o43b_quiz_key.py [--n 4] -> reports/qa/data/<stamp>-o43b-quizkey.json"""
import argparse, datetime as dt, importlib.util, json, pathlib, sys, time
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o41", ROOT / "scripts/qa/o41_k36_live.py"); M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
SETUPS = {
    "geo": "Prov i Geografi nästa vecka om de 50 mest kända sjöarna, floderna och kuststäderna. Årskurs: Åk 9. Ämne: Geografi. Förklaringar: korta förklaringar. Kontrollfrågor: korta frågor.",
    "bio": "Prov i Biologi nästa vecka om cellen, fotosyntesen, genetik och kroppen. Årskurs: Åk 9. Ämne: Biologi. Förklaringar: korta förklaringar. Kontrollfrågor: korta frågor.",
}


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--n", type=int, default=4); a = ap.parse_args()
    tok, rows = M.O.signup(), []
    for i in range(a.n):
        ex = "geo" if i % 2 == 0 else "bio"
        time.sleep(3.2)
        body = {"fragment": "Förhör mig", "mode": "tutor", "language": "sv", "persona": "tutor", "persona_setup": SETUPS[ex],
                "context": {"recent_qa": [{"q": "Förhör mig", "a": r["said"]} for r in rows if r["exam"] == ex][-3:]}}
        import urllib.request
        req = urllib.request.Request(M.D.URL + "/functions/v1/answer", data=json.dumps(body).encode(), method="POST",
                                     headers={"apikey": M.D.KEY, "content-type": "application/json", "authorization": "Bearer " + tok})
        with urllib.request.urlopen(req, timeout=60) as x:
            ev = []
            for f in x.read().decode().split("\n\n"):
                e = [l[7:] for l in f.split("\n") if l.startswith("event: ")]; d = [l[6:] for l in f.split("\n") if l.startswith("data: ")]
                if e and d:
                    ev.append((e[0], json.loads(d[0])))
        said = "".join(d.get("text", "") for n, d in ev if n == "delta")
        done = next((d for n, d in ev if n == "done"), {}) or {}
        qk = done.get("quiz_key")
        rows.append({"exam": ex, "said": said, "quiz_key": qk, "svar_line_spoken": "[[" in said or "SVAR" in said, "usage": done.get("usage")})
        print(ex, "|", said[:110].replace("\n", " "), "|| quiz_key:", qk, flush=True)
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o43b-quizkey.json")
    out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"quiz_key present {sum(bool(r['quiz_key']) for r in rows)}/{len(rows)}, spoken marker {sum(r['svar_line_spoken'] for r in rows)} ->", out)


if __name__ == "__main__":
    main()
