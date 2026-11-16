"""K80 (D202): the waitlist's CORS live. Usage: python -X utf8 scripts/k80-cors.py https://<the-vercel-address>
Sends a preflight (OPTIONS) from that origin and from a foreign one (https://example.com) to /functions/v1/waitlist
and prints Access-Control-Allow-Origin. Nothing is signed up (only OPTIONS). 0 ElevenLabs.
"""
import json, os, sys, time, urllib.request, urllib.error
URL = "https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/waitlist"
HERE = os.path.dirname(os.path.abspath(__file__))
origin = (sys.argv[1] if len(sys.argv) > 1 else "").rstrip("/")
if not origin.startswith("https://"):
    print("give the Vercel address: https://...") ; sys.exit(2)
def pre(o):
    req = urllib.request.Request(URL, method="OPTIONS", headers={"Origin": o, "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "content-type, apikey", "user-agent": "python-urllib/kevin-k80"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r: return r.status, r.headers.get("access-control-allow-origin")
    except urllib.error.HTTPError as e: return e.code, e.headers.get("access-control-allow-origin")
out = {"vercel": pre(origin), "foreign": pre("https://example.com"), "github_pages": pre("https://aronstenlund-code.github.io")}
out["checks"] = {"vercel_allowed": out["vercel"] == (204, origin), "foreign_refused": out["foreign"][0] == 403 and not out["foreign"][1],
                 "github_pages_still_allowed": out["github_pages"][1] == "https://aronstenlund-code.github.io"}
print(json.dumps(out, indent=1))
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k80-cors.json")
json.dump(out, open(p, "w"), indent=1)
