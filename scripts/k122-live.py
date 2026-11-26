"""K122 round (Kevin moln 2026-11-26): Kelly's Ke88 question, live, no model call, 0 ElevenLabs.
The site (earmind.vercel.app, no login) reads the launch week from GET /functions/v1/purchase: here exactly as the
browser does it - no apikey, no Authorization, only Origin - and the answer must be 200 with the site's origin in
access-control-allow-origin and a launch_offer field (null until Aron sets the dates).
Usage (kevin-live.yml): python -X utf8 scripts/k122-live.py"""
import json, sys, urllib.error, urllib.request
sys.stdout.reconfigure(encoding="utf-8")
URL = "https://xjczbzfkmbjdebwlccki.supabase.co/functions/v1/purchase"
res = {}


def ok(name, cond, info):
    res[name] = bool(cond)
    print(("PASS " if cond else "FAIL ") + name, json.dumps(info, ensure_ascii=False)[:300], flush=True)


for origin in ("https://earmind.vercel.app", "https://evil.example"):
    r = urllib.request.Request(URL, method="GET", headers={"origin": origin, "user-agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(r, timeout=30) as x:
            st, h, body = x.status, {k.lower(): v for k, v in x.headers.items()}, x.read().decode()
    except urllib.error.HTTPError as e:
        st, h, body = e.code, {k.lower(): v for k, v in e.headers.items()}, e.read().decode()
    acao = h.get("access-control-allow-origin")
    try:
        j = json.loads(body)
    except ValueError:
        j = {}
    if origin.endswith("vercel.app"):
        ok("GET /purchase without a key, from the site: 200, the site's origin allowed, launch_offer present",
           st == 200 and acao == origin and "launch_offer" in j, {"status": st, "acao": acao, "body": body[:160]})
    else:
        ok("another origin is not allowed (no access-control-allow-origin)", acao in (None, ""), {"status": st, "acao": acao})
n = sum(res.values())
print(f"=== K122 live: {n} av {len(res)}")
sys.exit(0 if n == len(res) else 1)
