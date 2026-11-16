"""K83 (D206): does step 1 cover the whole material? Runs /exam drill (answers false, 12 questions) on longer test
materials, twice each, and reads usage.coverage: `before` = parts with a question from the model alone (what the old
code gave), `after` = after the coverage calls. Test account, Claude only, 0 ElevenLabs.
Usage: python -X utf8 scripts/k83-coverage.py -> reports/qa/data/<time>-k83-coverage.json
"""
import json, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa")); sys.path.insert(0, os.path.join(HERE, "qa", "repetition_bank"))
import qa_testaccount as qa  # noqa: E402
qa.install()
BANK = {e["id"]: e for e in json.load(open(os.path.join(HERE, "qa", "repetition_bank", "exams.json"), encoding="utf8"))}
txt = lambda k: "\n\n".join(BANK[k]["material"]["pages"])
tok = qa.signup()[0]
mats = {
    "bio-fotosyntes": ("Biologi", "åk 8", txt("bio-ak8-fotosyntes")),
    "so-tre-delar": ("Samhällskunskap", "åk 9", "\n\n".join([txt("hist-ak9-forsta-varldskriget"), txt("sh1b-demokrati"), txt("ge-ak7-klimat")])),
    "no-tre-delar": ("Kemi", "åk 9", "\n\n".join([txt("ke1-mol"), txt("fy-ak9-ellara"), txt("bio-ak8-fotosyntes")])),
}
st, _, raw = qa.call("POST", "/functions/v1/fetch-url", {"url": "https://sv.wikipedia.org/wiki/Fotosyntes"}, tok, timeout=30)
if st == 200:
    mats["wikipedia-fotosyntes"] = ("Biologi", "åk 9", json.loads(raw)["text"][:16000])
out = {}
for name, (subject, grade, text) in mats.items():
    runs = []
    for _ in range(2):
        tok = qa.signup()[0]  # /exam limits generations per account: a fresh test account per run
        t0 = time.perf_counter()
        st, _, raw = qa.call("POST", "/functions/v1/exam", {"action": "drill", "text": text, "questions": 12, "answers": False, "subject": subject, "grade": grade}, tok, timeout=200)
        j = json.loads(raw or b"{}")
        u = j.get("usage") or {}
        runs.append({"status": st, "ms": round((time.perf_counter() - t0) * 1000), "coverage": u.get("coverage"), "cost": u.get("est_cost_usd"),
                     "questions": [i["question"] for i in j.get("items", [])]})
    out[name] = {"chars": len(text), "runs": runs}
    print(name, len(text), [r["coverage"] for r in runs], flush=True)
tot = [r["coverage"] for m in out.values() for r in m["runs"] if r.get("coverage")]
out["summary"] = {"runs_with_parts": len(tot), "parts": sum(c["parts"] for c in tot), "covered_before": sum(c["before"] for c in tot),
                  "covered_after": sum(c["after"] for c in tot), "added": sum(c["added"] for c in tot),
                  "cost_usd": round(sum((r.get("cost") or 0) for m in mats for r in out[m]["runs"]), 4)}
print(json.dumps(out["summary"]))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k83-coverage.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
