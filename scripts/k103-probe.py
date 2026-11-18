"""K103 (Kevin moln, 2026-11-18, D232): Oscar's O86 cases through /answer with test accounts, printing every delta
as it came (to see where words run together or lines break), done.timing and the web searches. 0 ElevenLabs
(/answer is text), Claude only. Usage: python -X utf8 scripts/k103-probe.py --ids=text-02,fakta-05 --rounds=2"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import datetime as dt, importlib.util, json, time, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
spec = importlib.util.spec_from_file_location("live_eval", HERE / "live-eval.py")
LE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(LE)
ARGV = dict(a[2:].split("=", 1) for a in _s.argv[1:] if a.startswith("--") and "=" in a)
IDS = set((ARGV.get("ids") or "text-02,fakta-05,k9-neg-5,minne-01,socialt-01").split(","))
ROUNDS = int(ARGV.get("rounds", "2"))

def ask(self, u, body):
    t0 = time.time()
    res = dict(text="", ttft_ms=None, total_ms=None, done={}, options=None, error=None)
    deltas = []
    with self._post("/functions/v1/answer", body, self.tokens[u]) as r:
        ev = None
        for line in r:
            line = line.decode().rstrip("\n")
            if line.startswith("event: "): ev = line[7:]
            elif line.startswith("data: "):
                d = json.loads(line[6:])
                if ev == "delta":
                    if res["ttft_ms"] is None: res["ttft_ms"] = int((time.time() - t0) * 1000)
                    deltas.append(d.get("text", "")); res["text"] += d.get("text", "")
                elif ev == "suggestions":
                    res["options"] = d
                    if res["ttft_ms"] is None: res["ttft_ms"] = int((time.time() - t0) * 1000)
                elif ev == "done": res["done"] = d
                elif ev == "error": res["error"] = d
    res["total_ms"] = int((time.time() - t0) * 1000)
    d = res["done"] or {}
    print(json.dumps({"q": body.get("fragment"), "ttft": res["ttft_ms"], "timing": d.get("timing"), "web": (d.get("usage") or {}).get("web_searches"),
                      "model": (d.get("usage") or {}).get("model"), "deltas": deltas[:80], "options": res["options"]}, ensure_ascii=False), flush=True)
    return res

LE.Backend.ask = ask
_shared = []
_ri = LE.Backend.__init__
def _init(self):
    _ri(self); self.tokens = _shared
LE.Backend.__init__ = _init
ROOT = HERE.parent
cases = json.load(open(ROOT / "scripts" / "live-eval-cases.json", encoding="utf-8"))
rizz = {s["id"]: s for s in json.load(open(ROOT / "testdata" / "rizz-scenarios.json", encoding="utf-8"))}
domains = LE.reliable_domains()
for rnd in range(ROUNDS):
    print(f"=== round {rnd + 1}", flush=True)
    rows = LE.run(cases, rizz, domains, IDS, dt.datetime.now(dt.timezone.utc))
    for r in rows:
        print("ROW", json.dumps({"id": r["id"], "ttft": r["ttft"], "problems": r["problems"], "answer": r["answer"][:400]}, ensure_ascii=False), flush=True)
