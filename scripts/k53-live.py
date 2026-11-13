#!/usr/bin/env python3
"""K53 live check: 30 photos (Oscar's invented bank photos, repeated to 30; never student material) uploaded one by
one through signed URLs (6 at a time, as a phone would), then drill with page_paths, then drill_answers.
Times each phase against the goal "30 photos to questions within 60 s" and checks the photos are deleted afterwards.
  python -X utf8 scripts/k53-live.py [--n 30]"""
import argparse, concurrent.futures as cf, json, pathlib, sys, time, urllib.error, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design


def token():
    req = urllib.request.Request(URL + "/auth/v1/signup", data=b"{}", method="POST", headers={"apikey": KEY, "content-type": "application/json"})
    return json.load(urllib.request.urlopen(req))["access_token"]


def exam(body, tok, timeout=180):
    req = urllib.request.Request(URL + "/functions/v1/exam", data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def put(url, data, ctype):
    req = urllib.request.Request(url, data=data, method="PUT", headers={"content-type": ctype})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.status


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=30)
    a = ap.parse_args()
    photos = sorted((ROOT / "scripts/qa/repetition_bank/files").glob("*/p*.jpg"))
    photos = (photos * (a.n // len(photos) + 1))[: a.n]
    size = sum(p.stat().st_size for p in photos)
    tok = token()
    out = {"photos": len(photos), "mb": round(size / 1e6, 1)}
    t0 = time.time()
    st, u = exam({"action": "upload_urls", "count": len(photos)}, tok)
    out["upload_urls"] = {"status": st, "s": round(time.time() - t0, 1)}
    ups = u["uploads"]
    t1 = time.time()
    with cf.ThreadPoolExecutor(6) as ex:
        codes = list(ex.map(lambda x: put(x[0]["url"], x[1].read_bytes(), x[0]["content_type"]), zip(ups, photos)))
    out["upload"] = {"ok": sum(c in (200, 201) for c in codes), "s": round(time.time() - t1, 1)}
    t2 = time.time()
    st, j = exam({"action": "drill", "page_paths": [x["path"] for x in ups], "answers": False, "questions": 20}, tok)
    out["questions"] = {"status": st, "s": round(time.time() - t2, 1), "count": len(j.get("items", [])), "possible": j.get("questions_possible"),
                        "subject": j.get("summary", {}).get("subject"), "cost": j.get("usage", {}).get("est_cost_usd"), "error": j.get("error")}
    out["total_to_questions_s"] = round(time.time() - t0, 1)
    if st == 200:
        t3 = time.time()
        st, k = exam({"action": "drill_answers", "items": j["items"], "notes": j["notes"], "subject": j["summary"]["subject"], "grade": j["summary"]["grade"]}, tok)
        out["answers"] = {"status": st, "s": round(time.time() - t3, 1), "answered": sum(1 for i in k.get("items", []) if i.get("short")),
                          "cost": k.get("usage", {}).get("est_cost_usd")}
    # the photos are gone: the same paths again -> 422 material_missing
    st, g = exam({"action": "drill", "page_paths": [ups[0]["path"]], "answers": False}, tok)
    out["deleted_after"] = {"status": st, "code": g.get("error", {}).get("code")}
    print(json.dumps(out, ensure_ascii=False, indent=1))
    (ROOT / "reports/eval/k53-live-2026-11-14.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
