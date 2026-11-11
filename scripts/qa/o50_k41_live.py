#!/usr/bin/env python3
"""Oscar QA, O50: K41 logo vote with six choices A-F. ONE anonymous test user votes A, then changes to B, C, D, E, F
(one vote per user, so only one test vote remains; its user id is printed for removal), checks GET returns the own
vote after each change, and that invalid choices (G, "", "a b", "AB", 7) are refused without changing the vote.
Old votes are counted before/after separately (Supabase MCP, read only). 0 USD, 0 ElevenLabs.
  python -I scripts/qa/o50_k41_live.py -> reports/qa/data/<stamp>-o50-k41.json"""
import base64, datetime as dt, importlib.util, json, pathlib, sys, time
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o38", ROOT / "scripts/qa/o38_k38_live.py"); L = importlib.util.module_from_spec(spec); spec.loader.exec_module(L)
call, O = L.call, L.O


def main():
    tok = O.signup()
    payload = json.loads(base64.urlsafe_b64decode(tok.split(".")[1] + "=="))
    uid = payload.get("sub")
    rows = []

    def check(name, status, body, ok):
        rows.append({"check": name, "status": status, "body": body[:200], "ok": bool(ok)})
        print("OK  " if ok else "FAIL", name, status, body[:100], flush=True)

    s, b = call("GET", "/functions/v1/logo-vote", tok)
    check("GET before voting: null", s, b, s == 200 and json.loads(b).get("choice") is None)
    for c in "ABCDEF":
        time.sleep(1)
        s, b = call("POST", "/functions/v1/logo-vote", tok, {"choice": c})
        check(f"POST {c}", s, b, s == 200 and json.loads(b).get("choice") == c)
        s, b = call("GET", "/functions/v1/logo-vote", tok)
        check(f"GET after {c}", s, b, s == 200 and json.loads(b).get("choice") == c)
    s, b = call("POST", "/functions/v1/logo-vote", tok, {"choice": "d"})
    check("POST lowercase 'd' accepted as D", s, b, s == 200 and json.loads(b).get("choice") == "D")
    for bad in ("G", "", "a b", "AB", 7, "Ö"):
        s, b = call("POST", "/functions/v1/logo-vote", tok, {"choice": bad})
        check(f"POST invalid {bad!r}", s, b, s == 400)
    s, b = call("GET", "/functions/v1/logo-vote", tok)
    check("GET after invalid posts: still D", s, b, s == 200 and json.loads(b).get("choice") == "D")
    s, b = call("GET", "/functions/v1/logo-vote?view=owner", tok)
    check("owner view as anonymous user", s, b, s == 403)
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o50-k41.json")
    out.write_text(json.dumps({"test_user_id": uid, "ok": f"{sum(r['ok'] for r in rows)}/{len(rows)}", "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("test user", uid, f"{sum(r['ok'] for r in rows)}/{len(rows)} ->", out)


if __name__ == "__main__":
    main()
