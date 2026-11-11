#!/usr/bin/env python3
"""Oscar QA, O53: K43 test-mode audio (D140) from the client side, with the public key and an anonymous user. The
bucket debug_audio and the tables debug_turns / debug_testers must be unreachable; /debug-audio must refuse
anonymous opt-in, upload and the owner view; a forged token is refused; purge takes no parameters that reach other
folders. Creates no email accounts (that sends mail). 0 USD, 0 ElevenLabs.
  python -I scripts/qa/o53_k43_live.py -> reports/qa/data/<stamp>-o53-k43.json"""
import base64, datetime as dt, importlib.util, json, pathlib, sys, urllib.error, urllib.request
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o38", ROOT / "scripts/qa/o38_k38_live.py"); L = importlib.util.module_from_spec(spec); spec.loader.exec_module(L)
call, O, D = L.call, L.O, L.O.D


def raw(method, path, tok=None, data=b"", ctype="audio/mp4"):
    h = {"apikey": D.KEY, "content-type": ctype}
    if tok:
        h["authorization"] = "Bearer " + tok
    try:
        with urllib.request.urlopen(urllib.request.Request(D.URL + path, data=data if method != "GET" else None, method=method, headers=h), timeout=30) as r:
            return r.status, r.read().decode("utf-8", "replace")[:200]
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")[:200]


def main():
    tok = O.signup()
    rows = []

    def check(name, status, body, ok):
        rows.append({"check": name, "status": status, "body": body[:200], "ok": bool(ok)})
        print("OK  " if ok else "FAIL", name, status, body[:110], flush=True)

    refused = lambda s, b: s in (400, 401, 403, 404) or '"42501"' in b or "permission denied" in b or "not found" in b.lower() or "Unauthorized" in b
    for who, t in (("public key only", None), ("anonymous user", tok)):
        for tbl in ("debug_turns", "debug_testers"):
            s, b = call("GET", f"/rest/v1/{tbl}?select=*", t)
            check(f"REST select {tbl} ({who})", s, b, refused(s, b))
            s, b = call("POST", f"/rest/v1/{tbl}", t, {"user_id": "00000000-0000-0000-0000-000000000000"}, {"prefer": "return=minimal"})
            check(f"REST insert {tbl} ({who})", s, b, refused(s, b))
        s, b = call("POST", "/storage/v1/object/list/debug_audio", t, {"prefix": "", "limit": 100})
        check(f"storage list debug_audio ({who})", s, b, refused(s, b) or b.strip() == "[]")
        s, b = raw("GET", "/storage/v1/object/public/debug_audio/2026-11-11/x.m4a", t)
        check(f"storage public URL ({who})", s, b, refused(s, b))
        s, b = raw("POST", "/storage/v1/object/debug_audio/2026-11-11/oscar-o53-probe.m4a", t, b"\x00" * 16)
        check(f"storage direct upload ({who})", s, b, refused(s, b))
        s, b = raw("GET", "/storage/v1/bucket/debug_audio", t, ctype="application/json")
        check(f"storage bucket info ({who})", s, b, refused(s, b) or '"public":false' in b.replace(" ", ""))
    s, b = call("GET", "/functions/v1/debug-audio", None)
    check("GET flag without token", s, b, s == 401)
    s, b = call("GET", "/functions/v1/debug-audio", "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.forged")
    check("GET flag with forged token", s, b, s == 401)
    s, b = call("GET", "/functions/v1/debug-audio", tok)
    check("GET flag anonymous: false", s, b, s == 200 and json.loads(b).get("debug_audio") is False)
    s, b = call("POST", "/functions/v1/debug-audio?action=opt_in", tok, {})
    check("opt_in anonymous", s, b, s == 403)
    s, b = call("POST", "/functions/v1/debug-audio", tok, {"audio_b64": base64.b64encode(b"\x00" * 64).decode(), "audio_mime": "audio/mp4", "transcript": "test"})
    check("upload turn anonymous", s, b, s == 403)
    s, b = call("GET", "/functions/v1/debug-audio?view=owner", tok)
    check("owner view anonymous", s, b, s == 403)
    s, b = call("POST", "/functions/v1/debug-audio?action=purge&days=0&folder=..", None, {"days": 0, "folder": "2026-11-11"})
    check("purge ignores days/folder parameters (removes only > 14 days)", s, b, s == 200 and json.loads(b).get("removed") == 0)
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o53-k43.json")
    out.write_text(json.dumps({"ok": f"{sum(r['ok'] for r in rows)}/{len(rows)}", "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{sum(r['ok'] for r in rows)}/{len(rows)} ->", out)


if __name__ == "__main__":
    main()
