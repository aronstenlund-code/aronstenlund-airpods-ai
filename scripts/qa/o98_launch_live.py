"""O98 (D259, K119, K120; Oscar moln 2026-11-26): lanseringsveckan och compress live. Testkonton, 0 ElevenLabs, inga
riktiga köp, inga modellanrop som kostar (krediterna är slut, D258: compress ska få 503 provider_quota).
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o98_launch_live.py
1. GET /purchase utan inloggning och utan nyckel (och med sajtens Origin): 200, launch_offer null, cache 60 s.
2. Köpverifieringen live: falsk kedja (Kevins testrot, o78/fixtures.json) och skräp nekas 422; kontot får inget.
   Lanseringsfönstret ligger efter Apples signatur och kan bara provas i test (scripts/qa/o98_launch_test.ts).
3. /exam compress på sv och en: 503 provider_quota, användartext på valt språk, inga krediter dras."""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE))
import qa_testaccount as T  # noqa: E402
T.install()
import http.client, json, urllib.error, urllib.request  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
OK = []
WEB = "https://earmind.vercel.app"
FIX = json.loads((HERE / "o78" / "fixtures.json").read_text())


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:1500], flush=True)


def bare_get(path, headers):
    c = http.client.HTTPSConnection(T.URL.replace("https://", ""), timeout=30)
    c.request("GET", path, headers=headers)
    r = c.getresponse()
    return r.status, {k.lower(): v for k, v in r.getheaders()}, json.loads(r.read() or b"{}")


def post(fn, body, tok, extra=None):
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=json.dumps(body).encode(), method="POST", headers=T.headers(tok, True, extra))
    try:
        with urllib.request.urlopen(r, timeout=120) as x:
            return x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read() or b"{}"
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw[:200].decode(errors="replace")}


# 1
s, h, j = bare_get("/functions/v1/purchase", {"user-agent": "oscar-qa-o98"})
check("1a: GET /purchase utan inloggning och utan nyckel ger 200 och launch_offer null (ingen vecka startad)",
      s == 200 and "launch_offer" in j and j["launch_offer"] is None and "max-age=60" in h.get("cache-control", ""),
      {"status": s, "svar": j, "cache-control": h.get("cache-control")})
s, h, j = bare_get("/functions/v1/purchase", {"user-agent": "oscar-qa-o98", "origin": WEB})
check("1b: samma från sajten (Origin earmind.vercel.app), CORS speglar sajten",
      s == 200 and j.get("launch_offer", 0) is None and h.get("access-control-allow-origin") in (WEB, "*"),
      {"status": s, "svar": j, "acao": h.get("access-control-allow-origin")})

# 2
tok = T.signup(True)[0]
_, q0 = post("drill", {"action": "quota"}, tok)
res = {k: post("purchase", {"action": "verify", "jws": v}, tok) for k, v in
       (("falsk kedja", FIX["fake_chain_jws"]), ("falsk kedja, fel signatur", FIX["fake_chain_bad_sig"]), ("skräp", "a.b.c"))}
_, q1 = post("drill", {"action": "quota"}, tok)
check("2: köpverifieringen nekar falska köp som förut (422 purchase_invalid), kontot får inga krediter",
      all(r[0] == 422 and (r[1].get("error") or {}).get("code") == "purchase_invalid" for r in res.values())
      and q0.get("limit") == q1.get("limit") and q0.get("remaining") == q1.get("remaining"),
      {"svar": {k: [v[0], (v[1].get("error") or {}).get("code"), v[1].get("reason")] for k, v in res.items()},
       "före": {k: q0.get(k) for k in ("limit", "used", "remaining")}, "efter": {k: q1.get(k) for k in ("limit", "used", "remaining")}})

# 3
TXT = {"sv": "Fotosyntesen är den process där växter tar upp ljus. Med hjälp av ljuset, vatten och koldioxid bildar växten "
             "glukos och syre. Glukosen används som energi och byggmaterial, och syret släpps ut i luften genom klyvöppningarna.",
       "en": "Photosynthesis is the process in which plants take in light. With the light, water and carbon dioxide the plant "
             "makes glucose and oxygen. The glucose is used for energy and building material, and the oxygen leaves through the stomata."}
WANT = {"sv": "EarMind är nere en stund", "en": "EarMind is down for a moment"}
tok = T.signup(True)[0]
_, q0 = post("drill", {"action": "quota"}, tok)
rows = {}
for lang in ("sv", "en"):
    s, j = post("exam", {"action": "compress", "text": TXT[lang], "lang": lang}, tok, {"x-earmind-lang": lang})
    e = j.get("error") or {}
    rows[lang] = {"status": s, "kod": e.get("code"), "text": e.get("message"), "ok": s == 503 and e.get("code") == "provider_quota" and WANT[lang] in (e.get("message") or "")}
_, q1 = post("drill", {"action": "quota"}, tok)
deployed = not any(r["status"] == 400 for r in rows.values())
check("3: /exam compress svarar 503 provider_quota med användartext på sv och en, och inga krediter dras"
      + ("" if deployed else " (K120 inte driftsatt: 400)"),
      deployed and all(r["ok"] for r in rows.values()) and q0.get("used") == q1.get("used") and q0.get("remaining") == q1.get("remaining"),
      {"svar": rows, "före": {k: q0.get(k) for k in ("used", "remaining")}, "efter": {k: q1.get(k) for k in ("used", "remaining")}})

print(f"\n=== O98 {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
