#!/usr/bin/env python3
"""Oscar O55: K46/K47 live, R5 (RLS), R5b (aldrig samma ljud två gånger), R5c (delning utan ElevenLabs).
Egna texter: två "bra" par ur o55_calibration.json (skrivna av Oscar, aldrig elevtext), som ingen annan har
genererat, så att första sparningen verkligen gör ljud. Högst 2 000 ElevenLabs-tecken (O55, D120): skriptet räknar
före varje sparning och stoppar annars.
  1. A sparar 2 frågor -> new_chars = frågor + långa svar; dela direkt -> 409 audio_not_ready (R5c)
  2. A pollar status tills allt är klart (tid, filer, short_end_ms < duration_ms)
  3. A sparar igen med samma id -> new_chars 0; B sparar samma texter i ett eget prov -> new_chars 0 (R5b, alla konton)
  4. A ändrar bara frågan i par 1 -> new_chars = den nya frågans längd (R5b)
  5. R5: B get/delete/share på A:s prov nekas; B list utan A:s prov; PostgREST drills/drill_items som B = []
     och som anonym = []; Storage-sökvägen ur A:s länk utan signatur nekas
  6. R5c: A delar -> kod; B share_info, import (tid <= 10 s, new_chars 0, alla filer klara); B ändrar sin kopia,
     A:s original oförändrat; B kan inte stänga A:s delning; A unshare -> import 404
  python -I -X utf8 scripts/qa/o55_drill_server.py"""
import sys as _d180s, pathlib as _d180p; _d180s.path.insert(0, str(_d180p.Path(__file__).resolve().parent)); import qa_testaccount; qa_testaccount.install()  # D180: bara testkonton, aldrig riktiga ElevenLabs
import datetime as dt, json, pathlib, sys, time, urllib.error, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
BUDGET = 2000
spent = 0
checks = []


def token():
    req = urllib.request.Request(URL + "/auth/v1/signup", data=b"{}", method="POST", headers={"apikey": KEY, "content-type": "application/json"})
    return json.load(urllib.request.urlopen(req))["access_token"]


def http(method, path, tok=None, body=None):
    h = {"apikey": KEY, "content-type": "application/json"}
    if tok:
        h["authorization"] = "Bearer " + tok
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode() if body is not None else None, method=method, headers=h)
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=150) as r:
            raw = r.read()
            try:
                return r.status, json.loads(raw or b"{}"), time.time() - t0
            except ValueError:
                return r.status, {"_bytes": len(raw)}, time.time() - t0
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw or b"{}"), time.time() - t0
        except ValueError:
            return e.code, {"_raw": raw[:200].decode(errors="replace")}, time.time() - t0


def drill(tok, body):
    return http("POST", "/functions/v1/drill", tok, body)


def check(name, ok, detail=""):
    checks.append({"check": name, "ok": bool(ok), "detail": detail})
    print(("OK  " if ok else "FEL ") + name + (f" | {detail}" if detail else ""), flush=True)


def save(tok, drill_meta, items, expect_chars):
    global spent
    if spent + expect_chars > BUDGET:
        raise SystemExit(f"stopp: {spent} + {expect_chars} tecken är över budgeten {BUDGET}")
    st, j, t = drill(tok, {"action": "save", "drill": drill_meta, "items": items})
    spent += j.get("new_chars", 0) if st == 200 else 0
    return st, j, t


def wait_done(tok, did, limit_s=240):
    t0 = time.time()
    while time.time() - t0 < limit_s:
        st, j, _ = drill(tok, {"action": "status", "id": did})
        a = j.get("audio", {})
        if st == 200 and a.get("total") and a.get("done", 0) + a.get("failed", 0) >= a["total"]:
            return j, time.time() - t0
        time.sleep(3)
    return j, time.time() - t0


def main():
    cal = json.loads((ROOT / "scripts/qa/repetition_bank/o55_calibration.json").read_text(encoding="utf-8"))["items"]
    pick = [c for c in cal if c["label"] == "good" and c["exam"] in ("fy-ak9-ellara", "ge-ak7-klimat")]
    items = [{"question": c["question"], "short": c["short"], "long": c["long"]} for c in pick]
    chars = sum(len(i["question"]) + len(i["long"]) for i in items)
    meta = {"title": "O55 testprov (påhittat)", "subject": "Fysik", "grade": "åk 9", "covers": "Ellära och klimat, Oscars testbank", "long_words": 90}
    A, B = token(), token()

    # 1
    st, a1, _ = save(A, meta, items, chars)
    check("A sparar 2 frågor", st == 200, f"status {st}, new_chars {a1.get('new_chars')} (väntat {chars} om texten är ny)")
    did = a1.get("drill", {}).get("id")
    ids = [i["id"] for i in a1.get("items", [])]
    st, j, _ = drill(A, {"action": "share", "id": did})
    check("R5c dela före klart ljud ger 409", st == 409 and j.get("error", {}).get("code") == "audio_not_ready", f"{st} {json.dumps(j, ensure_ascii=False)[:160]}")

    # 2
    s2, t_audio = wait_done(A, did)
    au = s2.get("audio", {})
    check("allt ljud klart", au.get("done") == au.get("total") and not au.get("failed"), f"{au} på {t_audio:.0f} s")
    files_ok = all(it["audio"]["question"].get("url") and it["audio"]["long"].get("url") for it in s2.get("items", []))
    se_ok = all(0 < (it["audio"]["long"].get("short_end_ms") or 0) < (it["audio"]["long"].get("duration_ms") or 0) for it in s2.get("items", []))
    check("varje fråga har fråga- och långt-fil med länk", files_ok, f"{len(s2.get('items', []))} frågor")
    check("D145 short_end_ms < duration_ms", se_ok, str([(it['audio']['long'].get('short_end_ms'), it['audio']['long'].get('duration_ms')) for it in s2.get('items', [])]))
    url0 = s2["items"][0]["audio"]["long"].get("url", "")
    st, j, _ = http("GET", url0.replace(URL, "")) if url0.startswith(URL) else (0, {}, 0)
    check("A:s signerade länk går att hämta", st == 200 and j.get("_bytes", 0) > 1000, f"{st} {j.get('_bytes')} byte")

    # 3
    same = [{"id": i, **it} for i, it in zip(ids, items)]
    st, j, _ = save(A, {**meta, "id": did}, same, 0)
    check("R5b A sparar igen oförändrat: 0 nya tecken", st == 200 and j.get("new_chars") == 0, f"{st} new_chars {j.get('new_chars')}")
    st, b1, _ = save(B, {**meta, "title": "B:s eget prov"}, items, 0)
    check("R5b B sparar samma texter i eget prov: 0 nya tecken", st == 200 and b1.get("new_chars") == 0, f"{st} new_chars {b1.get('new_chars')}")
    bdid = b1.get("drill", {}).get("id")
    sb, _ = wait_done(B, bdid, 30)
    check("R5b B:s prov är klart direkt (återanvända filer)", sb.get("audio", {}).get("done") == sb.get("audio", {}).get("total"), str(sb.get("audio")))

    # 4
    newq = "Varför slocknar alla i seriekoppling?"
    edit = [{"id": ids[0], "question": newq, "short": items[0]["short"], "long": items[0]["long"]}, same[1]]
    st, j, _ = save(A, {**meta, "id": did}, edit, len(newq))
    check("R5b ändrad fråga ger bara den frågans fil", st == 200 and j.get("new_chars") == len(newq), f"new_chars {j.get('new_chars')} (väntat {len(newq)})")
    wait_done(A, did)

    # 5 R5
    for act in ("get", "status", "delete", "share", "unshare"):
        st, j, _ = drill(B, {"action": act, "id": did})
        check(f"R5 B {act} på A:s prov nekas", st in (403, 404), f"{st} {j.get('error', {}).get('code')}")
    st, j, _ = drill(B, {"action": "list"})
    check("R5 B:s lista saknar A:s prov", st == 200 and all(d["id"] != did for d in j.get("drills", [])), f"{len(j.get('drills', []))} prov")
    for tbl in ("drills", "drill_items"):
        col = "id" if tbl == "drills" else "drill_id"
        st, j, _ = http("GET", f"/rest/v1/{tbl}?{col}=eq.{did}&select=*", B)
        check(f"R5 PostgREST {tbl} som B", (st == 200 and j == []) or st in (401, 403, 404), f"{st} {str(j)[:100]}")
        st, j, _ = http("GET", f"/rest/v1/{tbl}?{col}=eq.{did}&select=*", None)
        check(f"R5 PostgREST {tbl} som anonym", (st == 200 and j == []) or st in (401, 403, 404), f"{st} {str(j)[:100]}")
    if "/object/sign/" in url0:
        path = url0.split("/object/sign/")[1].split("?")[0]
        st, j, _ = http("GET", "/storage/v1/object/" + path, B)
        check("R5 ljudfilen utan signatur som B nekas", st in (400, 401, 403, 404), f"{st}")
        st, j, _ = http("GET", "/storage/v1/object/public/" + path, None)
        check("R5 ljudfilen som publik länk nekas", st in (400, 401, 403, 404), f"{st}")

    # 6 R5c
    st, sh, _ = drill(A, {"action": "share", "id": did})
    check("R5c A delar när allt ljud är klart", st == 200 and sh.get("code"), f"{st} {sh}")
    code = sh.get("code")
    st2, sh2, _ = drill(A, {"action": "share", "id": did})
    check("R5c samma kod igen", sh2.get("code") == code, str(sh2.get("code")))
    C = token()
    st, info, _ = drill(C, {"action": "share_info", "code": code})
    check("R5c share_info", st == 200 and info.get("audio_ready") is True, json.dumps(info, ensure_ascii=False)[:160])
    st, imp, t_imp = drill(C, {"action": "import", "code": sh.get("url") or code})
    spent_before = spent
    ia = imp.get("audio", {})
    check("R5c import <= 10 s och 0 nya tecken", st == 200 and imp.get("new_chars") == 0 and t_imp <= 10, f"{st} {t_imp:.1f} s new_chars {imp.get('new_chars')}")
    check("R5c kopian har allt ljud klart", ia.get("done") == ia.get("total") and all(it["audio"]["long"].get("url") for it in imp.get("items", [])), str(ia))
    check("R5c kopian pekar på samma filer (shared_from)", imp.get("drill", {}).get("shared_from") is not None, str(imp.get("drill", {}).get("shared_from")))
    cdid = imp.get("drill", {}).get("id")
    citems = imp.get("items", [])
    st, j, _ = drill(C, {"action": "unshare", "id": did})
    check("R5c mottagaren kan inte stänga A:s delning", st in (403, 404), f"{st}")
    # C ändrar sin kopia (bara frågan i par 2, några tecken)
    q2 = "Varför regnar det mest på västsidan?"
    cedit = [{"id": citems[0]["id"], "question": citems[0]["question"], "short": citems[0]["short"], "long": citems[0]["long"]},
             {"id": citems[1]["id"], "question": q2, "short": citems[1]["short"], "long": citems[1]["long"]}]
    st, j, _ = save(C, {**{k: imp["drill"].get(k) for k in ("title", "subject", "grade", "covers", "long_words")}, "id": cdid}, cedit, len(q2))
    check("R5c mottagarens ändring kostar bara den frågan", st == 200 and j.get("new_chars") == len(q2), f"new_chars {j.get('new_chars')}")
    st, orig, _ = drill(A, {"action": "get", "id": did})
    check("R5c originalet oförändrat", st == 200 and orig["items"][1]["question"] == items[1]["question"], orig.get("items", [{}, {}])[1].get("question"))
    st, j, _ = drill(A, {"action": "unshare", "id": did})
    check("R5c A stänger delningen", st == 200, f"{st}")
    st, j, _ = drill(token(), {"action": "import", "code": code})
    check("R5c import efter stängd delning ger 404", st == 404 and j.get("error", {}).get("code") == "share_not_found", f"{st} {j.get('error', {}).get('code')}")

    # städning: radera testproven
    for tok, d in ((A, did), (B, bdid), (C, cdid)):
        drill(tok, {"action": "delete", "id": d})
    ok = sum(c["ok"] for c in checks)
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o55-drill-server.json")
    out.write_text(json.dumps({"checks": checks, "elevenlabs_chars": spent, "audio_model": s2.get("audio", {}).get("model"),
                               "audio_est_usd": s2.get("audio", {}).get("est_usd"), "audio_bytes": s2.get("audio", {}).get("bytes"),
                               "t_audio_s": round(t_audio, 1), "t_import_s": round(t_imp, 1)}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\n{ok}/{len(checks)} OK, ElevenLabs {spent} tecken -> {out}")


if __name__ == "__main__":
    main()
