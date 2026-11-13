#!/usr/bin/env python3
"""K50 live check (D151): about 2 100 ElevenLabs characters.
  1. a real 3-question drill (K45 output on Oscar's invented bank) with voice A (Multilingual v2): characters,
     credits ElevenLabs charged (character-cost) and the ratio -> the real cost per drill
  2. one tiny item each with voice B (v3) and C (Flash): the timestamp endpoint works for all three
  3. the voice is locked (409), the quota is counted ("list")
  4. clean-up (the shared audio stays)
  python -X utf8 scripts/k50-live.py"""
import datetime, json, pathlib, sys, time, urllib.error, urllib.request

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


def wait(did, tok):
    for _ in range(90):
        st, j = drill({"action": "status", "id": did}, tok)
        a = j.get("audio", {})
        if a.get("done", 0) + a.get("failed", 0) >= a.get("total", 1):
            return j
        time.sleep(2)
    return j


def main():
    tok = token()
    src = json.load(open(ROOT / "reports" / "eval" / "k45-drill-2026-11-13.json", encoding="utf-8"))
    ex = next(e for e in src if e["id"] == "hist-ak9-forsta-varldskriget")
    items = [{"question": i["question"], "short": i["short"], "long": i["long"]} for i in ex["items"][:3]]
    out = {}
    st, j = drill({"action": "save", "drill": {"title": "K50 livetest A (påhittat)", "voice_model": "A"}, "items": items}, tok)
    out["save_A"] = {"status": st, "new_chars": j.get("new_chars"), "generated_questions": j.get("generated_questions")}
    did = j["drill"]["id"]
    a = wait(did, tok)["audio"]
    out["A"] = {k: a.get(k) for k in ("done", "total", "failed", "chars", "credits", "credits_chars", "est_usd", "bytes", "model")}
    if a.get("credits") and a.get("credits_chars"):
        out["A"]["credits_per_char"] = round(a["credits"] / a["credits_chars"], 3)
    tiny = [{"question": "Varför är himlen blå?", "short": "Blått ljus sprids mest.", "long": "Blått ljus sprids mest. Därför ser himlen blå ut."}]
    for v in ("B", "C"):
        st, jv = drill({"action": "save", "drill": {"title": f"K50 livetest {v}", "voice_model": v}, "items": tiny}, tok)
        av = wait(jv["drill"]["id"], tok)
        long = av["items"][0]["audio"]["long"]
        out[v] = {"status": st, **{k: av["audio"].get(k) for k in ("done", "total", "failed", "chars", "credits", "model")},
                  "short_end_ms": long.get("short_end_ms"), "duration_ms": long.get("duration_ms")}
        drill({"action": "delete", "id": jv["drill"]["id"]}, tok)
    st, lk = drill({"action": "save", "drill": {"id": did, "voice_model": "B"}, "items": items}, tok)
    out["lock"] = {"status": st, "code": lk.get("error", {}).get("code")}
    st, ls = drill({"action": "list"}, tok)
    out["quota"] = ls.get("quota")
    drill({"action": "delete", "id": did}, tok)
    p = ROOT / "reports" / "eval" / f"k50-live-{datetime.date.today().isoformat()}.json"
    p.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(out, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
