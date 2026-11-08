"""O1: repeat the Åk 8 'vad är en derivata' case to measure the spoken-meta leak. Usage: python -I o1_level.py [n]"""
import importlib.util, pathlib, sys, json
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("d81", ROOT / "scripts/qa/d81.py")
M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
n = int(sys.argv[1]) if len(sys.argv) > 1 else 5
tok = M.D.signup()
print("backend", M.backend_state())
for q, setup in [("vad är en derivata", "Prov i Matte imorgon. Årskurs: Åk 8."), ("vad är en derivata", "Prov i Matte imorgon. Årskurs: Åk 6."), ("vad är en ekvation", "Prov i Matte imorgon. Årskurs: Åk 8.")]:
    for i in range(n):
        b = M.prov(setup); b["fragment"] = q
        r = M.A(tok, b)
        t = r["text"]
        print(i, q, "|", setup[-6:], "|", len(t.split()), "ord |", t[:230].replace("\n", " / "), flush=True)
