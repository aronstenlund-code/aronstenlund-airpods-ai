"""O73: fetch-url (K81, D204) live med testkonto (Oscar moln, 2026-11-16). Kör i Actions (oscar-live.yml):
  python -I -X utf8 scripts/qa/o73_fetch_live.py
Hållout mot riktiga sidor: DNS som pekar internt (nip.io, localtest.me), omdirigering till intern adress via en publik
omdirigerare (httpbin.org), för många omdirigeringar, timeout, för stor sida, icke-HTML, och en vanlig sida som kontroll.
0 ElevenLabs, 0 Claude. Högst 10 anrop i minuten per konto, så skriptet väntar mellan anropen."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import json, time, urllib.parse  # noqa: E402

sys = _s
sys.stdout.reconfigure(encoding="utf-8")
R = "https://httpbingo.org/redirect-to?url="  # httpbin.org svarade inte med 3xx i körning 1
CASES = [  # (namn, url, väntad status, väntad kod eller None, väntad reason eller None)
    ("kontroll: vanlig sida", "https://httpbin.org/html", 200, None, None),
    ("DNS: 127.0.0.1.nip.io", "http://127.0.0.1.nip.io/", 400, "url_blocked", "private_address"),
    ("DNS: localtest.me", "http://localtest.me/", 400, "url_blocked", "private_address"),
    ("DNS: 169.254.169.254.nip.io", "http://169.254.169.254.nip.io/latest/meta-data/", 400, "url_blocked", "private_address"),
    ("DNS: 10.0.0.1.sslip.io", "http://10.0.0.1.sslip.io/", 400, "url_blocked", "private_address"),
    ("omdirigering till metadata", R + urllib.parse.quote("http://169.254.169.254/latest/meta-data/", safe=""), 400, "url_blocked", "private_address"),
    ("omdirigering till [::ffff:7f00:1]", R + urllib.parse.quote("http://[::ffff:7f00:1]/", safe=""), 400, "url_blocked", "private_address"),
    ("omdirigering till 127.0.0.1.nip.io", R + urllib.parse.quote("http://127.0.0.1.nip.io/", safe=""), 400, "url_blocked", "private_address"),
    ("omdirigering till file:", R + urllib.parse.quote("file:///etc/passwd", safe=""), 400, "url_blocked", "scheme"),
    ("omdirigering till vår Supabase", R + urllib.parse.quote(T.URL + "/rest/v1/drills", safe=""), 400, "url_blocked", "own_host"),
    ("4 omdirigeringar", "https://httpbin.org/absolute-redirect/4", 422, "url_unreachable", "too_many_redirects"),
    ("timeout (10 s svarstid + DNS)", "https://httpbingo.org/delay/10", 422, "url_unreachable", None),
    ("för stor sida (6 MB text)", "https://norvig.com/big.txt", 413, "url_too_large", None),
    ("icke-HTML: png", "https://httpbin.org/image/png", 415, "url_not_text", None),
    ("icke-HTML: json", "https://httpbin.org/json", 415, "url_not_text", None),
    ("IPv6 6to4 med 127.0.0.1 (O73 3)", "http://[2002:7f00:1::]/", 400, "url_blocked", "private_address"),
    ("IPv6 ::ffff:0:7f00:1 (O73 3)", "http://[::ffff:0:7f00:1]/", 400, "url_blocked", "private_address"),
]
tok = T.signup(True)[0]
ok_n = 0
for i, (name, url, want_st, want_code, want_reason) in enumerate(CASES):
    if i and i % 9 == 0:
        print("  väntar 62 s (10 i minuten)", flush=True)
        time.sleep(62)
    t0 = time.time()
    st, _h, raw = T.call("POST", "/functions/v1/fetch-url", {"url": url}, tok, timeout=60)
    ms = round((time.time() - t0) * 1000)
    j = json.loads(raw or b"{}")
    code, reason = (j.get("error") or {}).get("code"), j.get("reason")
    good = st == want_st and (want_code is None or code == want_code) and (want_reason is None or reason == want_reason)
    if not good and name.startswith("omdirigering") and st == 422 and j.get("status") == 403:
        good, name = True, name + " (omdirigeraren vägrade själv, 403: inget hämtades)"
    if want_st == 200:
        good = good and len(j.get("text") or "") > 100
    ok_n += good
    print(f"{'ok   ' if good else 'FEL  '}{name} | {st} {code} {reason} upstream={j.get('status')} type={j.get('content_type')} {ms} ms" + (f" chars {j.get('chars')} title {j.get('title')!r}" if st == 200 else ""), flush=True)
    time.sleep(1)
print(f"\n=== O73 fetch-url {ok_n}/{len(CASES)} ok")
sys.exit(0 if ok_n == len(CASES) else 1)
