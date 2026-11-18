"""O87 (Oscar moln, 2026-11-18): live-eval med de nya reglerna (D232) på de berörda fallen, två omgångar i samma process.
Visar (1) att de fyra falsklarmen är borta live och (2) att kontona återanvänds (inloggningar räknas, inga 429).
Testkonton (x-earmind-test), 0 ElevenLabs, Claude cirka 0,02 USD. Kör i Actions: python -I -X utf8 scripts/qa/o87_live.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE))
import qa_testaccount as T  # noqa: E402
T.install()
import datetime as dt, importlib.util, json  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
spec = importlib.util.spec_from_file_location("live_eval", HERE.parent / "live-eval.py")
LE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(LE)
SIGNUPS = [0]
real_signup = LE.Backend.signup


def signup(self):
    SIGNUPS[0] += 1
    return real_signup(self)


LE.Backend.signup = signup
ROOT = HERE.parent.parent
cases = json.load(open(ROOT / "scripts/live-eval-cases.json", encoding="utf-8"))
rizz = {s["id"]: s for s in json.load(open(ROOT / "testdata/rizz-scenarios.json", encoding="utf-8"))}
IDS = {"socialt-01", "socialt-02", "socialt-03", "minne-01", "praktiskt-04", "ämnesbyte-10"}
now = dt.datetime.now(dt.timezone.utc)
for rnd in (1, 2):
    for r in LE.run(cases, rizz, LE.reliable_domains(), IDS, now):
        print(json.dumps({"omg": rnd, "id": r["id"], "tur": r["turn"], "anmärkningar": r["problems"], "svar": r["answer"][:140]}, ensure_ascii=False), flush=True)
print(f"=== O87 inloggningar totalt: {SIGNUPS[0]} (6 fall × 2 omgångar; utan återanvändning blir det 12)")
