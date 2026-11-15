"""K72/K73 (Kevin moln, 2026-11-15) live with a test account (silent audio, D180): an English text with the subject
Historia is read in English, "osv." ends a sentence, /exam read has usage; import_text reads emoji numbering and
single italics. Usage: python -X utf8 scripts/k72-live.py -> reports/qa/data/<time>-k72-live.json
"""
import json, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
tag = str(int(time.time()))
EN = f"The Industrial Revolution {tag}\n\nIn 1769 James Watt improved the steam engine, and it was used in the mills of the north. About 1.2 million people moved to the towns in the years that followed.\n\nKroppen behöver kol, kväve osv. Nästa stycke handlar om energi."
tok = qa.signup()[0]
out, ok = {}, {}
st, _, raw = qa.call("POST", "/functions/v1/exam", {"action": "read", "text": EN, "subject": "Historia"}, tok, timeout=120)
r = json.loads(raw)
out["read"] = {"status": st, "language": r.get("language"), "usage": r.get("usage"), "parts": r.get("parts")}
ok["read_language_en"] = r.get("language") == "English"
ok["read_usage"] = isinstance(r.get("usage"), dict) and (r["usage"].get("input_tokens") or 0) > 0
st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "save", "drill": {"kind": "text", "subject": "Historia", "language": r.get("language")}, "items": [{"kind": p["kind"], "text": p["text"]} for p in r["parts"]]}, tok)
s = json.loads(raw)
out["save"] = {"status": st, "language": s["drill"].get("language"), "drill_id": s["drill"]["id"], "sentences": [i.get("sentences") for i in s["items"]]}
ok["save_language_en"] = s["drill"].get("language") == "English"
osv = [i for i in s["items"] if "osv" in (i.get("text") or "") or "och så vidare" in (i.get("text") or "")]
ok["osv_two_sentences"] = bool(osv) and len(osv[0]["sentences"]) == 2
TXT = "1️⃣ Fråga: Vad är magma?\nSvar: Magma är *smält berg* under jorden. Det finns på _Hawaii_.\n\n🔟 Fråga: Vad är lava?\nSvar: Lava är magma ovan jord."
st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "import_text", "text": TXT}, tok)
im = json.loads(raw)
out["import"] = {"status": st, "items": im.get("items")}
ok["emoji_numbering"] = [i["question"] for i in im.get("items", [])] == ["Vad är magma?", "Vad är lava?"]
ok["italics"] = "*" not in im["items"][0]["long"] and "_" not in im["items"][0]["long"]
out["checks"] = ok
print(json.dumps(out, ensure_ascii=False, indent=1))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k72-live.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
