"""K69 (Kevin, 2026-11-15): time from Skapa frågor to Stämmer det här? = /exam drill with answers false (the app's step 1).
Per run: wall time, and per step (plan, shorten) the server's ms and tokens. Test accounts (D180; /exam never calls ElevenLabs).
Usage: python -X utf8 scripts/k69-measure.py [label] [counts...] -> reports/qa/data/<time>-k69-<label>.json
"""
import datetime, json, os, sys, time, concurrent.futures as cf
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa")); sys.path.insert(0, os.path.join(HERE, "qa", "repetition_bank"))
import qa_testaccount as qa  # noqa: E402
qa.install()
from materials_holdout3 import H3  # noqa: E402
import base64, glob
BANK = {e["id"]: e for e in json.load(open(os.path.join(HERE, "qa", "repetition_bank", "exams.json"), encoding="utf8"))}
label = sys.argv[1] if len(sys.argv) > 1 else "before"
counts = [int(x) for x in sys.argv[2:]] or [3, 15, 20]
EX = os.environ.get("K69_EX", "photo:bio-ak8-fotosyntes,text:bio-ak8-fotosyntes,photo:h3-hi-franska-revolutionen").split(",")

def one(key, n):
    tok = qa.signup()[0]
    kind, name = key.split(":")
    if kind == "photo":
        files = sorted(glob.glob(os.path.join(HERE, "qa", "repetition_bank", "files", name, "*.jpg")))
        body = {"pages": [{"media_type": "image/jpeg", "data": base64.b64encode(open(f, "rb").read()).decode()} for f in files]}
    else:
        pages = (H3.get(name) or BANK[name]["material"])["pages"]
        body = {"text": "\n\n".join(pages)}
    t0 = time.perf_counter()
    st, _, raw = qa.call("POST", "/functions/v1/exam", {"action": "drill", "questions": n, "answers": False, **body}, tok, timeout=200)
    wall = round((time.perf_counter() - t0) * 1000)
    if st != 200: return {"key": key, "n": n, "status": st, "wall_ms": wall, "body": raw[:200].decode()}
    j = json.loads(raw); u = j.get("usage", {})
    step = lambda k: {x: u.get(k, {}).get(x) for x in ("ms", "input_tokens", "output_tokens")} if u.get(k) else None
    return {"key": key, "n": n, "status": st, "wall_ms": wall, "server_ms": u.get("ms"), "plan": step("plan"), "shorten": step("shorten"),
            "questions": len(j.get("items", [])), "notes_chars": len(j.get("notes", "")), "cost": u.get("est_cost_usd"),
            "items": [i["question"] for i in j.get("items", [])]}

jobs = [(k, n) for n in counts for k in EX]
out = []
with cf.ThreadPoolExecutor(3) as pool:
    for r in pool.map(lambda a: one(*a), jobs):
        out.append(r)
        print(r["key"], r["n"], r.get("status"), "wall", r["wall_ms"], "plan", r.get("plan"), "shorten", r.get("shorten"), "q", r.get("questions"), "notes", r.get("notes_chars"), flush=True)
stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S")
p = os.path.join(HERE, "..", "reports", "qa", "data", f"{stamp}-k69-{label}.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
print("saved", os.path.normpath(p), "cost", round(sum(r.get("cost") or 0 for r in out), 3))
