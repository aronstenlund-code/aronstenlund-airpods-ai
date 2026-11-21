"""K114 (D252, Kevin moln 2026-11-21): metadata only, 0 credits, no audio, nobody listens (D180, Aron's rule).
(1) /voices as the app sees it (names, ids, default); (2) the account's own voices (voice-lab account_voices, service
key; finds "chinese americano" and Marlon); (3) library candidates: native English voices and strong Indian/Chinese
accents, with the library's own metadata. Usage (kevin-live.yml): python -X utf8 scripts/k114-voices.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, os, time, urllib.error, urllib.parse, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")


def get(path, tok):
    r = urllib.request.Request(T.URL + path, headers=T.headers(tok, True))
    try:
        with urllib.request.urlopen(r, timeout=40) as x:
            return json.loads(x.read())
    except urllib.error.HTTPError as e:
        return {"http": e.code}


tok = T.signup()[0]
v = get("/functions/v1/voices", tok)
print("=== /voices default:", v.get("default_id"))
for x in v.get("voices", []):
    print("  env  ", x.get("id"), x.get("name"))
for x in v.get("catalog", []):
    print("  cat  ", x.get("voice_id"), x.get("name"), x.get("language"), x.get("accent"), "review" if x.get("review") else "")

svc = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
if svc:
    r = urllib.request.Request(T.URL + "/functions/v1/voice-lab", data=json.dumps({"action": "account_voices"}).encode(), method="POST",
                               headers={"apikey": T.KEY, "authorization": "Bearer " + svc, "content-type": "application/json"})
    try:
        acc = json.loads(urllib.request.urlopen(r, timeout=40).read())
        print("=== account voices:", len(acc.get("voices", [])))
        for x in acc.get("voices", []):
            if x.get("category") != "premade":
                print("  acct ", x["voice_id"], "|", x["name"], "|", x.get("category"), x.get("language"), x.get("accent"), x.get("gender"), x.get("age"))
    except urllib.error.HTTPError as e:
        print("=== account voices: HTTP", e.code)
else:
    print("=== account voices: no service key")

for q in [{"lang": "en", "gender": "female"}, {"lang": "en", "gender": "male"}, {"lang": "en", "accent": "british"}, {"lang": "en", "accent": "american"},
          {"lang": "any", "accent": "indian"}, {"lang": "any", "accent": "chinese"}, {"lang": "any", "search": "indian accent"}, {"lang": "any", "search": "chinese accent"}]:
    j = get("/functions/v1/voices?library=1&" + urllib.parse.urlencode(q), tok)
    print("=== library", q, len(j.get("library", [])))
    for x in j.get("library", [])[:10]:
        print("  lib  ", x.get("voice_id"), "|", x.get("name"), "|", x.get("gender"), x.get("age"), x.get("accent"), x.get("language"), x.get("verified_languages"), "|", (x.get("description") or "")[:90])
    time.sleep(7)  # 10 library searches a minute
