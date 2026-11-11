#!/usr/bin/env python3
"""Oscar QA, O38: K38 from the client side. The table real_user_candidates (K22 candidates) must be unreachable for
the public key and for a signed-in (anonymous) app user: no read, insert, update, delete, no purge RPC; and
/functions/v1/real-users-admin must refuse without a token (401) and for an anonymous user (403), GET and POST.
Writes nothing that succeeds (every write is expected to be refused; a probe row would be invented text). 0 USD.
  python -I scripts/qa/o38_k38_live.py   -> reports/qa/data/<stamp>-o38-k38.json"""
import datetime as dt, importlib.util, json, pathlib, sys, urllib.error, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o15", ROOT / "scripts/qa/o15.py")
O = importlib.util.module_from_spec(spec)
spec.loader.exec_module(O)
D = O.D
URL, KEY = D.URL, D.KEY
T = "real_user_candidates"
PROBE = {"id": "real-0000000000", "week": "2026-11-11", "q": "O38 påhittad testrad, ska nekas", "mode": "fragor", "installs": 0, "count": 0}


def call(method, path, tok=None, body=None, extra=None):
    h = {"apikey": KEY, "content-type": "application/json", **(extra or {})}
    if tok:
        h["authorization"] = "Bearer " + tok
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(urllib.request.Request(URL + path, data=data, method=method, headers=h), timeout=30) as r:
            return r.status, r.read().decode()[:300]
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]


def main():
    tok = O.signup()
    rows = []

    def check(name, status, body, ok):
        rows.append({"check": name, "status": status, "body": body, "ok": ok})
        print("OK  " if ok else "FAIL", name, status, body[:120], flush=True)

    refused = lambda s, b: s in (401, 403, 404) or '"42501"' in b or "permission denied" in b
    for who, t in (("public key only", None), ("anonymous user", tok)):
        s, b = call("GET", f"/rest/v1/{T}?select=*", t)
        check(f"REST select ({who})", s, b, refused(s, b))
        s, b = call("GET", f"/rest/v1/{T}?select=count", t, extra={"prefer": "count=exact"})
        check(f"REST count ({who})", s, b, refused(s, b))
        s, b = call("POST", f"/rest/v1/{T}", t, PROBE, {"prefer": "return=minimal"})
        check(f"REST insert ({who})", s, b, refused(s, b))
        s, b = call("PATCH", f"/rest/v1/{T}?id=eq.real-0000000000", t, {"decision": "approved"}, {"prefer": "return=minimal"})
        check(f"REST update ({who})", s, b, refused(s, b))
        s, b = call("DELETE", f"/rest/v1/{T}?id=like.real-*", t)
        check(f"REST delete ({who})", s, b, refused(s, b))
        s, b = call("POST", "/rest/v1/rpc/purge_real_user_candidates", t, {})
        check(f"RPC purge ({who})", s, b, refused(s, b))
        s, b = call("GET", f"/graphql/v1?query=%7B__typename%7D", t)
        rows.append({"check": f"graphql reachable ({who}, info)", "status": s, "body": b[:120], "ok": True})
    gq = '{"query":"{ real_user_candidatesCollection { edges { node { id q } } } }"}'
    s, b = call("POST", "/graphql/v1", tok, json.loads(gq))
    check("GraphQL select (anonymous user)", s, b, refused(s, b) or "errors" in b or '"edges":[]' in b or "null" in b)

    s, b = call("GET", "/functions/v1/real-users-admin", None)
    check("admin GET without user token", s, b, s in (401, 403))
    s, b = call("GET", "/functions/v1/real-users-admin", tok)
    check("admin GET anonymous user", s, b, s == 403)
    s, b = call("POST", "/functions/v1/real-users-admin", tok, {"id": "real-0000000000", "decision": "approved"})
    check("admin POST anonymous user", s, b, s == 403)
    s, b = call("GET", "/functions/v1/qa-log", tok)
    check("qa-log GET anonymous user (shared owner check)", s, b, s == 403)

    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    out = ROOT / "reports/qa/data" / f"{stamp}-o38-k38.json"
    out.write_text(json.dumps({"stamp": stamp, "ok": f"{sum(r['ok'] for r in rows)}/{len(rows)}", "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{sum(r['ok'] for r in rows)}/{len(rows)} ->", out)


if __name__ == "__main__":
    main()
