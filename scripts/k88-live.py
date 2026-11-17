"""K88 (Kevin moln, 2026-11-17) live with a test account (D180: the test voice, 0 ElevenLabs): the same client_id
twice gives one exam; two at once give one exam; without client_id two saves give two; a bad id is 400.
Usage: python -X utf8 scripts/k88-live.py -> reports/qa/data/<time>-k88-live.json
"""
import json, os, sys, time, uuid, urllib.request
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
tag = str(int(time.time()))
ITEMS = [{"question": f"Varför behövs klorofyll {tag}?", "short": "Det fångar ljus.", "long": "Det fångar ljus. Mer."}]

def call(body, tok):
    req = urllib.request.Request(qa.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST", headers=qa.headers(tok))
    try:
        with urllib.request.urlopen(req, timeout=120) as r: return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e: return e.code, json.loads(e.read() or b"{}")

out, ok = {}, {}
tok = qa.signup()[0]
def mine(title):
    st, l = call({"action": "list"}, tok)
    return [d["id"] for d in (l.get("drills") if isinstance(l, dict) else l) or [] if d.get("title") == title]
cid = str(uuid.uuid4())
st1, a = call({"action": "save", "defer_audio": True, "drill": {"title": f"K88a {tag}", "client_id": cid}, "items": ITEMS}, tok)
st2, b = call({"action": "save", "defer_audio": True, "drill": {"title": f"K88a {tag}", "client_id": cid}, "items": ITEMS}, tok)
out["twice"] = {"status": [st1, st2], "ids": [a.get("drill", {}).get("id"), b.get("drill", {}).get("id")], "already_saved": b.get("already_saved"), "listed": len(mine(f"K88a {tag}"))}
ok["twice_one_exam"] = st1 == 200 and st2 == 200 and out["twice"]["ids"][0] == out["twice"]["ids"][1] and b.get("already_saved") is True and out["twice"]["listed"] == 1
cid2 = str(uuid.uuid4())
with ThreadPoolExecutor(2) as ex:
    rs = list(ex.map(lambda _: call({"action": "save", "defer_audio": True, "drill": {"title": f"K88b {tag}", "client_id": cid2}, "items": ITEMS}, tok), [1, 2]))
out["at_once"] = {"status": [r[0] for r in rs], "ids": [r[1].get("drill", {}).get("id") for r in rs], "listed": len(mine(f"K88b {tag}"))}
ok["at_once_one_exam"] = all(r[0] == 200 for r in rs) and out["at_once"]["ids"][0] == out["at_once"]["ids"][1] and out["at_once"]["listed"] == 1
for _ in range(2): call({"action": "save", "defer_audio": True, "drill": {"title": f"K88c {tag}"}, "items": ITEMS}, tok)
out["without"] = {"listed": len(mine(f"K88c {tag}"))}
ok["without_two_exams"] = out["without"]["listed"] == 2
st, e = call({"action": "save", "drill": {"title": "x", "client_id": "abc"}, "items": ITEMS}, tok)
out["bad_id"] = st
ok["bad_id_400"] = st == 400
out["checks"] = ok
print(json.dumps(out, ensure_ascii=False, indent=1))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k88-live.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
sys.exit(0 if all(ok.values()) else 1)
