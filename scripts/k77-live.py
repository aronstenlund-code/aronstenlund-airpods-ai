"""K77 (Kevin moln, 2026-11-15) live: Repetitionsläget in Aron's analysis (D197). From Actions every call is a test
(GitHub's IP, D180), and test accounts must never reach qa_log, so this checks the negative live: save, edit and
stats answer 200, stats says logged false, and qa_log gets no repetition/read row (checked with SQL afterwards).
Usage: python -X utf8 scripts/k77-live.py -> reports/qa/data/<time>-k77-live.json
"""
import json, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
ITEMS = [{"question": "Vad är K77-testets fråga?", "short": "Ett påhittat svar.", "long": "Ett påhittat svar. Inget annat."}]
tok = qa.signup()[0]
out, ok = {"started_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}, {}
st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "save", "defer_audio": True, "drill": {"subject": "K77"}, "items": ITEMS}, tok)
s = json.loads(raw); ok["save"] = st == 200
did, iid = s["drill"]["id"], s["items"][0]["id"]
st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "save", "defer_audio": True, "drill": {"id": did}, "items": [dict(ITEMS[0], id=iid, long="Ett påhittat svar. Ändrat.")]}, tok)
ok["edit"] = st == 200
st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "stats", "id": did, "presses": {"1": 3, "2": 2, "3": 1}, "per_question": [{"position": 0, "presses": {"1": 3, "2": 2, "3": 1}}]}, tok)
j = json.loads(raw); out["stats"] = {"status": st, "body": j}
ok["stats_200"] = st == 200
ok["stats_not_logged_for_test"] = j.get("logged") is False
st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "stats", "id": did, "presses": {"1": "x"}}, tok)
ok["stats_bad_400"] = st == 400
qa.call("POST", "/functions/v1/drill", {"action": "delete", "id": did}, tok)
out["checks"] = ok
print(json.dumps(out, ensure_ascii=False, indent=1))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k77-live.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
