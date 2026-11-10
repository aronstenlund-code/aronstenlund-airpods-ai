#!/usr/bin/env python3
"""K4.1: write the regression check's result as a comment on the commit. Compares with the newest nightly D87 run
in reports/eval (Sonnet). Usage: regress-comment.py <dir with provlage-*.json> <owner/repo> <sha>; GH_TOKEN in env."""
import glob, json, os, sys, urllib.request

d, repo, sha = sys.argv[1], sys.argv[2], sys.argv[3]
files = sorted(glob.glob(os.path.join(d, "provlage-*.json")), key=os.path.getmtime)
if not files:
    body = "**Svarsregression (K4):** körningen gav inget resultat (se loggen)."
else:
    s = json.load(open(files[-1], encoding="utf-8"))["summary"]
    base = None
    night = sorted(glob.glob("reports/eval/provlage-*-sonnet-sample.json"), key=os.path.getmtime)
    for f in reversed(night):
        try:
            b = json.load(open(f, encoding="utf-8"))["summary"]
            if b.get("graded", 0) >= 20:
                base = (os.path.basename(f), b)
                break
        except Exception:
            continue
    first = s.get("first_answer_suffices_pct")
    line = f"**Svarsregression (K4), 21 fall ur D87 (Sonnet svarar och bedömer):** första svaret räcker **{first} %**"
    if base:
        delta = round(first - base[1]["first_answer_suffices_pct"], 1)
        flag = " ⚠️ **försämring**" if delta <= -10 else ""
        line += f" ({'+' if delta >= 0 else ''}{delta} mot {base[0]}: {base[1]['first_answer_suffices_pct']} %){flag}"
    body = (line + f"\n\nkorrekt {s.get('correct_pct')} %, A-nivå {s.get('a_level_pct')} %, språk {s.get('lang_ok_pct')} %, "
            f"tomma {s.get('empty')}, fel {s.get('errors')}, första text p50 {s.get('server_ttft_p50')} ms, kostnad "
            f"{round(s.get('answer_cost_total_usd', 0) + s.get('judge_cost_total_usd', 0), 3)} USD. Per typ: {s.get('by_kind')}")
req = urllib.request.Request(f"https://api.github.com/repos/{repo}/commits/{sha}/comments", method="POST",
                             data=json.dumps({"body": body}).encode(),
                             headers={"authorization": "Bearer " + os.environ["GH_TOKEN"], "accept": "application/vnd.github+json"})
print(urllib.request.urlopen(req, timeout=30).status, body)
