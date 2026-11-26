"""O100 (Kevin moln 2026-11-26): live after the security fixes, no model call, 0 ElevenLabs. From GitHub Actions every
call is CI test traffic, so the refusals themselves (S1 anonymous/ordinary accounts, S2 forged tokens) are verified in
tests; here: (1) the eval path still gets past S1's check from Actions (an unknown action is 400, not 403);
(2) /purchase stops an oversized body with 413 (S5); (3) GET /purchase still answers (K119).
Usage (kevin-live.yml): python -X utf8 scripts/o100-live.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, urllib.error, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
res = {}


def call(method, fn, body=None, tok=None, raw=None):
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=data, method=method, headers=T.headers(tok, True))
    try:
        with urllib.request.urlopen(r, timeout=60) as x:
            return x.status, x.read()[:300].decode(errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:300].decode(errors="replace")


def ok(name, cond, info):
    res[name] = bool(cond)
    print(("PASS " if cond else "FAIL ") + name, json.dumps(info, ensure_ascii=False)[:300], flush=True)


tok = T.signup()[0]
st, body = call("POST", "provlage-eval", {"action": "nope"}, tok)
ok("S1: the eval path from Actions passes the access check (400 for an unknown action, not 403)", st == 400, {"status": st, "body": body})
st, body = call("POST", "purchase", raw=b'{"action":"verify","jws":"' + b"a" * 70_000 + b'"}', tok=tok)
ok("S5: /purchase stops a body over 64 KB with 413", st == 413, {"status": st, "body": body[:120]})
st, body = call("GET", "purchase")
ok("K119: GET /purchase still answers", st == 200 and "launch_offer" in body, {"status": st, "body": body[:120]})
n = sum(res.values())
print(f"=== O100: {n} av {len(res)}")
_s.exit(0 if n == len(res) else 1)
