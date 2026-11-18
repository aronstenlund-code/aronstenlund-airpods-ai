"""K100 (Kevin moln, 2026-11-18): /drill without the gateway's JWT check. {"action":"warm"} without a token = 204;
every other action without a token = 401, with a bad token = 401; a test account's quota still works.
Usage: python -X utf8 scripts/k100-warm.py -> reports/qa/data/<time>-k100-warm.json"""
import json, os, sys, time, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()

def post(body, headers):
    req = urllib.request.Request(qa.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST", headers={"content-type": "application/json", **headers})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=60) as r: return r.status, round((time.time() - t0) * 1000)
    except urllib.error.HTTPError as e: return e.code, round((time.time() - t0) * 1000)

out = {}
out["warm"] = [post({"action": "warm"}, {}) for _ in range(3)]
out["list_no_token"] = post({"action": "list"}, {})
out["list_bad_token"] = post({"action": "list"}, {"authorization": "Bearer abc.def.ghi"})
tok = qa.signup()[0]
h = qa.headers(tok); h["X-earmind-test"] = "kevin-warm"
out["quota_test_account"] = post({"action": "quota"}, h)
ok = {"warm_204": all(s == 204 for s, _ in out["warm"]), "no_token_401": out["list_no_token"][0] == 401,
      "bad_token_401": out["list_bad_token"][0] == 401, "account_200": out["quota_test_account"][0] == 200}
out["checks"] = ok
print(json.dumps(out, indent=1))
json.dump(out, open(os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k100-warm.json"), "w"), indent=1)
sys.exit(0 if all(ok.values()) else 1)
