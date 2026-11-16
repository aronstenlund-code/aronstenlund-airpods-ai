"""K70 (Kevin moln, 2026-11-15): Läsläget live with a test account (D180: silent audio, 0 ElevenLabs; Claude only).
/exam read on an invented text with page numbers, a running head and a hyphenation break -> /drill save kind text ->
status until done -> sentences and times match; list, share, import of the copy (0 new characters).
Usage: python -X utf8 scripts/k70-live.py
"""
import json, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
TEXT = """Biologi åk 8 – Kapitel 3                                   Sida 12
Fotosyntesen

Växter bildar glukos av koldioxid och vatten med hjälp av ljus. Det sker i klorofyll-
korn, som finns i bladens celler. Syre blir över och släpps ut.

Biologi åk 8 – Kapitel 3                                   Sida 13
Cellandning

Cellandningen är fotosyntesens motsats. Glukos och syre blir koldioxid, vatten och energi. Den sker i alla levande celler, t.ex. i musklerna.
"""
out = {}
tok = qa.signup()[0]
t0 = time.perf_counter()
st, _, raw = qa.call("POST", "/functions/v1/exam", {"action": "read", "text": TEXT, "subject": "Biologi", "grade": "åk 8"}, tok, timeout=120)
out["read_ms"] = round((time.perf_counter() - t0) * 1000)
out["read_status"] = st
r = json.loads(raw)
print("read", st, out["read_ms"], "ms", json.dumps(r, ensure_ascii=False)[:1500])
parts = r["parts"]
out["parts"] = parts
joined = " ".join(p["text"] for p in parts)
out["checks"] = {
    "no_page_numbers": "Sida 1" not in joined,
    "no_running_head": "Kapitel 3" not in joined,
    "hyphen_mended": "klorofyllkorn" in joined,
    "headings": [p["text"] for p in parts if p["kind"] == "heading"],
    "nothing_cut": all(w in joined for w in ["glukos", "musklerna", "Syre blir över", "alla levande celler"]),
}
st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "save", "drill": {"kind": "text", "title": r["title"], "subject": "Biologi"},
                     "items": [{"kind": p["kind"], "text": p["text"]} for p in parts]}, tok)
s = json.loads(raw)
print("save", st, s.get("generated_questions"), s.get("new_chars"), s.get("audio"))
out["save"] = {"status": st, "generated_questions": s.get("generated_questions"), "new_chars": s.get("new_chars"), "counts_as": r["counts_as"]}
did = s["drill"]["id"]
for _ in range(20):
    st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "status", "id": did}, tok)
    s = json.loads(raw)
    if s["audio"]["done"] == s["audio"]["total"]: break
    time.sleep(2)
out["audio"] = s["audio"]
ok = True
for it in s["items"]:
    a = it["audio"]["text"]
    n_ok = a.get("sentences") is not None and len(a["sentences"]) == len(it["sentences"])
    ok = ok and n_ok
    print(it["part"], len(it["sentences"]), a.get("status"), (a.get("sentences") or [])[:3], a.get("duration_ms"))
out["checks"]["sentences_match_times"] = ok
st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "list"}, tok)
out["checks"]["list_kind"] = [d.get("kind") for d in json.loads(raw)["drills"]]
st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "share", "id": did}, tok)
code = json.loads(raw).get("code")
tok2 = qa.signup()[0]
st, _, raw = qa.call("POST", "/functions/v1/drill", {"action": "import", "code": code}, tok2)
c = json.loads(raw)
out["import"] = {"status": st, "kind": c.get("drill", {}).get("kind"), "new_chars": c.get("new_chars"), "items": len(c.get("items", []))}
print(json.dumps(out["checks"], ensure_ascii=False), out["import"])
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k70-live.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
print("->", p)
