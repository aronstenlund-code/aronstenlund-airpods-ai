"""K93 (Kevin moln, 2026-11-17) live: a test account (x-earmind-test, test voice, 0 ElevenLabs) that is admin for a
while and then not. Kevin adds/removes the account in credit_admins by hand (service_role) while this runs: the
script prints the user id, waits for quota.unlimited, checks the admin answers, then waits until it is gone again
and checks that the account is counted and refused as usual.
Usage: python -X utf8 scripts/k93-live.py -> reports/qa/data/<time>-k93-live.json
"""
import json, os, sys, time, urllib.request, base64
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
tag = str(int(time.time()))

def call(body, tok):
    req = urllib.request.Request(qa.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST", headers=qa.headers(tok))
    req.add_header("X-earmind-test", "kevin-k93")
    try:
        with urllib.request.urlopen(req, timeout=120) as r: return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e: return e.code, json.loads(e.read() or b"{}")

def uid(tok):
    p = tok.split(".")[1]; p += "=" * (-len(p) % 4)
    return json.loads(base64.urlsafe_b64decode(p))["sub"]

def wait(flag, secs=420):
    end = time.time() + secs
    while time.time() < end:
        st, q = call({"action": "quota"}, tok)
        if bool(q.get("unlimited")) == flag: return q
        time.sleep(10)
    return None

out, ok = {}, {}
tok = qa.signup()[0]
print("K93_USER_ID", uid(tok), flush=True)
# a marker Kevin finds in drills (title), so the right account is made admin (saved as text: nothing counted)
call({"action": "save", "defer_audio": True, "drill": {"kind": "text", "title": f"K93 markör {tag}"}, "items": [{"kind": "para", "text": f"Markör {tag}."}]}, tok)
q = wait(True)
ok["became_admin"] = q is not None
if q:
    out["admin_quota"] = {k: q.get(k) for k in ("unit", "unlimited", "used", "remaining", "limit")}
    big = [{"kind": "para", "text": (f"Admin {tag} läser en lång text om cellen. " * 40)[:1000].strip()}, {"kind": "para", "text": (f"Andra delen {tag}. " * 60)[:1000]}]
    st, c = call({"action": "cost", "drill": {"kind": "text"}, "items": big}, tok)
    out["admin_cost"] = {"status": st, "cost": c.get("cost"), "unlimited": c.get("unlimited"), "enough": c.get("enough")}
    st, s = call({"action": "save", "defer_audio": True, "drill": {"kind": "text", "title": f"K93 admin {tag}"}, "items": big}, tok)
    st2, a = call({"action": "start", "id": s.get("drill", {}).get("id")}, tok) if st == 200 else (st, {})
    st3, q2 = call({"action": "quota"}, tok)
    st4, l = call({"action": "list"}, tok)
    out["admin_play"] = {"save": st, "start": st2, "cost": a.get("cost"), "used_after": q2.get("used"), "list_unlimited": l.get("quota", {}).get("unlimited")}
    ok["admin_no_402_no_charge"] = st == 200 and st2 == 200 and (a.get("cost") or 0) > 1500 and q2.get("used") == 0 and c.get("unlimited") is True and l.get("quota", {}).get("unlimited") is True
    print("K93_ADMIN_DONE", flush=True)
    q3 = wait(False)
    ok["admin_removed"] = q3 is not None
    if q3:
        out["after_quota"] = {k: q3.get(k) for k in ("unlimited", "used", "remaining", "limit")}
        big2 = [{"kind": "para", "text": (f"Efter {tag} en annan lång text om atomer. " * 40)[:1000].strip()}, {"kind": "para", "text": (f"Tredje {tag}. " * 80)[:1000]}]
        st, r = call({"action": "save", "defer_audio": True, "drill": {"kind": "text", "title": f"K93 efter {tag}"}, "items": big2}, tok)
        small = [{"kind": "para", "text": f"Kort text {tag} om ljus."}]
        st5, s5 = call({"action": "save", "drill": {"kind": "text", "title": f"K93 liten {tag}"}, "items": small}, tok)
        st6, q4 = call({"action": "quota"}, tok)
        out["after"] = {"big_status": st, "big_cost": r.get("cost"), "small_cost": s5.get("cost"), "used": q4.get("used"), "unlimited": q4.get("unlimited")}
        ok["after_counted_and_refused"] = st == 402 and q3.get("unlimited") is None and q3.get("limit") == 1500 and q4.get("used") == len(small[0]["text"])
out["checks"] = ok
print(json.dumps(out, ensure_ascii=False, indent=1))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k93-live.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
sys.exit(0 if ok and all(ok.values()) else 1)
