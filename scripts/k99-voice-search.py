"""K99 (Kevin moln): candidates for the voice catalog from ElevenLabs' voice library, through our /voices?library=1
(a listing: no credits, no audio). Test account. Prints id, name, gender, age, accent, language, description, preview."""
import json, os, sys, time, urllib.parse, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
tok = qa.signup()[0]
SEARCHES = [
    {}, {"gender": "male"}, {"gender": "female"}, {"accent": "scanian"}, {"search": "skånsk"}, {"search": "göteborg"},
    {"search": "chinese", "lang": "any"}, {"accent": "chinese", "lang": "any"}, {"search": "indian", "lang": "any"}, {"accent": "indian", "lang": "any"},
    {"search": "old", "lang": "any"}, {"search": "child"},
]
seen = {}
for q in SEARCHES:
    url = qa.URL + "/functions/v1/voices?library=1&" + urllib.parse.urlencode(q)
    req = urllib.request.Request(url, headers=qa.headers(tok))
    try:
        with urllib.request.urlopen(req, timeout=30) as r: j = json.loads(r.read())
    except urllib.error.HTTPError as e:
        print("ERR", q, e.code); time.sleep(7); continue
    print(f"\n=== {q}: {len(j.get('library', []))}")
    for v in j.get("library", [])[:12]:
        if v["voice_id"] in seen: continue
        seen[v["voice_id"]] = v
        print(json.dumps({k: v.get(k) for k in ("voice_id", "name", "gender", "age", "accent", "language", "description", "preview_url")}, ensure_ascii=False))
    time.sleep(7)  # 10 a minute
print("\n=== total", len(seen))
