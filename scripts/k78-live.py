"""K78 (Kevin moln, 2026-11-16) live with test accounts and the FAKE out-of-credits (x-earmind-test: unavailable,
D180: 0 ElevenLabs calls): (1) credits run out during the audio: status gives the questions back and answers
audio_unavailable with the text; (2) known out: the next Starta prov counts nothing and sends nothing.
Usage: python -X utf8 scripts/k78-live.py -> reports/qa/data/<time>-k78-live.json
"""
import json, os, sys, time, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
tag = str(int(time.time()))
ITEMS = [{"question": f"Varför behövs klorofyll {tag}?", "short": "Det fångar ljus.", "long": "Det fångar ljus. Mer."},
         {"question": f"Vad är en näringskedja {tag}?", "short": "Vem som äter vem.", "long": "Vem som äter vem. Mer."}]

def call(body, tok, mode=None):
    req = urllib.request.Request(qa.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST", headers=qa.headers(tok))
    if mode: req.add_header("X-earmind-test", f"oscar-qa {mode}")
    try:
        with urllib.request.urlopen(req, timeout=120) as r: return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e: return e.code, json.loads(e.read() or b"{}")

out, ok = {}, {}
tok = qa.signup()[0]
st, q0 = call({"action": "quota"}, tok); out["quota_before"] = q0.get("used")
st, s = call({"action": "save", "items": ITEMS}, tok, "unavailable")
out["save"] = {"status": st, "generated": s.get("generated_questions"), "audio_unavailable": s.get("audio_unavailable")}
# when another test made a fake failure in the last 10 minutes, the save itself is already held back (path 2)
held = s.get("audio_unavailable") is True
ok["save_held_counts_nothing" if held else "save_counted"] = (s.get("generated_questions") == 0) if held else (s.get("generated_questions") == 2)
time.sleep(2)
st, v = call({"action": "status", "id": s["drill"]["id"]}, tok, "unavailable")
out["status"] = {"status": st, "audio_unavailable": v.get("audio_unavailable"), "notice": v.get("notice"), "refunded": v.get("refunded_questions"), "text": [i.get("question") for i in v.get("items", [])]}
ok["code_and_text"] = v.get("audio_unavailable") is True and v.get("notice", {}).get("code") == "audio_unavailable" and len(out["status"]["text"]) == 2
if not held: ok["given_back"] = v.get("refunded_questions") == out["save"]["generated"]
st, q1 = call({"action": "quota"}, tok); out["quota_after_refund"] = q1.get("used")
ok["quota_unchanged"] = q1.get("used") == q0.get("used")
st, d2 = call({"action": "save", "defer_audio": True, "items": [{"question": f"Vad är is {tag}?", "short": "Fruset vatten.", "long": "Fruset vatten."}]}, tok)
st, s2 = call({"action": "start", "id": d2["drill"]["id"]}, tok)
out["start_known_out"] = {"status": st, "audio_unavailable": s2.get("audio_unavailable"), "generated": s2.get("generated_questions"), "audio_started": s2.get("drill", {}).get("audio_started")}
ok["start_counts_nothing"] = st == 200 and s2.get("audio_unavailable") is True and s2.get("generated_questions") == 0 and s2["drill"].get("audio_started") is False
out["checks"] = ok
print(json.dumps(out, ensure_ascii=False, indent=1))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k78-live.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
