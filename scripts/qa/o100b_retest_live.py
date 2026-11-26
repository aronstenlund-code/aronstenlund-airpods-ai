"""O100 omtest (Oscar moln, 2026-11-26): Kevins S1–S5 live (deploy 378). Kör i Actions (oscar-live.yml):
    python -I -X utf8 scripts/qa/o100b_retest_live.py
0 ElevenLabs: /provlage-eval transcribe skickas alltid UTAN ljud, så även om spärren släppte igenom stannar servern på
"audio_base64 saknas" (400) före Scribe. Inga modellanrop, inga riktiga köp. Anrop som ska se ut som en vanlig användare
går genom http.client (qa_testaccount.install() lägger annars testhuvudet på allt).
S1  provlage-eval: CI-testtrafik släpps (400 utan ljud); ett vanligt anrop med en IP utanför GitHub i cf-connecting-ip
    eller x-forwarded-for ger 403 om kanten släpper igenom huvudet (då är också S10 verkligt), annars syns inget nej.
S2  en förfalskad token med konto V:s id + testhuvud mot /drill märker inte V (V:s app_metadata efter förnyad token);
    kontroll: V:s egen token + testhuvud märker V.
S4  fetch-url med http://example.com/ hämtas som https (svarets url).
S5  stora kroppar (chunked, utan content-length) utan token: snabbt 401/413, aldrig tidsgräns."""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE))
import qa_testaccount as T  # noqa: E402
T.install()
import base64, http.client, json, time, urllib.error, urllib.request  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
HOST = T.URL.replace("https://", "")
OK = []


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:1500], flush=True)


def raw(method, path, body=None, headers=None, chunked=False, timeout=25):
    """No test header unless given; returns (status, json|text, seconds)."""
    c = http.client.HTTPSConnection(HOST, timeout=timeout)
    t0 = time.time()
    try:
        if chunked:
            c.putrequest(method, path)
            for k, v in (headers or {}).items():
                c.putheader(k, v)
            c.putheader("transfer-encoding", "chunked")
            c.endheaders()
            chunk = b"a" * 65536
            for _ in range(32):  # 2 MB
                c.send(b"%x\r\n%s\r\n" % (len(chunk), chunk))
            c.send(b"0\r\n\r\n")
        else:
            c.request(method, path, body=json.dumps(body) if body is not None else None, headers=headers or {})
        r = c.getresponse()
        data = r.read()
        try:
            out = json.loads(data or b"{}")
        except ValueError:
            out = data[:200].decode(errors="replace")
        return r.status, out, round(time.time() - t0, 1)
    except Exception as e:  # noqa: BLE001
        return -1, f"{type(e).__name__}: {str(e)[:100]}", round(time.time() - t0, 1)


IPHONE = {"user-agent": T.APP_UA, "apikey": T.KEY, "content-type": "application/json"}


def signup_plain():
    s, j, _ = raw("POST", "/auth/v1/signup", {}, IPHONE)
    return j["access_token"], j["refresh_token"], j["user"]["id"]


def claims(tok):
    p = tok.split(".")[1]
    return json.loads(base64.urlsafe_b64decode(p + "=" * (-len(p) % 4)))


def refreshed_meta(refresh):
    s, j, _ = raw("POST", "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh}, IPHONE)
    return (claims(j["access_token"]).get("app_metadata") or {}) if s == 200 else {"fel": s}, j.get("refresh_token", refresh)


def code(j):
    return (j.get("error") or {}).get("code") if isinstance(j, dict) else None


# ---------- S1 ----------
tok, _, _ = signup_plain()
BODY = {"action": "transcribe"}  # no audio: never reaches Scribe
rows = {}
s, j, _ = raw("POST", "/functions/v1/provlage-eval", BODY, {**IPHONE, "authorization": "Bearer " + tok, "x-earmind-test": "oscar-qa"})
rows["CI + testhuvud"] = [s, code(j)]
for name, h in (("cf-connecting-ip 203.0.113.7", {"cf-connecting-ip": "203.0.113.7"}),
                ("x-forwarded-for 203.0.113.7", {"x-forwarded-for": "203.0.113.7"}),
                ("båda", {"cf-connecting-ip": "203.0.113.7", "x-forwarded-for": "203.0.113.7"})):
    s, j, _ = raw("POST", "/functions/v1/provlage-eval", BODY, {**IPHONE, "authorization": "Bearer " + tok, **h})
    rows["vanligt anrop, " + name] = [s, code(j)]
spoof_works = any(v[0] == 403 for k, v in rows.items() if k.startswith("vanligt"))
check("S1: CI-testtrafik släpps fram (400 utan ljud), aldrig 200; inget anrop når Scribe",
      rows["CI + testhuvud"][0] == 400 and all(v[0] in (400, 403) for v in rows.values()), rows)
print(f"     S1 nej live: {'visat (403) – och då går klientens IP-huvud igenom kanten (S10 verkligt)' if spoof_works else 'kunde inte visas härifrån (kanten skriver över IP-huvudena, S10 inte verkligt för dessa huvuden)'}", flush=True)

# ---------- S2 ----------
vtok, vref, vid = signup_plain()
m0 = claims(vtok).get("app_metadata") or {}
hdr = base64.urlsafe_b64encode(b'{"alg":"HS256","typ":"JWT"}').rstrip(b"=").decode()
pl = base64.urlsafe_b64encode(json.dumps({"sub": vid, "role": "authenticated", "aud": "authenticated", "exp": 4102444800}).encode()).rstrip(b"=").decode()
forged = f"{hdr}.{pl}.{base64.urlsafe_b64encode(b'y' * 32).rstrip(b'=').decode()}"
f = [raw("POST", "/functions/v1/drill", {"action": "quota"}, {**IPHONE, "authorization": "Bearer " + forged, "x-earmind-test": "oscar-qa"})[0] for _ in range(3)]
time.sleep(3)
m1, vref = refreshed_meta(vref)
s, _, _ = raw("POST", "/functions/v1/drill", {"action": "quota"}, {**IPHONE, "authorization": "Bearer " + vtok, "x-earmind-test": "oscar-qa"})
time.sleep(3)
m2, vref = refreshed_meta(vref)
check("S2: förfalskad token med V:s id märker inte V; V:s egen token gör det (kontroll)",
      m1.get("test") is not True and m2.get("test") is True,
      {"V före": m0.get("test"), "förfalskad (status ×3)": f, "V efter förfalskad": m1.get("test"), "V:s egen token": s, "V efter egen": m2.get("test")})

# ---------- S4 ----------
ftok = T.signup(True)[0]
r = urllib.request.Request(T.URL + "/functions/v1/fetch-url", data=json.dumps({"url": "http://example.com/"}).encode(), method="POST", headers=T.headers(ftok, True))
try:
    with urllib.request.urlopen(r, timeout=30) as x:
        s, j = x.status, json.loads(x.read())
except urllib.error.HTTPError as e:
    s, j = e.code, json.loads(e.read() or b"{}")
check("S4: http://example.com/ hämtas som https", s == 200 and str(j.get("url", "")).startswith("https://"),
      {"status": s, "url": j.get("url"), "titel": j.get("title"), "kod": code(j)})

# ---------- S5 ----------
big = {}
for fn in ("purchase", "voice-lab", "drill", "waitlist", "debug-audio", "feedback-admin", "usage-stats"):
    s, j, sec = raw("POST", "/functions/v1/" + fn, headers={"apikey": T.KEY, "content-type": "application/json", "user-agent": "python-urllib/oscar-qa"}, chunked=True)
    big[fn] = [s, code(j), sec]
check("S5: 2 MB utan content-length och utan token: svar inom 10 s och aldrig 200/500 (purchase, voice-lab, drill och fyra till)",
      all(v[0] not in (-1, 200, 500) and v[2] < 10 for v in big.values()), big)

print(f"\n=== O100 omtest {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
