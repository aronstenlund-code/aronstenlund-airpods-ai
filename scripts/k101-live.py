"""K101 (Kevin moln, 2026-11-18) live: a test account (x-earmind-test, silent test voice, 0 ElevenLabs) saves a text,
then deletes itself with POST /account/delete. Checks: no confirm = 400; with confirm = 200 and deleted; afterwards
its drill is gone (list empty, get 404) and a second delete answers without error.
Usage: python -X utf8 scripts/k101-live.py -> reports/qa/data/<time>-k101-live.json
"""
import json, os, sys, time, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
tag = str(int(time.time()))

def call(path, body, tok):
    req = urllib.request.Request(qa.URL + "/functions/v1/" + path, data=json.dumps(body).encode(), method="POST", headers=qa.headers(tok))
    req.add_header("X-earmind-test", "kevin-k101")
    try:
        with urllib.request.urlopen(req, timeout=60) as r: return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e: return e.code, json.loads(e.read() or b"{}")

tok = qa.signup()[0]
out, ok = {}, {}
st, s = call("drill", {"action": "save", "start": True, "drill": {"kind": "text", "title": f"K101 {tag}", "said": True}, "items": [{"kind": "para", "text": f"Kevin raderar konto {tag} efter den här meningen."}]}, tok)
did = s.get("drill", {}).get("id")
out["save"] = {"status": st, "id": did}
time.sleep(3)
st1, n = call("account/delete", {}, tok)
st2, d = call("account/delete", {"confirm": True}, tok)
out["no_confirm"] = {"status": st1, "code": (n.get("error") or {}).get("code")}
out["delete"] = {"status": st2, **{k: d.get(k) for k in ("deleted", "removed", "subscription", "notice")}}
st3, l = call("drill", {"action": "list"}, tok)
st4, g = call("drill", {"action": "get", "id": did}, tok)
st5, d2 = call("account/delete", {"confirm": True}, tok)
out["after"] = {"list_status": st3, "list_drills": len(l.get("drills", []) or []), "get_status": st4, "again_status": st5}
ok["saved"] = st == 200 and bool(did)
ok["confirm_required"] = st1 == 400 and out["no_confirm"]["code"] == "confirm_required"
ok["deleted"] = st2 == 200 and d.get("deleted") is True and (d.get("removed") or {}).get("audio_files", 0) >= 1
ok["drill_gone"] = st4 in (401, 404) and (st3 != 200 or out["after"]["list_drills"] == 0)
ok["again_no_error"] = st5 in (200, 401)
out["checks"] = ok
print(json.dumps(out, ensure_ascii=False, indent=1))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k101-live.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
sys.exit(0 if all(ok.values()) else 1)
