#!/usr/bin/env python3
"""Oscar QA, O34b: K19 links asked for in own words (O15c group 14) with the link itself saved and checked: is there a
URL in done.source (or the SSE), does it answer HTTP 200, and is the page about the topic (title/text contains the
topic word)? ~0.02 USD per case (web search).
  python -I scripts/qa/o34b_k19_links.py [--only g14-07,...]  -> reports/qa/data/<stamp>-o34b-links.json"""
import argparse, datetime as dt, importlib.util, json, pathlib, re, sys, time, urllib.request
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o41", ROOT / "scripts/qa/o41_k36_live.py"); M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
spec = importlib.util.spec_from_file_location("b", ROOT / "scripts/qa/o15c_bank.py"); B = importlib.util.module_from_spec(spec); spec.loader.exec_module(B)
TOPIC = {"g14-01": "cell", "g14-02": "vulkan", "g14-03": "pythagoras", "g14-04": "revolution", "g14-05": "fotosyntes", "g14-06": "dna",
         "g14-07": "klimat", "g14-08": "derivat", "g14-09": "derivat", "g14-10": "demokrati"}


def page(url):
    try:
        req = urllib.request.Request(url, headers={"user-agent": "Mozilla/5.0 (QA link check)"})
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, r.read(400_000).decode("utf-8", "replace")
    except Exception as e:
        return getattr(e, "code", None) or repr(e)[:80], ""


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--only", default=""); a = ap.parse_args()
    tok, rows = M.O.signup(), []
    for c in B.CASES:
        if not c[0].startswith("g14") or (a.only and c[0] not in a.only.split(",")):
            continue
        time.sleep(3.2)
        st, ev, err = M.answer(tok, c[4], "auto")
        done = next((d for n, d in ev if n == "done"), {}) or {}
        said = "".join(d.get("text", "") for n, d in ev if n == "delta")
        blob = json.dumps([d for n, d in ev if n != "delta"], ensure_ascii=False)
        urls = sorted(set(re.findall(r"https?://[^\s\"'<>\\]+", blob)))
        checks = []
        for u in urls[:3]:
            s, html = page(u)
            title = (re.search(r"<title[^>]*>(.*?)</title>", html, re.S | re.I) or [None, ""])[1].strip()[:120]
            checks.append({"url": u, "status": s, "title": title, "on_topic": TOPIC[c[0]] in (title + html[:200000]).lower()})
        rows.append({"id": c[0], "text": c[4], "status": st, "said": said, "source": done.get("source"), "urls": checks, "usage": done.get("usage")})
        print(c[0], st, "|", c[4], "||", said[:90], "||", [(x["status"], x["on_topic"], x["url"][:70]) for x in checks], flush=True)
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o34b-links.json")
    out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8"); print(out)


if __name__ == "__main__":
    main()
