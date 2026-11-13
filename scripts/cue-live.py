#!/usr/bin/env python3
"""Live check of the drill cue (cue.press_for_answer): one tiny invented drill per voice A, B, C; the cue is made once
per voice (about 25 characters each), then deleted drills (the shared audio stays).  python -X utf8 scripts/cue-live.py"""
import json, sys, time, urllib.error, urllib.request

URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design


def token():
    req = urllib.request.Request(URL + "/auth/v1/signup", data=b"{}", method="POST", headers={"apikey": KEY, "content-type": "application/json"})
    return json.load(urllib.request.urlopen(req))["access_token"]


def drill(body, tok):
    req = urllib.request.Request(URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=150) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def main():
    tok = token()
    item = [{"question": "Varför är himlen blå?", "short": "Blått ljus sprids mest.", "long": "Blått ljus sprids mest. Därför ser himlen blå ut."}]
    out = {}
    for v in ("A", "B", "C"):
        st, j = drill({"action": "save", "drill": {"title": f"Cue-test {v}", "voice_model": v}, "items": item}, tok)
        did = j["drill"]["id"]
        cue = {}
        for _ in range(30):
            st, j = drill({"action": "status", "id": did}, tok)
            cue = j.get("cue", {}).get("press_for_answer", {})
            if cue.get("status") == "done":
                break
            time.sleep(2)
        ok = False
        if cue.get("url"):
            mp3 = urllib.request.urlopen(cue["url"], timeout=30).read()
            ok = mp3[:3] == b"ID3" or mp3[:2] in (b"\xff\xfb", b"\xff\xf3")
        out[v] = {"status": cue.get("status"), "duration_ms": cue.get("duration_ms"), "mp3": ok}
        drill({"action": "delete", "id": did}, tok)
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
