"""O85 (Oscar moln, 2026-11-18): drill utan gatewayens JWT-kontroll (Kevin 6ff8914e, K100 warm). Kontroll live att koden
nekar allt utan giltig token, också förfalskade token, och att {"action":"warm"} inte visar något.
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o85_drill_auth_live.py. Testkonto, 0 ElevenLabs, 0 Claude."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import base64, hashlib, hmac, json, time, urllib.request  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")


def raw(body, headers):
    r = urllib.request.Request(T.URL + "/functions/v1/drill", data=json.dumps(body).encode() if body is not None else None, method="POST", headers=headers)
    t0 = time.time()
    try:
        with urllib.request.urlopen(r, timeout=60) as x:
            b = x.read()
            return x.status, b[:200].decode(errors="replace"), round((time.time() - t0) * 1000)
    except urllib.error.HTTPError as e:
        return e.code, (e.read() or b"")[:200].decode(errors="replace"), round((time.time() - t0) * 1000)


b64 = lambda d: base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b"=").decode()  # noqa: E731
tok = T.signup(True)[0]
claims = json.loads(base64.urlsafe_b64decode(tok.split(".")[1] + "=="))
sub = claims.get("sub")
# riktigt konto med ett prov
T.call("POST", "/functions/v1/drill", {"action": "save", "defer_audio": True, "drill": {"kind": "text", "title": "O85 (QA)"}, "items": [{"kind": "para", "text": "Hemlig text för O85."}]}, tok)
forged = {**claims, "exp": int(time.time()) + 3600, "app_metadata": {"test": True}, "role": "service_role"}
tokens = {
    "ingen token": None,
    "skräp": "abc.def.ghi",
    "alg none": f"{b64({'alg': 'none', 'typ': 'JWT'})}.{b64(forged)}.",
    "HS256 med fel nyckel": (lambda h, p: f"{h}.{p}.{base64.urlsafe_b64encode(hmac.new(b'fel', f'{h}.{p}'.encode(), hashlib.sha256).digest()).rstrip(b'=').decode()}")(b64({"alg": "HS256", "typ": "JWT"}), b64(forged)),
    "riktig token, ändrad payload": f"{tok.split('.')[0]}.{b64(forged)}.{tok.split('.')[2]}",
    "publika nyckeln som token": T.KEY,
}
res, ok = {}, True
for name, t in tokens.items():
    for action in ("list", "quota", "save", "warm_med_token"):
        h = {"content-type": "application/json", "apikey": T.KEY, "x-earmind-test": "oscar-qa"}
        if t:
            h["authorization"] = f"Bearer {t}"
        body = {"action": action} if action != "save" else {"action": "save", "drill": {"kind": "text", "title": "O85 intrång"}, "items": [{"kind": "para", "text": "x"}]}
        if action == "warm_med_token":
            if not t:
                continue
            body = {"action": "warm"}
        st, txt, _ = raw(body, h)
        res[f"{name} / {action}"] = [st, txt[:80]]
        if st != 401:
            ok = False
# warm utan token: 204 utan innehåll, och det läcker inget
w = [raw({"action": "warm"}, {"content-type": "application/json"}) for _ in range(3)]
w_ok = all(s == 204 and b == "" for s, b, _ in w)
# riktig token fungerar och ser bara sitt eget
s_ok, txt, _ = raw({"action": "list"}, {"content-type": "application/json", "apikey": T.KEY, "authorization": f"Bearer {tok}", "x-earmind-test": "oscar-qa"})
drills = "-"
print("ok   " if ok else "FEL  ", "O85 1: allt utan giltig token ger 401 (ingen token, skräp, alg none, fel nyckel, ändrad payload, publika nyckeln)", flush=True)
print("     " + json.dumps(res, ensure_ascii=False)[:2500], flush=True)
print("ok   " if w_ok else "FEL  ", "O85 2: warm utan token ger 204 utan innehåll", json.dumps([[s, b, ms] for s, b, ms in w]), flush=True)
print("ok   " if s_ok == 200 else "FEL  ", "O85 3: riktig token fungerar som förut", s_ok, drills, flush=True)
for d in json.loads(T.call("POST", "/functions/v1/drill", {"action": "list"}, tok)[2] or b"{}").get("drills") or []:
    T.call("POST", "/functions/v1/drill", {"action": "delete", "id": d["id"]}, tok)
print(f"\n=== O85 {'3/3' if ok and w_ok and s_ok == 200 else 'FEL'}")
sys.exit(0 if ok and w_ok and s_ok == 200 else 1)
