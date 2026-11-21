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
PICKS = {"ljvo28cz3g2pJ1roaSVU": ("en", "Niki"), "6pePhCBvwi0Dte0AkHf3": ("en", "Chris"), "lB9K9mKVhRzwTiRZXQ3b": ("en", "Paul"),
         "qIamWLq3y7Ucaa02ln95": ("en", "Alyssa Laine"), "AuzRHzXe606dpYMHSHYp": ("any", "Ajay"), "Qc0X0JnOfc5XzetLVusF": ("any", "Oolong")}
if "catalog" in _s.argv[1:]:
    # the whole voice_catalog as the database has it (review and disabled rows too); a read with the service key
    svc = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    r = urllib.request.Request(T.URL + "/rest/v1/voice_catalog?select=voice_id,name,language,accent,review,enabled,sort&order=sort.asc",
                               headers={"apikey": svc, "authorization": "Bearer " + svc})
    rows = json.loads(urllib.request.urlopen(r, timeout=30).read())
    for x in rows:
        print("  row  ", x["voice_id"], x["name"], x.get("language"), x.get("accent"), "review" if x.get("review") else "-", "on" if x.get("enabled") else "OFF", x.get("sort"))
    by = {x["voice_id"]: x for x in rows}
    want = {"8XcXJz3rvAjZSQNgtWCy": ("PS3 character", False, True), "ljvo28cz3g2pJ1roaSVU": ("Niki", False, True), "6pePhCBvwi0Dte0AkHf3": ("Chris", False, True),
            "lB9K9mKVhRzwTiRZXQ3b": ("Paul", False, True), "qIamWLq3y7Ucaa02ln95": ("Alyssa", False, True), "AuzRHzXe606dpYMHSHYp": ("Ajay", True, True),
            "Qc0X0JnOfc5XzetLVusF": ("Wei", True, True), "9IAi5SvX5bAamiDIdLdI": (None, None, False), "PyMZFI2sitc2HbXqPlKW": (None, None, False)}
    bad = []
    for vid, (name, review, on) in want.items():
        x = by.get(vid)
        if not x or (name and x["name"] != name) or (review is not None and bool(x["review"]) != review) or bool(x["enabled"]) != on:
            bad.append(vid)
    m = by.get("L5eqCY1Zc0lkxB6M9pRQ")
    if m and m.get("enabled"):
        bad.append("Marlon on")
    v = get("/functions/v1/voices", tok)
    if "L5eqCY1Zc0lkxB6M9pRQ" in json.dumps(v):
        bad.append("Marlon in /voices")
    print("=== catalog K114:", "OK" if not bad else f"FEL {bad}", "| Marlon row:", "none" if not m else ("on" if m.get("enabled") else "off"),
          "| /voices catalog names:", [x["name"] for x in v.get("catalog", [])])
    _s.exit(0 if not bad else 1)
if "picks" in _s.argv[1:]:
    # the chosen voices' library metadata and preview_url (a sample ElevenLabs hosts; fetching it is not generation)
    for vid, (lang, name) in PICKS.items():
        j = get("/functions/v1/voices?library=1&" + urllib.parse.urlencode({"lang": lang, "search": name}), tok)
        hit = next((x for x in j.get("library", []) if x.get("voice_id") == vid), None)
        print("=== pick", vid, name, json.dumps(hit, ensure_ascii=False) if hit else "NOT FOUND")
        time.sleep(7)
    _s.exit(0)
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
