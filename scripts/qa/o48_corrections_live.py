#!/usr/bin/env python3
"""Oscar QA, O48: corrections in a student's own words LIVE against /memory {"correction": {...}} after Kevin's
standing round 13 (915211e/f901141: an utterance the code does not know gets a tiny Haiku check). Cases: O22b's 20
corrections and 15 non-corrections (scripts/qa/o22b_corrections_offline.mjs, none in Kevin's tests), plus 15 NEW
short feedback-like sentences about something else (the new false-hit risk of a model check). Stateless (settings are
sent and returned), Haiku only, ~0.005 USD.
  python -I scripts/qa/o48_corrections_live.py -> reports/qa/data/<stamp>-o48-corrections.json"""
import datetime as dt, importlib.util, json, pathlib, re, sys, time, urllib.error, urllib.request
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o15", ROOT / "scripts/qa/o15.py"); O = importlib.util.module_from_spec(spec); spec.loader.exec_module(O)
D = O.D
src = (ROOT / "scripts/qa/o22b_corrections_offline.mjs").read_text(encoding="utf-8")
def arr(name):
    block = src.split(f"const {name} = [", 1)[1].split("\n];", 1)[0]
    return block
CORR = re.findall(r'\["([^"]+)", "([a-z]+:[a-z]+)"\]', arr("CORR"))
NOT_CORR = re.findall(r'"([^"]+)"', arr("NOT_CORR"))
NEW_NOT = [  # 2026-11-11 16:08, feedback-like but about something else, or a request/command
    "läraren pratar för mycket", "boken är för svår", "mamma säger att jag ska plugga mer", "filmen var alldeles för lång",
    "ge mig ett exempel på en metafor", "kan du pausa", "stopp", "säg det igen", "vad betyder enklare",
    "provet var för svårt", "min kompis förklarar alltid för krångligt", "det där stämmer, tack", "ja, precis så",
    "jag fattar inte varför Napoleon förlorade", "det var fel av Sverige att gå med i kriget",
]


def post(tok, text):
    body = {"correction": {"text": text, "context": {"mode": "fragor"}}, "settings": []}
    req = urllib.request.Request(D.URL + "/functions/v1/memory", data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": D.KEY, "content-type": "application/json", "authorization": "Bearer " + tok})
    try:
        with urllib.request.urlopen(req, timeout=30) as x:
            return x.status, json.loads(x.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, {"err": e.read().decode()[:200]}


def main():
    tok, rows = O.signup(), []
    for group, items in (("corr", CORR), ("not_corr", [(t, None) for t in NOT_CORR]), ("new_not", [(t, None) for t in NEW_NOT])):
        for t, want in items:
            time.sleep(3.2)
            st, j = post(tok, t)
            s = j.get("setting") or {}
            got = f"{s.get('key')}:{s.get('value')}" if s else None
            ok = got == want
            rows.append({"group": group, "t": t, "want": want, "got": got, "by": j.get("by"), "status": st, "ok": ok, "err": j.get("err")})
            print(group, "OK " if ok else "BAD", "|", t, "->", got, j.get("by") or "", j.get("err") or "", flush=True)
    s = {g: f"{sum(r['ok'] for r in rows if r['group'] == g)}/{sum(r['group'] == g for r in rows)}" for g in ("corr", "not_corr", "new_not")}
    s["by_model"] = sum(r["by"] == "model" for r in rows)
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o48-corrections.json")
    out.write_text(json.dumps({"summary": s, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(s), "->", out)


if __name__ == "__main__":
    main()
