"""O87 (Oscar moln, 2026-11-18): bevis att evalens nya regler (D232) bara tar bort de fyra falsklarmen.
Kör nattens 388 lagrade svar (reports/eval/latest.json) genom live-eval:s run() två gånger, med de gamla och de nya
reglerna och fallen, utan nät: Backend.ask ersätts av en som lämnar tillbaka det lagrade svaret och tiden.
    python3 -I scripts/qa/o87_eval_rules_diff.py OLD_LIVE_EVAL.py OLD_CASES.json
Skillnaden mellan körningarna är bara regeländringen (samma svar in i båda). 0 nät, 0 Claude."""
import datetime, importlib.util, json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
rows = json.load(open(ROOT / "reports/eval/latest.json", encoding="utf-8"))


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def evaluate(le, cases_path):
    le.ROOT = str(ROOT)
    it = iter(rows)

    def ask(self, u, body):
        r = next(it)
        return dict(text=r["answer"] if not r["answer"].startswith(("kalibrering", "{")) else "", ttft_ms=r["ttft"], total_ms=r["total"],
                    done={"relation": r.get("relation")}, options=r["answer"].split(" | ") if r["q"] == "(Rizz)" else None, error=None)
    le.Backend.ask = ask
    le.Backend.signup = lambda self: "x"
    le.time.sleep = lambda s: None
    cases = json.load(open(cases_path, encoding="utf-8"))
    rizz = {s["id"]: s for s in json.load(open(ROOT / "testdata/rizz-scenarios.json", encoding="utf-8"))}
    now = datetime.datetime(2026, 11, 18, 3, 0, tzinfo=datetime.timezone.utc)
    return le.run(cases, rizz, le.reliable_domains(), set(), now)


old = evaluate(load(sys.argv[1], "le_old"), sys.argv[2])
new = evaluate(load(ROOT / "scripts/live-eval.py", "le_new"), ROOT / "scripts/live-eval-cases.json")
assert len(old) == len(new) == len(rows), (len(old), len(new), len(rows))
diff = [(o["id"], o["turn"], o["problems"], n["problems"]) for o, n in zip(old, new) if o["problems"] != n["problems"]]
print(f"turer {len(new)}; med anmärkning gamla regler {sum(1 for o in old if o['problems'])}, nya regler {sum(1 for n in new if n['problems'])}")
print(f"turer där utfallet ändrades: {len(diff)}")
for d in diff:
    print(json.dumps({"id": d[0], "tur": d[1], "förut": d[2], "nu": d[3]}, ensure_ascii=False))
