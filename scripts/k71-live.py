"""K71 (Kevin moln, 2026-11-15): audio at Starta prov (D190) live with a test account (silent audio, 0 ElevenLabs).
save defer_audio -> no files, nothing counted; edit -> still free; start -> all files, counted; edit after start ->
only that question; a second drill shared without start -> audio made, then the code.
Usage: python -X utf8 scripts/k71-live.py -> reports/qa/data/<time>-k71-live.json
"""
import json, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
tag = str(int(time.time()))  # fresh texts, so no earlier run's files are reused
ITEMS = [{"question": f"Varför behövs klorofyll {tag}?", "short": "Klorofyll fångar ljusenergi.", "long": "Klorofyll fångar ljusenergi. Utan den bildas inget socker."},
         {"question": f"Hur bildas en näringsväv {tag}?", "short": "Kedjor hakar i varandra.", "long": "Kedjor hakar i varandra. Djur äter flera sorters föda."}]
tok = qa.signup()[0]
def drill(body):
    st, _, raw = qa.call("POST", "/functions/v1/drill", body, tok)
    return st, json.loads(raw)
out, ok = {}, {}
st, s = drill({"action": "save", "defer_audio": True, "drill": {"title": "K71"}, "items": ITEMS})
out["save"] = {"status": st, "audio_started": s["drill"].get("audio_started"), "generated": s.get("generated_questions"), "chars_on_start": s.get("chars_on_start"), "audio": s["audio"]}
ok["save_no_audio"] = st == 200 and s["drill"].get("audio_started") is False and s["audio"]["done"] == 0 and s.get("generated_questions") == 0
did, ids = s["drill"]["id"], [i["id"] for i in s["items"]]
ITEMS[0]["long"] = "Klorofyll fångar ljusenergi. Den gör bladen gröna."
st, s = drill({"action": "save", "defer_audio": True, "drill": {"id": did}, "items": [dict(x, id=i) for x, i in zip(ITEMS, ids)]})
ok["edit_free"] = st == 200 and s.get("generated_questions") == 0 and s["audio"]["done"] == 0
st, s = drill({"action": "start", "id": did})
out["start"] = {"status": st, "generated": s.get("generated_questions"), "new_chars": s.get("new_chars")}
for _ in range(20):
    st2, s = drill({"action": "status", "id": did})
    if s["audio"]["done"] == s["audio"]["total"]: break
    time.sleep(2)
out["after_start"] = s["audio"]
ok["start_all"] = out["start"]["generated"] == 2 and s["audio"]["done"] == s["audio"]["total"] == 4 and s["drill"].get("audio_started") is True
ITEMS[1]["long"] = "Kedjor hakar i varandra. Ny mening här."
st, s = drill({"action": "save", "defer_audio": True, "drill": {"id": did}, "items": [dict(x, id=i) for x, i in zip(ITEMS, ids)]})
out["edit_after_start"] = {"status": st, "generated": s.get("generated_questions"), "new_chars": s.get("new_chars")}
ok["edit_after_start_one"] = st == 200 and s.get("generated_questions") == 1
st, s2 = drill({"action": "save", "defer_audio": True, "drill": {"title": "K71 dela"}, "items": [{"question": f"Vad är fotosyntes {tag}?", "short": "Växter gör socker av ljus.", "long": "Växter gör socker av ljus."}]})
code = None
for _ in range(15):
    st, r = drill({"action": "share", "id": s2["drill"]["id"]})
    if st == 200: code = r.get("code"); break
    time.sleep(2)
out["share_unstarted"] = {"status": st, "code": bool(code)}
ok["share_makes_audio"] = bool(code)
out["checks"] = ok
print(json.dumps(out, ensure_ascii=False, indent=1))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k71-live.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
