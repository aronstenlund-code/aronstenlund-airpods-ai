#!/usr/bin/env python3
"""Oscar O56: K49 Publicera prov (D149, spec §11, R12) live mot /drill. Egna påhittade texter (o55_calibration.json),
aldrig elevtext. ElevenLabs: de två O55-paren finns redan som ljud (0 tecken); ett litet nytt par (< 150 tecken)
behövs för fallet "ljudet inte klart". Användarna återanvänds via refresh token (registreringar har tak per IP).
  1. R12 nekas utan skola, ämne, datum, ljud (var för sig, 4/4) + ogiltig skolkod och ogiltigt datum
  2. publicera; sök på skolan hittar provet inom 5 s; ämnesfilter; my_school
  3. inga personuppgifter: fälten i publication/search; display_name bara med show_name; inget konto-id
  4. hämta (B): 0 tecken, egen kopia, B:s ändring rör inte originalet
  5. RLS: B kan inte publicera/avpublicera A:s prov; PostgREST drill_publications/drill_reports/schools som B och
     anonym: läsa, skriva, ändra, radera nekas; moderate nekas för andra än Aron
  6. rapporter: samma konto räknas en gång; 3 olika konton döljer; dolt prov syns inte i sök och går inte att hämta
  7. städning: A avpublicerar och raderar
  python -I -X utf8 scripts/qa/o56_publish.py"""
import sys as _d180s, pathlib as _d180p; _d180s.path.insert(0, str(_d180p.Path(__file__).resolve().parent)); import qa_testaccount; qa_testaccount.install()  # D180: bara testkonton, aldrig riktiga ElevenLabs
import datetime as dt, json, os, pathlib, sys, time, urllib.error, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
TOKENS = pathlib.Path(os.environ.get("TEMP", "/tmp")) / "o56_tokens.json"
checks, spent = [], 0


def http(method, path, tok=None, body=None, extra=None):
    h = {"apikey": KEY, "content-type": "application/json", **(extra or {})}
    if tok:
        h["authorization"] = "Bearer " + tok
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode() if body is not None else None, method=method, headers=h)
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            raw = r.read()
            return r.status, (json.loads(raw) if raw.strip() else {}), time.time() - t0
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw or b"{}"), time.time() - t0
        except ValueError:
            return e.code, {"_raw": raw[:200].decode(errors="replace")}, time.time() - t0


def users(n):
    """n testanvändare; sparade refresh tokens återanvänds."""
    try:
        saved = json.loads(TOKENS.read_text())
    except Exception:
        saved = []
    out = []
    for i in range(n):
        j = None
        if i < len(saved):
            st, j, _ = http("POST", "/auth/v1/token?grant_type=refresh_token", body={"refresh_token": saved[i]})
            j = j if st == 200 else None
        while not j:
            st, j, _ = http("POST", "/auth/v1/signup", body={})
            if st == 429:
                print("  registrering 429, väntar 60 s", flush=True)
                time.sleep(60)
                j = None
            elif st != 200:
                raise SystemExit(f"signup {st} {j}")
        out.append(j)
    TOKENS.write_text(json.dumps([u["refresh_token"] for u in out]))
    return [u["access_token"] for u in out], [u["user"]["id"] for u in out]


def drill(tok, body):
    return http("POST", "/functions/v1/drill", tok, body)


def check(name, ok, detail=""):
    checks.append({"check": name, "ok": bool(ok), "detail": detail})
    print(("OK  " if ok else "FEL ") + name + (f" | {detail}" if detail else ""), flush=True)


def wait_done(tok, did, limit_s=120):
    t0 = time.time()
    while time.time() - t0 < limit_s:
        st, j, _ = drill(tok, {"action": "status", "id": did})
        a = j.get("audio", {})
        if a.get("total") and a.get("done", 0) + a.get("failed", 0) >= a["total"]:
            return j
        time.sleep(3)
    return j


def main():
    global spent
    (A, B, C, D, E), ids = users(5)
    cal = json.loads((ROOT / "scripts/qa/repetition_bank/o55_calibration.json").read_text(encoding="utf-8"))["items"]
    pick = [c for c in cal if c["label"] == "good" and c["exam"] in ("fy-ak9-ellara", "ge-ak7-klimat")]
    items = [{"question": c["question"], "short": c["short"], "long": c["long"]} for c in pick]
    meta = {"title": "O56 testprov (påhittat)", "subject": "Fysik", "grade": "åk 9", "covers": "Ellära, Oscars testbank", "long_words": 90}

    st, sv, _ = drill(A, {"action": "save", "drill": meta, "items": items})
    spent += sv.get("new_chars", 0)
    did = sv["drill"]["id"]
    check("A sparar (ljudet finns redan)", st == 200 and sv.get("new_chars") == 0, f"new_chars {sv.get('new_chars')}")
    wait_done(A, did)

    st, sc, _ = drill(A, {"action": "schools", "q": "Katedral"})
    schools = sc.get("schools", [])
    check("schools ger träffar", st == 200 and schools, f"{len(schools)} st, första {schools[:1]}")
    st, sc2, _ = drill(A, {"action": "schools", "q": "a"})
    check("schools kräver minst 2 bokstäver", st == 400 or not sc2.get("schools"), f"{st}")
    school = schools[0]["code"]
    date = (dt.date.today() + dt.timedelta(days=7)).isoformat()

    # 1 R12
    base = {"action": "publish", "id": did, "school_code": school, "subject": "Fysik", "exam_date": date}
    for miss, key in (("school", "school_code"), ("subject", "subject"), ("date", "exam_date")):
        b = {k: v for k, v in base.items() if k != key}
        st, j, _ = drill(A, b)
        check(f"R12 nekas utan {miss}", st == 409 and miss in (j.get("missing") or []), f"{st} {j.get('missing')} {j.get('error', {}).get('message')}")
        b[key] = ""
        st, j, _ = drill(A, b)
        check(f"R12 nekas med tom {miss}", st in (400, 409), f"{st} {j.get('missing')}")
    st, j, _ = drill(A, {**base, "school_code": "00000000"})
    check("ogiltig skolkod nekas", st in (400, 404, 409), f"{st} {j.get('error', {}).get('code')}")
    st, j, _ = drill(A, {**base, "exam_date": "2026-13-45"})
    check("ogiltigt datum nekas", st in (400, 409), f"{st} {j.get('error', {}).get('code')}")
    # ljudet inte klart: ett nytt litet par, publicera direkt efter sparning
    tiny = [{"question": "Varför jordas elsladdar?", "short": "Jordning leder bort felström.", "long": "Jordning leder bort felström. Då löser jordfelsbrytaren ut."}]
    st, sv2, _ = drill(A, {"action": "save", "drill": {**meta, "title": "O56 ljud ej klart"}, "items": tiny})
    spent += sv2.get("new_chars", 0)
    did2 = sv2["drill"]["id"]
    st, j, _ = drill(A, {**base, "id": did2})
    check("R12 nekas när ljudet inte är klart", st == 409 and "audio" in (j.get("missing") or []), f"{st} {j.get('missing')} (new_chars {sv2.get('new_chars')})")

    # 2 publicera och sök
    st, pub, _ = drill(A, base)
    p = pub.get("publication", {})
    check("A publicerar", st == 200 and p.get("id"), json.dumps(p, ensure_ascii=False)[:200])
    t0, found = time.time(), None
    while time.time() - t0 < 15 and not found:
        st, s, _ = drill(E, {"action": "search", "school_code": school})
        found = next((r for r in s.get("results", []) if r.get("id") == p.get("id")), None)
        if not found:
            time.sleep(0.5)
    t_found = time.time() - t0
    check("R12 sök på skolan hittar provet inom 5 s", found and t_found <= 5, f"{t_found:.1f} s")
    st, s, _ = drill(E, {"action": "search", "school_code": school, "subject": "Kemi"})
    check("ämnesfilter utesluter Fysik", all(r.get("id") != p.get("id") for r in s.get("results", [])), f"{len(s.get('results', []))} träffar")

    # 3 personuppgifter
    keys = sorted(found.keys()) if found else []
    bad_keys = [k for k in keys if any(x in k.lower() for x in ("user", "owner", "account", "email", "phone", "device", "install"))]
    blob = json.dumps(found or {}, ensure_ascii=False)
    check("R12 inga konto-id eller kontaktfält i sökresultatet", not bad_keys and not any(i in blob for i in ids), f"fält {keys}")
    check("display_name saknas när show_name är av", not (found or {}).get("display_name"), str((found or {}).get("display_name")))
    st, pub2, _ = drill(A, {**base, "show_name": False, "display_name": "Testnamn Oscar"})
    check("display_name publiceras inte utan show_name", not pub2.get("publication", {}).get("display_name"), str(pub2.get("publication", {}).get("display_name")))
    st, pub3, _ = drill(A, {**base, "show_name": True, "display_name": "Testnamn Oscar"})
    check("display_name visas med show_name", pub3.get("publication", {}).get("display_name") == "Testnamn Oscar", str(pub3.get("publication", {}).get("display_name")))
    drill(A, {**base, "show_name": False})
    st, s, _ = drill(E, {"action": "search", "school_code": school})
    again = next((r for r in s.get("results", []) if r.get("id") == p.get("id")), {})
    check("namnet försvinner när show_name stängs av", not again.get("display_name"), str(again.get("display_name")))

    # 4 hämta
    st, imp, t_imp = drill(B, {"action": "import", "publication_id": p.get("id")})
    check("R12 hämta = 0 tecken, eget prov med ljud", st == 200 and imp.get("new_chars") == 0 and imp.get("audio", {}).get("done") == imp.get("audio", {}).get("total"),
          f"{st} {t_imp:.1f} s new_chars {imp.get('new_chars')} {imp.get('audio')}")
    bid = imp.get("drill", {}).get("id")
    if bid:
        bi = imp["items"]
        drill(B, {"action": "save", "drill": {**{k: imp["drill"].get(k) for k in ("title", "subject", "grade", "covers", "long_words")}, "id": bid},
                  "items": [{"id": bi[0]["id"], "question": bi[0]["question"], "short": bi[0]["short"], "long": bi[0]["long"]}]})
        st, orig, _ = drill(A, {"action": "get", "id": did})
        check("B:s ändring (tog bort en fråga) rör inte originalet", len(orig.get("items", [])) == 2, f"{len(orig.get('items', []))} frågor")

    # 5 RLS
    st, j, _ = drill(B, {**base})
    check("RLS B kan inte publicera A:s prov", st in (403, 404), f"{st} {j.get('error', {}).get('code')}")
    st, j, _ = drill(B, {"action": "unpublish", "id": did})
    check("RLS B kan inte avpublicera A:s prov", st in (403, 404), f"{st} {j.get('error', {}).get('code')}")
    st, j, _ = drill(B, {"action": "moderate", "publication_id": p.get("id"), "hidden": True})
    check("moderate nekas för andra än Aron", st in (401, 403, 404), f"{st} {j.get('error', {}).get('code')}")
    for tbl in ("drill_publications", "drill_reports", "schools"):
        for who, tok in (("B", B), ("anonym", None)):
            st, j, _ = http("GET", f"/rest/v1/{tbl}?select=*&limit=1", tok)
            check(f"RLS läsa {tbl} som {who}", (st == 200 and j == []) or st in (401, 403, 404), f"{st} {str(j)[:80]}")
        st, j, _ = http("PATCH", f"/rest/v1/drill_publications?id=eq.{p.get('id')}", B, {"hidden": True}, {"prefer": "return=representation"})
        if tbl == "drill_publications":
            check("RLS ändra drill_publications som B", (st in (200, 204) and not j) or st in (401, 403, 404), f"{st} {str(j)[:80]}")
            st, j, _ = http("DELETE", f"/rest/v1/drill_publications?id=eq.{p.get('id')}", B, None, {"prefer": "return=representation"})
            check("RLS radera drill_publications som B", (st in (200, 204) and not j) or st in (401, 403, 404), f"{st} {str(j)[:80]}")
            st, j, _ = http("POST", "/rest/v1/drill_reports", B, {"publication_id": p.get("id"), "reason": "fel"})
            check("RLS skriva drill_reports som B", st in (401, 403, 404), f"{st} {str(j)[:80]}")
    st, j, _ = http("POST", "/rest/v1/rpc/report_publication", B, {})
    check("RLS rpc report_publication som B nekas", st in (401, 403, 404), f"{st}")

    # 6 rapporter
    st, r1, _ = drill(B, {"action": "report", "publication_id": p.get("id"), "reason": "fel"})
    st2, r1b, _ = drill(B, {"action": "report", "publication_id": p.get("id"), "reason": "krankande"})
    check("samma konto räknas en gång", r1.get("reports") == 1 and r1b.get("reports") in (1, None) and not r1b.get("hidden"), f"{r1} {st2} {r1b}")
    st, j, _ = drill(B, {"action": "report", "publication_id": p.get("id"), "reason": "skräp"})
    check("ogiltig rapportorsak nekas", st == 400, f"{st}")
    st, r2, _ = drill(C, {"action": "report", "publication_id": p.get("id"), "reason": "upphovsratt"})
    check("2 rapporter döljer inte", r2.get("reports") == 2 and not r2.get("hidden"), str(r2))
    st, r3, _ = drill(D, {"action": "report", "publication_id": p.get("id"), "reason": "annat"})
    check("R12 3 rapporter döljer provet", r3.get("reports") == 3 and r3.get("hidden") is True, str(r3))
    st, s, _ = drill(E, {"action": "search", "school_code": school})
    check("dolt prov syns inte i sök", all(r.get("id") != p.get("id") for r in s.get("results", [])), f"{len(s.get('results', []))} träffar")
    st, j, _ = drill(E, {"action": "import", "publication_id": p.get("id")})
    check("dolt prov går inte att hämta", st in (403, 404, 410), f"{st} {j.get('error', {}).get('code')}")

    # 7 städning
    st, j, _ = drill(A, {"action": "unpublish", "id": did})
    check("A avpublicerar sitt prov", st == 200, f"{st}")
    for tok, d in ((A, did), (A, did2), (B, bid)):
        if d:
            drill(tok, {"action": "delete", "id": d})
    ok = sum(c["ok"] for c in checks)
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o56-publish.json")
    out.write_text(json.dumps({"checks": checks, "elevenlabs_chars": spent, "school": schools[0], "t_search_s": round(t_found, 2)}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\n{ok}/{len(checks)} OK, ElevenLabs {spent} tecken -> {out}")


if __name__ == "__main__":
    main()
