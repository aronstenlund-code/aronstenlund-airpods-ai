"""O100 retest fixes (Kevin moln 2026-11-26), live from Actions, no model call, 0 ElevenLabs.
S1b: the server no longer reads the client's cf-connecting-ip: a CI test call that sends cf-connecting-ip 203.0.113.7
     (outside GitHub) is still CI test traffic (/provlage-eval answers 400 for an unknown action, not 403).
S5b: /purchase answers a 192 KB chunked body without content-length and without a token within 10 s (413).
Usage (kevin-live.yml): python -X utf8 scripts/o100b-live.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import http.client, json, time, urllib.error, urllib.parse, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
res = {}


def ok(name, cond, info):
    res[name] = bool(cond)
    print(("PASS " if cond else "FAIL ") + name, json.dumps(info, ensure_ascii=False)[:300], flush=True)


tok = T.signup()[0]
r = urllib.request.Request(T.URL + "/functions/v1/provlage-eval", data=b'{"action":"nope"}', method="POST",
                           headers=T.headers(tok, True, {"x-real-ip": "203.0.113.7"}))
try:
    with urllib.request.urlopen(r, timeout=60) as x:
        st, body = x.status, x.read()[:200].decode()
except urllib.error.HTTPError as e:
    st, body = e.code, e.read()[:200].decode()
ok("S1b: a client's x-real-ip is ignored (CI test call still 400, not 403)", st == 400, {"status": st, "body": body})
# a client's own cf-connecting-ip never reaches a function: Cloudflare answers 403 "error code: 1000" itself (run 100)
r = urllib.request.Request(T.URL + "/functions/v1/provlage-eval", data=b'{"action":"nope"}', method="POST", headers=T.headers(tok, True, {"cf-connecting-ip": "203.0.113.7"}))
try:
    with urllib.request.urlopen(r, timeout=60) as x:
        st, body = x.status, x.read()[:200].decode()
except urllib.error.HTTPError as e:
    st, body = e.code, e.read()[:200].decode()
ok("S1b: a client's cf-connecting-ip is refused by Cloudflare before any function (error code 1000)", st == 403 and "1000" in body, {"status": st, "body": body})

host = urllib.parse.urlparse(T.URL).hostname
for n in (3,):  # 32 (2 MB) blocks the client's own send once the server has answered and stopped reading
    c = http.client.HTTPSConnection(host, timeout=25)
    t0 = time.time()
    try:
        c.putrequest("POST", "/functions/v1/purchase")
        for k, v in {"apikey": T.KEY, "content-type": "application/json", "user-agent": "python-urllib/kevin-qa"}.items():
            c.putheader(k, v)
        c.putheader("transfer-encoding", "chunked")
        c.endheaders()
        chunk = b"a" * 65536
        try:
            for _ in range(n):
                c.send(b"%x\r\n%s\r\n" % (len(chunk), chunk))
            c.send(b"0\r\n\r\n")
        except OSError:
            pass  # the server may answer and close before the whole body is sent
        x = c.getresponse()
        st, body, sec = x.status, x.read()[:160].decode(errors="replace"), round(time.time() - t0, 1)
    except Exception as e:  # noqa: BLE001
        st, body, sec = -1, f"{type(e).__name__}: {e}"[:120], round(time.time() - t0, 1)
    ok(f"S5b: /purchase answers {n * 64} KB chunked without a token within 10 s (413)", st == 413 and sec < 10, {"status": st, "s": sec, "body": body})
n = sum(res.values())
print(f"=== O100b: {n} av {len(res)}")
_s.exit(0 if n == len(res) else 1)
