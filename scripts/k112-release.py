"""K112 (Deangelo 2026-11-20, D227): what a reviewer can meet without test mode, live, 0 ElevenLabs and 0 Claude:
the login errors and the welcome without Team ID are Swedish and name nothing internal. Usage (kevin-live.yml)."""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, re, urllib.error, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
INTERNAL = re.compile(r"\b(test|admin|debug|elevenlabs|anthropic|claude|supabase|jwt|bearer|token)\b", re.I)


def call(fn, body, tok=None):
    h = {"apikey": T.KEY, "content-type": "application/json"}
    if tok:
        h["authorization"] = "Bearer " + tok
    try:
        with urllib.request.urlopen(urllib.request.Request(T.URL + "/functions/v1/" + fn, data=json.dumps(body).encode(), headers=h, method="POST"), timeout=60) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


rows, ok = [], True
tok = T.signup()[0]
for name, fn, body, t in [("no login", "drill", {"action": "quota"}, None), ("bad login", "drill", {"action": "quota"}, "not-a-jwt"),
                          ("no login (exam)", "exam", {"action": "drill", "text": "x"}, None),
                          ("welcome challenge", "purchase", {"action": "attest_challenge"}, tok), ("welcome", "purchase", {"action": "welcome"}, tok)]:
    st, j = call(fn, body, t)
    msg = (j.get("error") or {}).get("message") or j.get("message") or ""
    good = bool(re.search(r"[åäö]", msg)) and not INTERNAL.search(msg)
    ok &= good
    rows.append({"case": name, "status": st, "code": (j.get("error") or {}).get("code"), "message": msg, "ok": good})
    print(json.dumps(rows[-1], ensure_ascii=False), flush=True)
print("=== K112 ALL", ok)
_s.exit(0 if ok else 1)
