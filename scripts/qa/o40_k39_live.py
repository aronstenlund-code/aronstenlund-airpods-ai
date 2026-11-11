#!/usr/bin/env python3
"""Oscar QA, O40: K39 logo vote from the client side, WITHOUT casting a valid vote (a test vote would count in Aron's
real poll). Checks: no token 401; an anonymous user's GET is its own vote only (null for a new user); invalid
choices 400 and nothing stored; the owner view 403; the table and both RPCs unreachable with the public key and as a
signed-in user (otherwise anyone could vote for any user id or read everyone's votes). 0 USD.
  python -I scripts/qa/o40_k39_live.py   -> reports/qa/data/<stamp>-o40-k39.json"""
import datetime as dt, importlib.util, json, pathlib, sys, urllib.error, urllib.request, uuid

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o38", ROOT / "scripts/qa/o38_k38_live.py")
L = importlib.util.module_from_spec(spec)
spec.loader.exec_module(L)
call, O = L.call, L.O


def main():
    tok = O.signup()
    rows = []

    def check(name, status, body, ok):
        rows.append({"check": name, "status": status, "body": body, "ok": bool(ok)})
        print("OK  " if ok else "FAIL", name, status, body[:110], flush=True)

    refused = lambda s, b: s in (401, 403, 404) or '"42501"' in b or "permission denied" in b
    s, b = call("GET", "/functions/v1/logo-vote", None)
    check("GET without user token", s, b, s == 401)
    s, b = call("POST", "/functions/v1/logo-vote", None, {"choice": "A"})
    check("POST without user token", s, b, s == 401)
    s, b = call("GET", "/functions/v1/logo-vote", tok)
    check("GET new anonymous user: own vote null, no results", s, b, s == 200 and json.loads(b).get("choice") is None and "results" not in json.loads(b))
    for bad in ("D", "", "AB", "A;drop", 1, None, ["A"], "Ä"):
        s, b = call("POST", "/functions/v1/logo-vote", tok, {"choice": bad})
        check(f"POST invalid choice {bad!r}", s, b, s == 400)
    s, b = call("POST", "/functions/v1/logo-vote", tok, {"choice": "B", "pad": "x" * 2000})
    check("POST body over 1 KB refused (no vote)", s, b, s in (400, 413))
    s, b = call("GET", "/functions/v1/logo-vote", tok)
    check("after invalid posts: still no vote", s, b, s == 200 and json.loads(b).get("choice") is None)
    s, b = call("GET", "/functions/v1/logo-vote?view=owner", tok)
    check("owner view as anonymous user", s, b, s == 403)
    for who, t in (("public key only", None), ("anonymous user", tok)):
        s, b = call("GET", "/rest/v1/logo_votes?select=*", t)
        check(f"REST select logo_votes ({who})", s, b, refused(s, b))
        s, b = call("POST", "/rest/v1/logo_votes", t, {"user_id": str(uuid.uuid4()), "choice": "A"}, {"prefer": "return=minimal"})
        check(f"REST insert logo_votes ({who})", s, b, refused(s, b))
        s, b = call("POST", "/rest/v1/rpc/cast_logo_vote", t, {"p_user": str(uuid.uuid4()), "p_choice": "A"})
        check(f"RPC cast_logo_vote for another id ({who})", s, b, refused(s, b))
        s, b = call("POST", "/rest/v1/rpc/logo_vote_counts", t, {})
        check(f"RPC logo_vote_counts ({who})", s, b, refused(s, b))
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    out = ROOT / "reports/qa/data" / f"{stamp}-o40-k39.json"
    out.write_text(json.dumps({"stamp": stamp, "ok": f"{sum(r['ok'] for r in rows)}/{len(rows)}", "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{sum(r['ok'] for r in rows)}/{len(rows)} ->", out)


if __name__ == "__main__":
    main()
