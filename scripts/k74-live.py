"""K74 (Kevin moln, 2026-11-15) live with a test account (silent audio, D180): a new drill gets voice rules 2
(brackets, quotes, slashes, abbreviations and long sentences in the voice text, the display text unchanged), and
eleven_v4 cannot be chosen (409). The voice texts are read afterwards with SQL by the drill id printed here.
Usage: python -X utf8 scripts/k74-live.py -> reports/qa/data/<time>-k74-live.json
"""
import json, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
tag = str(int(time.time()))
ITEMS = [
    {"question": f"Vad gör klorofyll (i bladen) {tag}?", "short": "Det fångar ljus, t.ex. solljus.", "long": "Det fångar ljus, t.ex. solljus. Läs kap. 3 och/eller s. 12 om \"fotosyntes\" fr.o.m. måndag."},
    {"question": f"Varför är småpartier utsatta {tag}?", "short": "Rösten kan kännas bortkastad.",
     "long": "Rösten kan kännas bortkastad. Många väljare kan bli tveksamma till att rösta på ett litet parti, eftersom de är rädda att rösten går förlorad, och det kan göra det ännu svårare för partiet att komma in i riksdagen nästa gång."},
]
tok = qa.signup()[0]
out, ok = {}, {}
st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "save", "drill": {"title": "K74", "subject": "Biologi"}, "items": ITEMS}, tok)
s = json.loads(raw)
out["save"] = {"status": st, "drill_id": s["drill"]["id"], "audio": s.get("audio")}
ok["save"] = st == 200
ok["display_unchanged"] = [i["long"] for i in s["items"]] == [x["long"] for x in ITEMS]
st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "save", "drill": {"title": "K74 v4", "voice_model": "eleven_v4"}, "items": ITEMS[:1]}, tok)
out["v4"] = {"status": st, "body": json.loads(raw)}
ok["v4_refused"] = st == 409
out["checks"] = ok
print(json.dumps(out, ensure_ascii=False, indent=1))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k74-live.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
