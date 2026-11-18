"""K102 (Kevin moln, 2026-11-18, D230): Oscar's five O79 materials through exam drill (answers false, like the app;
no save, 0 ElevenLabs, Claude only). Per material: the number of questions (the default count, as in Oscar's O79), the share of understanding
questions (why/how/explain/compare/what followed, the same idea as Oscar's WHY plus D230's forms), the last check
(usage.final_check: ms, fixed, dropped, refilled) and the whole time. Prints every question for reading.
Usage: python -X utf8 scripts/k102-measure.py -> reports/qa/data/<time>-k102-measure.json"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, re, time, urllib.error  # noqa: E402
_s.path.insert(0, str(HERE / "qa" / "o79"))
_s.path.insert(0, str(HERE / "qa" / "repetition_bank"))
from o79_materials import O79  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")

UNDER = re.compile(r"^\s*(varför|hur |förklara|jämför|beskriv hur|på vilket sätt|vad (blev|blir) följden|vad (hände|händer) (när|om|med|efter)|vilka följder|vilken betydelse|vad betydde|why|how |explain|compare|in what way|what (happened|happens) (when|if|to|after)|what (was|were) the (effects?|results?|consequences?))", re.I)
LINK = re.compile(r"hänger ihop|skillnaden mellan|leder till|ledde till|påverka|the difference between|led to|lead to|affect", re.I)

def call(body, tok):
    for _ in range(4):
        t0 = time.time()
        try:
            st, _h, raw = T.call("POST", "/functions/v1/exam", body, tok, timeout=240)
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            print("  nätfel:", e, flush=True); time.sleep(5); continue
        if st in (429, 502, 503, 504):
            time.sleep(20); continue
        return st, json.loads(raw or b"{}"), round((time.time() - t0) * 1000)
    return st, {}, 0

def photo_pages(m, eid):
    import base64, tempfile
    from make_files import photo  # noqa: PLC0415
    pages = []
    with tempfile.TemporaryDirectory() as d:
        for n, (h, p) in enumerate(m["parts"]):
            path = f"{d}/p{n}.jpg"
            photo(f"{h}\n{p}", path, seed=f"{eid}-{n}")
            pages.append({"media_type": "image/jpeg", "data": base64.b64encode(open(path, "rb").read()).decode()})
    return pages

rows, total = [], 0.0
for eid, m in O79.items():
    tok = T.signup(True)[0]
    body = {"action": "drill", "answers": False, "subject": m["subject"]}
    if m["format"] == "photo": body |= {"pages": photo_pages(m, eid), "text": ""}
    else: body |= {"pages": [], "text": "\n\n".join(f"{h}\n\n{p}" for h, p in m["parts"])}
    st, j, ms = call(body, tok)
    qs = [it.get("question", "") for it in j.get("items", [])]
    under = [q for q in qs if UNDER.search(q) or LINK.search(q)]
    u = j.get("usage") or {}
    fc = u.get("final_check") or {}
    cost = float(u.get("est_cost_usd") or 0); total += cost
    row = {"eid": eid, "status": st, "questions": len(qs), "understanding": len(under), "share": round(len(under) / max(1, len(qs)), 2),
           "final_check_ms": fc.get("ms"), "fixed": fc.get("fixed"), "dropped": fc.get("dropped"), "refilled": fc.get("refilled"), "refill_ms": fc.get("refill_ms"),
           "total_ms": ms, "usd": round(cost, 4)}
    rows.append(row)
    print(f"=== {eid}: " + json.dumps(row, ensure_ascii=False), flush=True)
    for i, q in enumerate(qs, 1): print(f"  {i:2}. {'F' if q in under else ' '} {q}", flush=True)
out = {"rows": rows, "usd": round(total, 3),
       "summary": {"questions": [r["questions"] for r in rows], "share": [r["share"] for r in rows], "final_check_ms": [r["final_check_ms"] for r in rows]}}
print("=== K102 " + json.dumps(out["summary"], ensure_ascii=False) + f" | Claude {total:.3f} USD", flush=True)
json.dump(out, open(HERE.parent / "reports" / "qa" / "data" / (time.strftime("%Y-%m-%d-%H%M%S") + "-k102-measure.json"), "w", encoding="utf8"), ensure_ascii=False, indent=1)
_s.exit(0 if all(r["status"] == 200 for r in rows) else 1)
