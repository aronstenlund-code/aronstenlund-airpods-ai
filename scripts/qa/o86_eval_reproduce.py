"""O86 (Oscar moln, 2026-11-18): nattens live-eval 2026-11-18, de 22 turerna med anmärkning, körda igen 3 gånger var med
samma kroppar som scripts/live-eval.py, plus serverns egen tidsuppdelning (done.timing, breakdown, usage.web_searches,
model). Testkonton (qa_testaccount: x-earmind-test), 0 ElevenLabs (/answer är text), Claude cirka 0,2 USD.
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o86_eval_reproduce.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE))
import qa_testaccount as T  # noqa: E402
T.install()
import datetime as dt, importlib.util, json, statistics  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
spec = importlib.util.spec_from_file_location("live_eval", HERE.parent / "live-eval.py")
LE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(LE)

IDS = ["fakta-05", "fakta-09", "ämnesbyte-10", "symboler-08", "praktiskt-02", "praktiskt-03", "praktiskt-04", "praktiskt-07",
       "socialt-01", "socialt-02", "socialt-03", "minne-01", "text-01", "text-02", "text-03", "text-04", "k7-logik-01",
       "k9-harder_question-1", "k9-harder_question-2", "k9-harder_question-3", "k9-neg-5", "k20-05"]
DONE = []
real_ask = LE.Backend.ask


def ask(self, u, body):
    r = real_ask(self, u, body)
    d = r.get("done") or {}
    DONE.append({"q": body.get("fragment"), "timing": d.get("timing"), "breakdown": d.get("breakdown"),
                 "web": (d.get("usage") or {}).get("web_searches"), "model": (d.get("usage") or {}).get("model"), "source": d.get("source")})
    return r


LE.Backend.ask = ask
# samma konton i alla omgångar (live-eval skapar annars 12 nya per omgång, och inloggningen ger 429 i omgång 3)
_shared_tokens = []
_real_init = LE.Backend.__init__


def _init(self):
    _real_init(self)
    self.tokens = _shared_tokens


LE.Backend.__init__ = _init
import os  # noqa: E402
ARGV = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
if ARGV.get("ids"):
    IDS = ARGV["ids"].split(",")
ROUNDS = int(ARGV.get("rounds", "3"))
ROOT = HERE.parent.parent
cases = json.load(open(ROOT / "scripts" / "live-eval-cases.json", encoding="utf-8"))
real = ROOT / "scripts" / "real-user-cases.json"
if real.exists():
    cases += json.load(open(real, encoding="utf-8"))
rizz = {s["id"]: s for s in json.load(open(ROOT / "testdata" / "rizz-scenarios.json", encoding="utf-8"))}
domains = LE.reliable_domains()
now = dt.datetime.now(dt.timezone.utc)
print("fall hittade:", sorted({c["id"] for c in cases if c["id"] in IDS}), "saknas:", sorted(set(IDS) - {c["id"] for c in cases}), flush=True)
rows_all = []
for rnd in range(ROUNDS):
    DONE.clear()
    rows = LE.run(cases, rizz, domains, set(IDS), now)
    meta = {d["q"]: d for d in DONE}
    for r in rows:
        m = meta.get(r["q"], {})
        r["round"] = rnd + 1
        r["server"] = m
        rows_all.append(r)
        print(json.dumps({"rnd": rnd + 1, "id": r["id"], "turn": r["turn"], "ttft": r["ttft"], "problems": r["problems"],
                          "timing": m.get("timing"), "type": (m.get("breakdown") or {}).get("answer_type"), "web": m.get("web"),
                          "model": m.get("model"), "source": m.get("source"), "svar": r["answer"][:220]}, ensure_ascii=False), flush=True)

print("\n=== O86 per fall (ttft ms över 3 omgångar, anmärkningar)")
by = {}
for r in rows_all:
    by.setdefault((r["id"], r["turn"]), []).append(r)
for (cid, t), rs in by.items():
    tt = [r["ttft"] for r in rs if r["ttft"] is not None]
    probs = sorted({p.split(":")[0] for r in rs for p in r["problems"]})
    print(json.dumps({"id": cid, "turn": t, "ttft": tt, "median": statistics.median(tt) if tt else None,
                      "web": [((r["server"] or {}).get("web")) for r in rs], "anmärkningar": probs,
                      "antal med anmärkning": sum(1 for r in rs if r["problems"])}, ensure_ascii=False), flush=True)
cost = sum(r.get("cost") or 0 for r in rows_all)
print(f"=== O86 turer {len(rows_all)}, med anmärkning {sum(1 for r in rows_all if r['problems'])}, Claude {cost:.3f} USD")
