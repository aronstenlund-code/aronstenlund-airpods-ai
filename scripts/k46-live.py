#!/usr/bin/env python3
"""K46 live check of /drill (D142-D145), at most 2 000 real ElevenLabs characters (D120):
  1. user A saves a small drill (questions and answers from the K45 run on Oscar's invented bank, never student text)
  2. polls "status" until every file is done; downloads one long answer and checks short_end_ms < duration
  3. user B saves the same drill: 0 new characters, the same files (D144, R5b)
  4. K47: A shares, B imports (0 new characters, R5c); B cannot unshare A's drill
  5. user B cannot get A's drill (404), and A's rows are not readable through PostgREST as B (RLS, R5)
  python -X utf8 scripts/k46-live.py [--items 3] [--out reports/eval]"""
import argparse, datetime, json, pathlib, sys, time, urllib.error, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design
MAX_CHARS = 2000


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
    ap = argparse.ArgumentParser()
    ap.add_argument("--items", type=int, default=3)
    ap.add_argument("--out", default=str(ROOT / "reports" / "eval"))
    a = ap.parse_args()
    src = json.load(open(sorted((ROOT / "reports" / "eval").glob("k45-drill-*.json"))[-1], encoding="utf-8"))[0]
    items = [{"question": i["question"], "short": i["short"], "long": i["long"]} for i in src["items"][: a.items]]
    chars = sum(len(i["question"]) + len(i["long"]) for i in items)
    assert chars <= MAX_CHARS, f"{chars} characters is over the budget"
    out = {"source": src["id"], "items": len(items), "text_chars": chars}
    ta, tb = token(), token()
    t0 = time.time()
    st, j = drill({"action": "save", "drill": {"title": "K46 livetest (påhittat)", "subject": src["summary"]["subject"], "grade": src["summary"]["grade"]}, "items": items}, ta)
    out["save_status"], out["save_s"], out["new_chars"] = st, round(time.time() - t0, 1), j.get("new_chars")
    if st != 200:
        print("save failed", st, j)
        return 1
    did = j["drill"]["id"]
    while time.time() - t0 < 300:
        st, j = drill({"action": "status", "id": did}, ta)
        a_ = j.get("audio", {})
        print(f"{time.time() - t0:5.1f} s  ljud {a_.get('done')} av {a_.get('total')} (fel {a_.get('failed')})")
        if a_.get("done", 0) + a_.get("failed", 0) >= a_.get("total", 1):
            break
        time.sleep(3)
    out["audio"] = j["audio"]
    out["all_done_s"] = round(time.time() - t0, 1)
    long0 = j["items"][0]["audio"]["long"]
    q0 = j["items"][0]["audio"]["question"]
    if long0.get("url"):
        mp3 = urllib.request.urlopen(long0["url"], timeout=60).read()
        out["long0"] = {"bytes": len(mp3), "is_mp3": mp3[:3] == b"ID3" or mp3[:2] in (b"\xff\xfb", b"\xff\xf3", b"\xff\xf2"),
                        "duration_ms": long0.get("duration_ms"), "short_end_ms": long0.get("short_end_ms")}
        out["long0"]["short_before_end"] = bool(long0.get("short_end_ms")) and long0["short_end_ms"] < long0["duration_ms"]
        out["question0_ms"] = q0.get("duration_ms")
    # D144 / R5b: the same drill for another account makes nothing new
    st, jb = drill({"action": "save", "drill": {"title": "kopia"}, "items": items}, tb)
    out["second_account"] = {"status": st, "new_chars": jb.get("new_chars"), "done": jb.get("audio", {}).get("done"), "total": jb.get("audio", {}).get("total")}
    # K47 / R5c: A shares, B imports: the same audio, 0 new characters, under 10 s
    st, sh = drill({"action": "share", "id": did}, ta)
    t1 = time.time()
    st_i, imp = drill({"action": "import", "code": sh.get("code", "")}, tb)
    out["share"] = {"status": st, "url": sh.get("url"), "import_status": st_i, "import_s": round(time.time() - t1, 1),
                    "new_chars": imp.get("new_chars"), "done": imp.get("audio", {}).get("done"), "total": imp.get("audio", {}).get("total"),
                    "shared_from_ok": imp.get("drill", {}).get("shared_from") == did}
    st_u, _ = drill({"action": "unshare", "id": did}, tb)
    out["share"]["unshare_by_other"] = st_u
    # R5: B cannot read A's drill, neither through the function nor PostgREST
    st, _ = drill({"action": "get", "id": did}, tb)
    req = urllib.request.Request(f"{URL}/rest/v1/drills?id=eq.{did}&select=id", headers={"apikey": KEY, "authorization": "Bearer " + tb})
    rows_b = json.load(urllib.request.urlopen(req))
    req = urllib.request.Request(f"{URL}/rest/v1/drills?id=eq.{did}&select=id", headers={"apikey": KEY, "authorization": "Bearer " + ta})
    rows_a = json.load(urllib.request.urlopen(req))
    req = urllib.request.Request(f"{URL}/rest/v1/drill_audio_files?select=hash&limit=1", headers={"apikey": KEY, "authorization": "Bearer " + tb})
    try:
        audio_rows = json.load(urllib.request.urlopen(req))
    except urllib.error.HTTPError as e:
        audio_rows = f"HTTP {e.code}"
    out["rls"] = {"function_get_as_b": st, "rest_as_b": len(rows_b), "rest_as_a": len(rows_a), "audio_table_as_b": audio_rows}
    # clean up A's and B's test drills (the shared audio stays)
    drill({"action": "delete", "id": did}, ta)
    for j_ in (jb, imp):
        if j_.get("drill"):
            drill({"action": "delete", "id": j_["drill"]["id"]}, tb)
    p = pathlib.Path(a.out) / f"k46-live-{datetime.date.today().isoformat()}.json"
    p.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(out, ensure_ascii=False, indent=1))
    print("->", p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
