#!/usr/bin/env python3
"""K40 live: Provläge check questions get a hidden answer key (done.quiz_key), and the student's misheard reply is
graded by sound when the key comes back (context.quiz_key, A62). Also /study-profile with a topic of names.
Raw data -> reports/eval/<stamp>-k40-quiz-live.json.   python3 -X utf8 -I scripts/k40-quiz-live.py"""
import datetime, json, pathlib, urllib.request, zoneinfo
U = "https://xjczbzfkmbjdebwlccki.supabase.co"; K = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
PROFILE = "Ämne: Geografi. Årskurs: 8. Prov: 50 mest kända sjöar, floder och kuststäder. Kontrollfrågor: korta."


def post(path, body, tok=None):
    h = {"apikey": K, "content-type": "application/json", **({"authorization": "Bearer " + tok} if tok else {})}
    with urllib.request.urlopen(urllib.request.Request(U + path, data=json.dumps(body).encode(), headers=h), timeout=90) as r:
        return r.read().decode()


def answer(tok, fragment, recent=None, key=None):
    ctx = {"transcript": fragment, "recent_qa": recent or [], "last_answer_age_sec": 6}
    if key: ctx["quiz_key"] = key
    t = post("/functions/v1/answer", {"fragment": fragment, "mode": "tutor", "persona": "tutor", "language": "sv",
                                      "persona_setup": PROFILE, "context": ctx}, tok)
    said, done = "", {}
    for f in t.split("\n\n"):
        if f.startswith("event: delta"): said += json.loads(f.split("data: ", 1)[1]).get("text", "")
        if f.startswith("event: done"): done = json.loads(f.split("data: ", 1)[1])
    return said, done


tok = json.loads(post("/auth/v1/signup", {}))["access_token"]
rows = []
# 1. three check questions: the key comes in done, never in the speech
for i in range(3):
    said, done = answer(tok, "förhör mig")
    rows.append({"step": "quiz", "said": said, "quiz_key": done.get("quiz_key"), "key_spoken": "SVAR" in said or "|" in said})
    print("quiz:", said[:90], "| key:", done.get("quiz_key"), flush=True)
# 2. misheard replies graded with the key
CASES = [
    ("Vilken flod rinner genom Egypten?", {"answer": "Nilen", "alternatives": ["Kongo", "Niger", "Zambezi"]}, "Nilan", "right"),
    ("Vilken flod rinner genom Egypten?", {"answer": "Nilen", "alternatives": ["Kongo", "Niger", "Zambezi"]}, "ni len", "right"),
    ("Vilken flod rinner genom Paris?", {"answer": "Seine", "alternatives": ["Loire", "Rhône", "Garonne"]}, "såg en", "near"),
    ("Vilken flod rinner genom Paris?", {"answer": "Seine", "alternatives": ["Loire", "Rhône", "Garonne"]}, "sän", "right"),
    ("Vilken flod rinner genom Paris?", {"answer": "Seine", "alternatives": ["Loire", "Rhône", "Garonne"]}, "Loire", "wrong"),
    ("Vilken stad ligger vid Rhônes mynning?", {"answer": "Marseille", "alternatives": ["Nice", "Lyon", "Toulon"]}, "mar säj", "right"),
    ("Vilken är Europas största sjö?", {"answer": "Ladoga", "alternatives": ["Onega", "Vänern", "Peipus"]}, "Vänern", "wrong"),
]
for q, key, heard, want in CASES:
    said, done = answer(tok, heard, [{"q": "förhör mig", "a": q}], key)
    low = said.lower()
    got = "near" if low.startswith("menade du") else "right" if low.startswith("rätt") else "wrong" if low.startswith(("inte riktigt", "nästan", "fel")) else "?"
    ok = got == want or (want == "right" and got == "near")
    rows.append({"step": "grade", "q": q, "heard": heard, "want": want, "got": got, "ok": ok, "said": said, "sound": done.get("quiz_sound")})
    print("OK " if ok else "BAD", heard, "->", got, "|", said[:90], flush=True)
# 3. without a key (before A62): Aron's case
said, done = answer(tok, "om ni har redan svarat", [{"q": "förhör mig", "a": "Vilken flod rinner genom Egypten?"}])
rows.append({"step": "nokey", "heard": "om ni har redan svarat", "said": said})
print("no key: om ni har redan svarat ->", said[:110], flush=True)
# 4. /study-profile with a topic of names
p = json.loads(post("/functions/v1/study-profile", {"text": "jag går i åttan och har prov i geografi på fredag om de 50 mest kända sjöarna, floderna och kuststäderna"}, tok))
rows.append({"step": "profile", "profile": p.get("profile"), "terms": p.get("terms")})
print("profile:", p.get("profile"), "| terms:", (p.get("terms") or [])[:15], flush=True)
graded = [r for r in rows if r["step"] == "grade"]
s = {"keys": sum(1 for r in rows if r["step"] == "quiz" and r["quiz_key"]), "keys_spoken": sum(1 for r in rows if r.get("key_spoken")),
     "graded_ok": f"{sum(r['ok'] for r in graded)}/{len(graded)}"}
print(s)
stamp = datetime.datetime.now(zoneinfo.ZoneInfo("Europe/Stockholm")).strftime("%Y-%m-%d-%H%M%S")
out = pathlib.Path(__file__).resolve().parents[1] / "reports" / "eval" / f"{stamp}-k40-quiz-live.json"
out.write_text(json.dumps({"summary": s, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
print(out)
