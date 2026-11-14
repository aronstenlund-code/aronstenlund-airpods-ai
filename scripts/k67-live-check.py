"""K67 live check (Kevin, 2026-11-14): the app's path (drill answers false, then drill_answers may_fix) on Oscar's
physics, English and history exams, then save with a test account (silent audio, D180) and read what the voice reads.
Usage: python -X utf8 scripts/k67-live-check.py  -> reports/qa/data/<time>-k67-live.json
"""
import concurrent.futures as cf, datetime, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa")); sys.path.insert(0, os.path.join(HERE, "qa", "repetition_bank"))
import qa_testaccount as qa  # noqa: E402
qa.install()
from materials_holdout3 import H3  # noqa: E402
from materials_holdout4 import H4  # noqa: E402
EX = {"h4-fy-hastighet": H4["h4-fy-hastighet"], "h3-en-climate": H3["h3-en-climate"], "h3-hi-franska-revolutionen": H3["h3-hi-franska-revolutionen"], "h4-en-lighthouse": H4["h4-en-lighthouse"]}
MAT = re.compile(r"(?<!\w)(materialet|the notes|the text|the material|anteckningarna)(?!\w)", re.I)

def run(key, ex):
    tok = qa.signup()[0]
    text = "\n\n".join(ex["pages"])
    st, _, raw = qa.call("POST", "/functions/v1/exam", {"action": "drill", "text": text, "questions": 12, "answers": False}, tok, timeout=240)
    if st != 200: return key, {"step1": st, "body": raw[:200].decode()}
    p = json.loads(raw)
    st, _, raw = qa.call("POST", "/functions/v1/exam", {"action": "drill_answers", "subject": p["summary"]["subject"], "grade": p["summary"]["grade"], "notes": p["notes"],
                          "items": p["items"], "may_fix": True}, tok, timeout=240)
    if st != 200: return key, {"step2": st, "body": raw[:200].decode()}
    a = json.loads(raw)
    items = a["items"]
    save = [{"question": i["question"], "short": i["short"], "long": i["long"], **({"screen": i["screen"]} if i.get("screen") else {})} for i in items if i.get("short")]
    st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "save", "drill": {"title": key, "subject": p["summary"]["subject"]}, "items": save}, tok)
    did = json.loads(raw)["drill"]["id"] if st == 200 else None
    fixed = [(b["question"], i["question"]) for b, i in zip(p["items"], items) if b["question"] != i["question"]]
    return key, {"subject": p["summary"]["subject"], "questions": len(items), "fixed": fixed, "drill_id": did, "save": st,
                 "mentions_material": [i["question"] for i in items if MAT.search(i.get("long", ""))],
                 "screen": sum(1 for i in items if i.get("screen")), "items": items,
                 "cost_usd": (p.get("usage", {}).get("est_cost_usd") or 0) + (a.get("usage", {}).get("est_cost_usd") or 0), "_tok": tok}

out = {}
with cf.ThreadPoolExecutor(4) as pool:
    for k, r in pool.map(lambda kv: run(*kv), EX.items()):
        out[k] = r
        print(k, {x: (v if not isinstance(v, list) or x in ("fixed", "mentions_material") else len(v)) for x, v in r.items() if x not in ("items", "_tok")}, flush=True)
stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S")
p = os.path.join(HERE, "..", "reports", "qa", "data", f"{stamp}-k67-live.json")
json.dump({k: {x: v for x, v in r.items() if x != "_tok"} for k, r in out.items()}, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
print("saved", os.path.normpath(p)); print("drills", json.dumps({k: r.get("drill_id") for k, r in out.items()}))
json.dump({k: [r.get("drill_id"), r.get("_tok")] for k, r in out.items()}, open(os.path.join(os.environ.get("TEMP", "."), "k67-drills.json"), "w"))
print("total cost", round(sum(r.get("cost_usd") or 0 for r in out.values()), 3))
