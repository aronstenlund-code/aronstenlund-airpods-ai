"""T50 (Kevin moln, 2026-11-18): how long save and start take for a new short Säg text, as the app does it
(save with defer_audio + client_id, then start), without and with a style. Test account, x-earmind-test: silent
audio, 0 ElevenLabs; a style costs one Haiku call per new part. The server logs drill_slow with the calls per kind.
Usage: python -X utf8 scripts/t50-timing.py -> reports/qa/data/<time>-t50-timing.json
"""
import json, os, sys, time, uuid, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
tag = str(int(time.time()))

def call(body, tok):
    req = urllib.request.Request(qa.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST", headers=qa.headers(tok))
    req.add_header("X-earmind-test", "kevin-t50")
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=60) as r: st, j = r.status, json.loads(r.read())
    except urllib.error.HTTPError as e: st, j = e.code, json.loads(e.read() or b"{}")
    return st, j, round((time.time() - t0) * 1000)

tok = qa.signup()[0]
rows = []
for i, style in enumerate([None, None, None, "Lugnt", "Glatt"]):
    text = f"Kevin mäter {tag} gång {i}: ring mamma klockan fem och köp mjölk på vägen hem."
    drill = {"kind": "text", "title": f"T50 tid {tag} {i}", "client_id": str(uuid.uuid4()), "said": True}
    if style: drill["style"] = style
    st, s, ms_save = call({"action": "save", "defer_audio": True, "drill": drill, "items": [{"kind": "para", "text": text}]}, tok)
    st2, a, ms_start = call({"action": "start", "id": s.get("drill", {}).get("id")}, tok) if st == 200 else (st, {}, 0)
    rows.append({"i": i, "style": style, "save": st, "save_ms": ms_save, "start": st2, "start_ms": ms_start, "sum_ms": ms_save + ms_start,
                 "said": s.get("drill", {}).get("said"), "style_saved": s.get("drill", {}).get("style")})
    print(json.dumps(rows[-1], ensure_ascii=False), flush=True)
    time.sleep(3)
out = {"rows": rows, "checks": {"all_200": all(r["save"] == 200 and r["start"] == 200 for r in rows)}}
print(json.dumps(out, ensure_ascii=False, indent=1))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-t50-timing.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
sys.exit(0 if out["checks"]["all_200"] else 1)
