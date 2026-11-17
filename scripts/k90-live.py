"""K90 (Kevin moln, 2026-11-17) live with a test account (D180: the test voice via x-earmind-test, 0 ElevenLabs):
credits are characters of new audio. quota says unit chars and 1500; a text longer than what is left is refused
with 402 (cost, remaining, limit, resets) and not saved; a short text costs its characters at start; the same
text again costs 0.
Usage: python -X utf8 scripts/k90-live.py -> reports/qa/data/<time>-k90-live.json
"""
import json, os, sys, time, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
tag = str(int(time.time()))

def call(body, tok):
    req = urllib.request.Request(qa.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST", headers=qa.headers(tok))
    req.add_header("X-earmind-test", "kevin-k90")
    try:
        with urllib.request.urlopen(req, timeout=120) as r: return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e: return e.code, json.loads(e.read() or b"{}")

out, ok = {}, {}
tok = qa.signup()[0]
st, q0 = call({"action": "quota"}, tok)
out["quota"] = {k: q0.get(k) for k in ("unit", "limit", "used", "remaining", "resets", "resets_day", "left")}
ok["quota_chars_1500"] = st == 200 and q0.get("unit") == "chars" and q0.get("limit") == 1500 and q0.get("remaining") == 1500
body = (f"Mening {tag} om cellen och dess delar. " * 40)[:1000].strip()
big = [{"kind": "para", "text": body}, {"kind": "para", "text": "Andra delen. " + body}]  # 2 000+ characters, over 1 500
st, r = call({"action": "save", "defer_audio": True, "drill": {"kind": "text", "title": f"K90 stor {tag}"}, "items": big}, tok)
st_l, l = call({"action": "list"}, tok)
out["big"] = {"status": st, "cost": r.get("cost"), "remaining": r.get("remaining"), "limit": r.get("limit"), "message": r.get("error", {}).get("message"), "saved": sum(1 for d in l.get("drills", []) if d.get("title") == f"K90 stor {tag}")}
ok["big_402_not_saved"] = st == 402 and r.get("cost") == sum(len(p["text"]) for p in big) and r.get("remaining") == 1500 and out["big"]["saved"] == 0
small = [{"kind": "heading", "text": f"Rubrik {tag}"}, {"kind": "para", "text": f"Klorofyll fångar ljus {tag}. Växten bildar glukos."}]
want = sum(len(p["text"]) for p in small)
st, s = call({"action": "save", "defer_audio": True, "drill": {"kind": "text", "title": f"K90 liten {tag}"}, "items": small}, tok)
out["small_save"] = {"status": st, "cost": s.get("cost"), "audio_cost": s.get("audio", {}).get("cost"), "started": s.get("drill", {}).get("audio_started")}
ok["cost_before_start"] = st == 200 and s.get("cost") == want and s.get("audio", {}).get("cost") == want and s["drill"].get("audio_started") is False
st, a = call({"action": "start", "id": s["drill"]["id"]}, tok)
st2, q1 = call({"action": "quota"}, tok)
out["start"] = {"status": st, "cost": a.get("cost"), "used_after": q1.get("used")}
ok["start_counts_chars"] = st == 200 and a.get("cost") == want and q1.get("used") == want
st, s2 = call({"action": "save", "drill": {"kind": "text", "title": f"K90 igen {tag}"}, "items": small}, tok)
st3, q2 = call({"action": "quota"}, tok)
out["again"] = {"status": st, "cost": s2.get("cost"), "used_after": q2.get("used")}
ok["same_text_free"] = st == 200 and s2.get("cost") == 0 and q2.get("used") == want
out["checks"] = ok
print(json.dumps(out, ensure_ascii=False, indent=1))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k90-live.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
sys.exit(0 if all(ok.values()) else 1)
