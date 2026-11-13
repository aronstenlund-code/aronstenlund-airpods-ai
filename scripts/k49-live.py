#!/usr/bin/env python3
"""K49 live check of Publicera prov (D149, D150, R12), one tiny invented item (about 120 ElevenLabs
characters the first time, 0 after that). Invented text only.
  1. A saves the drill; publishing without school, subject, date is refused with what is missing
  2. A publishes at a real active school from Skolverket's register (public.schools)
  3. B searches the school (time measured, R12: within 5 s) and imports: 0 new characters
  4. the search result holds no account id; three accounts report it -> hidden from search
  5. clean-up: A and B delete their drills (the publication goes with A's)
  python -X utf8 scripts/k49-live.py [--school-q Nyköping]"""
import argparse, datetime, json, pathlib, sys, time, urllib.error, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
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
    ap = argparse.ArgumentParser()
    ap.add_argument("--school-q", default="Nyköping")
    a = ap.parse_args()
    out = {}
    ta, tb = token(), token()
    st, sc = drill({"action": "schools", "q": a.school_q}, ta)
    school = (sc.get("schools") or [None])[0]
    out["schools"] = {"status": st, "count": len(sc.get("schools") or []), "first": school}
    if not school:
        print("no school found", st, sc)
        return 1
    # one tiny invented item (about 120 characters of audio, under 0.01 USD the first time, 0 after that)
    items = [{"question": "Varför behövs klorofyll?", "short": "Klorofyll fångar ljusenergi.", "long": "Klorofyll fångar ljusenergi. Utan den kan växten inte bilda glukos."}]
    st, j = drill({"action": "save", "drill": {"title": "K49 livetest (påhittat)", "subject": ""}, "items": items}, ta)
    for _ in range(40):  # wait for the audio (publishing needs all of it)
        if j.get("audio", {}).get("done") == j.get("audio", {}).get("total"):
            break
        time.sleep(2)
        st, j = drill({"action": "status", "id": j["drill"]["id"]}, ta)
    out["save"] = {"status": st, "new_chars": j.get("new_chars"), "audio": j.get("audio", {}).get("done"), "total": j.get("audio", {}).get("total")}
    did = j["drill"]["id"]
    st, m = drill({"action": "publish", "id": did}, ta)
    out["publish_empty"] = {"status": st, "missing": m.get("missing")}
    today = datetime.date.today()
    st, p = drill({"action": "publish", "id": did, "school_code": school["code"], "subject": "Biologi", "exam_date": (today + datetime.timedelta(days=7)).isoformat()}, ta)
    out["publish"] = {"status": st}
    pid = p.get("publication", {}).get("id")
    t0 = time.time()
    st, s = drill({"action": "search", "school_code": school["code"], "my_school": school["code"]}, tb)
    res = s.get("results", [])
    out["search"] = {"status": st, "s": round(time.time() - t0, 2), "found": any(r["id"] == pid for r in res),
                     "account_in_result": any(k in json.dumps(res) for k in ("user_id", "drill_id")), "fields": sorted(res[0].keys()) if res else []}
    st, c = drill({"action": "import", "publication_id": pid}, tb)
    out["import"] = {"status": st, "new_chars": c.get("new_chars"), "done": c.get("audio", {}).get("done"), "total": c.get("audio", {}).get("total")}
    st, pl = drill({"action": "played", "id": c.get("drill", {}).get("id")}, tb)
    out["played"] = {"status": st, "counted": pl.get("counted")}
    reps = []
    for _ in range(3):
        st, r = drill({"action": "report", "publication_id": pid, "reason": "fel"}, token())
        reps.append(r)
    out["reports"] = reps
    st, s2 = drill({"action": "search", "school_code": school["code"]}, tb)
    out["hidden_from_search"] = not any(r["id"] == pid for r in s2.get("results", []))
    drill({"action": "delete", "id": did}, ta)
    if c.get("drill"):
        drill({"action": "delete", "id": c["drill"]["id"]}, tb)
    p_ = ROOT / "reports" / "eval" / f"k49-live-{today.isoformat()}.json"
    p_.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(out, ensure_ascii=False, indent=1))
    print("->", p_)
    return 0


if __name__ == "__main__":
    sys.exit(main())
