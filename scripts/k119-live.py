"""K119 (D259, Kevin moln 2026-11-23): the launch week, live and free (no model, 0 ElevenLabs, no purchase).
GET /purchase without signing in gives {"launch_offer": null} until the agents start the week (or the running week's
starts_at/ends_at/percent/product_suffix), also from the site's origin (CORS). Usage: python -X utf8 scripts/k119-live.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
res = {}
for name, h in (("no auth, no apikey", {}), ("site origin + apikey", {"origin": "https://earmind.vercel.app", "apikey": T.KEY})):
    r = urllib.request.Request(T.URL + "/functions/v1/purchase", method="GET", headers=h)
    with urllib.request.urlopen(r, timeout=30) as x:
        body = json.loads(x.read())
        hdr = {k.lower(): v for k, v in x.headers.items()}
    o = body.get("launch_offer", "missing")
    good = x.status == 200 and (o is None or (isinstance(o, dict) and o.get("percent") == 65 and o.get("product_suffix") == ".launch"))
    if "origin" in h:
        good = good and hdr.get("access-control-allow-origin") == h["origin"]
    res[name] = good
    print(("PASS " if good else "FAIL ") + name, json.dumps({"status": x.status, "body": body, "acao": hdr.get("access-control-allow-origin"), "cache": hdr.get("cache-control")}), flush=True)
n = sum(res.values())
print(f"=== K119: {n} av {len(res)}")
_s.exit(0 if n == len(res) else 1)
