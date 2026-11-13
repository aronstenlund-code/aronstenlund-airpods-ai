#!/usr/bin/env python3
"""K49 (D149): copies Skolverket's school unit register (skolenhetsregistret v2, open data, updated daily) into
public.schools, so that a school is chosen from a list and never typed. Kept per unit: code, name, locality,
municipality code, school types and status. Never the head teacher, phone or e-mail.
The list gives code, name and status; the details (locality, municipality, school types) are fetched only for units
that are new or whose name changed, so a weekly run costs a few hundred calls. Run by the "Schools sync" workflow.
  SUPABASE_SERVICE_ROLE_KEY=... python3 scripts/schools-sync.py [--max-details 9000]"""
import argparse, concurrent.futures as cf, json, os, sys, time, urllib.error, urllib.request

API = "https://api.skolverket.se/skolenhetsregistret/v2/school-units"
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"


def get(url, tries=4):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "earmind-schools-sync"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except (urllib.error.URLError, TimeoutError):
            if i == tries - 1:
                raise
            time.sleep(2 * (i + 1))


def rest(method, path, key, body=None, prefer=None):
    headers = {"apikey": key, "content-type": "application/json"}
    if key.startswith("eyJ"):
        headers["authorization"] = "Bearer " + key
    if prefer:
        headers["prefer"] = prefer
    req = urllib.request.Request(URL + "/rest/v1/" + path, method=method, headers=headers,
                                 data=json.dumps(body).encode() if body is not None else None)
    with urllib.request.urlopen(req, timeout=120) as r:
        raw = r.read()
        return json.loads(raw) if raw else None


def detail(code):
    d = get(f"{API}/{code}")["data"]["attributes"]
    addr = next((a for a in d.get("addresses", []) if a.get("type") == "BESOKSADRESS"), None) or (d.get("addresses") or [{}])[0]
    loc = (addr.get("locality") or "").strip().title() or None
    mc = d.get("municipalityCode")
    return {"locality": loc, "municipality_code": mc if mc and len(mc) == 4 else None, "school_types": d.get("schoolTypes") or []}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--max-details", type=int, default=9000)
    a = ap.parse_args()
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not key:
        print("SUPABASE_SERVICE_ROLE_KEY missing")
        return 1
    units = get(API)["data"]["attributes"]
    print(f"register: {len(units)} units")
    have = {}
    for off in range(0, 100_000, 1000):
        rows = rest("GET", f"schools?select=code,name,status,locality&order=code&offset={off}&limit=1000", key)
        for r in rows:
            have[r["code"]] = r
        if len(rows) < 1000:
            break
    print(f"database: {len(have)} schools")
    # details only for active or planned units that are new, renamed or still without a locality
    need = [u for u in units if u["status"] in ("AKTIV", "PLANERAD") and (
        u["schoolUnitCode"] not in have or have[u["schoolUnitCode"]]["name"] != u["name"] or not have[u["schoolUnitCode"]].get("locality"))]
    need = need[: a.max_details]
    print(f"details to fetch: {len(need)}")
    details, failed = {}, 0
    with cf.ThreadPoolExecutor(max_workers=8) as ex:
        futs = {ex.submit(detail, u["schoolUnitCode"]): u["schoolUnitCode"] for u in need}
        for f in cf.as_completed(futs):
            try:
                details[futs[f]] = f.result()
            except Exception as e:  # one unit failing never stops the run
                failed += 1
                if failed <= 5:
                    print("detail failed", futs[f], str(e)[:100])
    rows = []
    for u in units:
        c = u["schoolUnitCode"]
        old = have.get(c, {})
        d = details.get(c, {})
        if c in have and old.get("name") == u["name"] and old.get("status") == u["status"] and not d:
            continue
        rows.append({"code": c, "name": u["name"][:200], "status": u["status"],
                     "locality": d.get("locality", old.get("locality")),
                     **({"municipality_code": d["municipality_code"]} if d.get("municipality_code") else {}),
                     **({"school_types": d["school_types"]} if "school_types" in d else {}),
                     "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())})
    # PostgREST bulk upsert needs the same keys in every row
    keys = ["code", "name", "status", "locality", "municipality_code", "school_types", "updated_at"]
    for r in rows:
        old = have.get(r["code"], {})
        r.setdefault("municipality_code", old.get("municipality_code"))
        r.setdefault("school_types", old.get("school_types") or [])
    for i in range(0, len(rows), 500):
        rest("POST", "schools?on_conflict=code", key, [{k: r.get(k) for k in keys} for r in rows[i:i + 500]],
             prefer="resolution=merge-duplicates,return=minimal")
    print(f"upserted {len(rows)} rows, {failed} details failed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
