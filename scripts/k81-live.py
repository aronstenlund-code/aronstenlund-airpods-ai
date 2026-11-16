"""K81 (Kevin moln, 2026-11-16) live with a test account: fetch-url reads a public page (Swedish Wikipedia), refuses
internal and metadata addresses, and the text goes on to /exam read like a document's text (Claude only, 0 ElevenLabs).
Usage: python -X utf8 scripts/k81-live.py -> reports/qa/data/<time>-k81-live.json
"""
import json, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
tok = qa.signup()[0]
out, ok = {}, {}
def f(url):
    t0 = time.perf_counter()
    st, _, raw = qa.call("POST", "/functions/v1/fetch-url", {"url": url}, tok, timeout=30)
    j = json.loads(raw or b"{}")
    return st, j, round((time.perf_counter() - t0) * 1000)
st, j, ms = f("https://sv.wikipedia.org/wiki/Fotosyntes")
out["wikipedia"] = {"status": st, "ms": ms, "title": j.get("title"), "chars": j.get("chars"), "start": (j.get("text") or "")[:300], "error": j.get("error")}
ok["public_page"] = st == 200 and (j.get("chars") or 0) > 1000 and "otosyntes" in (j.get("text") or "")
for name, url in [("metadata", "http://169.254.169.254/latest/meta-data/"), ("localhost", "http://localhost/"), ("loopback", "http://127.0.0.1/"),
                  ("file", "file:///etc/passwd"), ("port", "http://example.com:22/"), ("own", "https://xjczbzfkmbjdebwlccki.supabase.co/rest/v1/")]:
    s2, j2, _ = f(url)
    out[name] = {"status": s2, "code": (j2.get("error") or {}).get("code"), "reason": j2.get("reason")}
    ok[f"{name}_blocked"] = s2 == 400 and out[name]["code"] == "url_blocked"
if ok["public_page"]:
    s3, _, raw = qa.call("POST", "/functions/v1/exam", {"action": "read", "text": j["text"][:6000], "subject": "Biologi"}, tok, timeout=120)
    r = json.loads(raw or b"{}")
    out["exam_read"] = {"status": s3, "parts": len(r.get("parts") or []), "counts_as": r.get("counts_as")}
    ok["text_to_read_mode"] = s3 == 200 and out["exam_read"]["parts"] > 0
out["checks"] = ok
print(json.dumps(out, ensure_ascii=False, indent=1))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k81-live.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
