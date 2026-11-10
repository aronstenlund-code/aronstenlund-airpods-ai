#!/usr/bin/env python3
"""K19 live: 'har du en film om …' in Provläge: one checked link (Swedish learning resources) or the honest no.
Each returned link is fetched again here (status, title).  python -X utf8 -I scripts/k19-eval.py --tokens FILE"""
import argparse, datetime, importlib.util, json, pathlib, re, sys, time, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


PE = load("pe", ROOT / "scripts/provlage-eval.py")
D = load("demo", ROOT / "scripts/qa/demo.py")
CASES = [("Biologi", "har du en film om fotosyntes"), ("Historia", "finns det någon bra film om franska revolutionen"),
         ("Matematik", "har du en video om Pythagoras sats"), ("Historia", "har du en film om andra världskriget"),
         ("Matematik", "finns det någon bra sida om ekvationer"), ("Biologi", "har du en film om cellen"),
         ("Kemi", "har du en film om syror och baser"), ("Geografi", "har du en film om plattektonik")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", required=True)
    a = ap.parse_args()
    toks = [PE.signup(a.tokens, i) for i in (5, 6)]
    rows = []
    for i, (subj, q) in enumerate(CASES):
        r = D.ask(toks[i % 2], {"fragment": q, "mode": "tutor", "language": "sv", "persona": "tutor",
                                "persona_setup": f"Prov i {subj} nästa vecka. Årskurs: Åk 8. Ämne: {subj}.", "context": {}})
        done = r.get("done") or {}
        res = done.get("resource")
        recheck = None
        if res:
            try:
                rr = urllib.request.urlopen(urllib.request.Request(res["url"], headers={"user-agent": "Mozilla/5.0"}), timeout=15)
                t = re.search(r"<title[^>]*>([^<]{1,200})</title>", rr.read(60000).decode("utf-8", "replace"), re.I)
                recheck = {"status": rr.status, "title": t.group(1).strip() if t else ""}
            except Exception as e:
                recheck = {"status": getattr(e, "code", 0), "title": ""}
        rows.append({"q": q, "status": r["status"], "said": r.get("text", ""), "resource": res, "recheck": recheck, "cost": r.get("cost")})
        print(r["status"], q, "|", (res or {}).get("url"), "|", (recheck or {}).get("status"), (recheck or {}).get("title", "")[:60], "|", r.get("text", "")[:90], flush=True)
        time.sleep(1)
    s = {"n": len(rows), "with_link": sum(bool(x["resource"]) for x in rows), "links_200": sum(bool(x["recheck"]) and x["recheck"]["status"] == 200 for x in rows)}
    json.dump({"summary": s, "rows": rows}, open(ROOT / "reports" / "eval" / f"k19-{datetime.date.today()}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(json.dumps(s))


if __name__ == "__main__":
    sys.exit(main())
