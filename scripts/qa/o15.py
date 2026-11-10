#!/usr/bin/env python3
"""Oscar QA, O15: run the reality bank (scripts/qa/o15_bank.py) against the live /answer, like the app.
  python -I scripts/qa/o15.py [--only g3,g5] [--cap 1.2] [--bank module]   -> reports/qa/data/<stamp>-o15.json
Frågor = mode auto (silence on, like listening), Provläge = mode tutor + persona tutor + profile.
Auto grade (then read by hand): spoke = done.answered and text and not retract;
  understood = a kw stem in meta.reconstructed_question or the answer (no kw: spoke);
  right = spoke and a kw stem in the answer; quiet_ok = expect silent and not spoke."""
import argparse, datetime as dt, importlib.util, json, pathlib, sys, time

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]


def load(name, rel):
    spec = importlib.util.spec_from_file_location(name, ROOT / rel)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


D = load("demo", "scripts/qa/demo.py")


def signup(wait_total=3600):
    """Anonymous signup; on the auth rate limit (429 over_request_rate_limit, per network) wait and try again."""
    t0 = time.time()
    while True:
        o = D.call("POST", "/auth/v1/signup", {})
        j = D.jbody(o) or {}
        if j.get("access_token"):
            return j["access_token"]
        if time.time() - t0 > wait_total:
            raise RuntimeError("signup failed: %s %s" % (o["status"], o["body"][:200]))
        print("signup", o["status"], "waiting 60 s", flush=True)
        time.sleep(60)


def body(mode, prof, text, profiles):
    if mode == "fragor":
        return {"fragment": text, "mode": "auto", "language": "sv", "context": {}}
    return {"fragment": text, "mode": "tutor", "language": "sv", "persona": "tutor", "persona_setup": profiles[prof], "context": {}}


def hit(kw, s):
    s = (s or "").lower()
    return any(k and k in s for k in kw.split("|"))


def grade(c, r):
    cid, g, mode, prof, text, expect, kw = c
    d, m = r.get("done") or {}, r.get("meta") or {}
    ans = (r.get("text") or "").strip()
    spoke = bool(d.get("answered")) and bool(ans) and not d.get("retract")
    recon = m.get("reconstructed_question") or ""
    out = {"spoke": spoke, "recon": recon, "is_question": m.get("is_question"), "answer_type": m.get("answer_type"),
           "app_command": m.get("app_command"), "status_done": d.get("status")}
    if expect == "silent":
        out["ok"] = not spoke
    elif expect == "answer":
        out["understood"] = hit(kw, recon + " " + ans) if kw else spoke
        out["right"] = spoke and (hit(kw, ans) if kw else True)
        out["ok"] = out["right"]
    else:
        out["ok"] = None
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--cap", type=float, default=1.2)
    ap.add_argument("--bank", default="scripts/qa/o15_bank.py")
    ap.add_argument("--tag", default="")
    a = ap.parse_args()
    B = load("bank", a.bank)
    cases = [c for c in B.CASES if not a.only or any(c[0].startswith(p) for p in a.only.split(","))]
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    rows, tok, n = [], None, 99
    out = ROOT / "reports/qa/data" / f"{stamp}-o15{a.tag}.json"
    for i, c in enumerate(cases):
        if D.spent >= a.cap:
            print("budget cap", D.spent, flush=True)
            break
        if n >= 35:  # new users: 40 answers per hour in their first 10 minutes (D79), 20 per minute after
            tok, n = signup(), 0
        r = D.ask(tok, body(c[2], c[3], c[4], B.PROFILES))
        n += 1
        if r["status"] == 429:  # wait once and retry with the same user (a fresh signup costs the network's signup quota)
            time.sleep(int(r.get("retry_after") or 30) + 1)
            r = D.ask(tok, body(c[2], c[3], c[4], B.PROFILES))
        u = ((r.get("done") or {}).get("usage") or {})
        row = {"id": c[0], "group": c[1], "mode": c[2], "profile": c[3], "text": c[4], "expect": c[5], "kw": c[6], "status": r["status"],
               "answer": (r.get("text") or "")[:1200], "model": u.get("model"), "web": u.get("web_searches"), "first_ms": r.get("first_ms"),
               "ms": r.get("ms"), "cost": round(r.get("cost", 0) or 0, 5), "err": r.get("err"), **grade(c, r)}
        rows.append(row)
        print(c[0], c[5], "ok" if row["ok"] else ("-" if row["ok"] is None else "FAIL"), r["status"], row.get("model"), "|", c[4][:50], "| recon:",
              row["recon"][:60], "|", row["answer"][:110].replace("\n", " "), flush=True)
        out.write_text(json.dumps({"stamp": stamp, "spent_usd": round(D.spent, 4), "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    summ = {}
    for g in sorted({r["group"] for r in rows}):
        rs = [r for r in rows if r["group"] == g]
        ans = [r for r in rs if r["expect"] == "answer"]
        sil = [r for r in rs if r["expect"] == "silent"]
        summ[g] = {"n": len(rs), "answer_n": len(ans), "understood": sum(bool(r.get("understood")) for r in ans), "right": sum(bool(r.get("right")) for r in ans),
                   "silent_n": len(sil), "quiet_ok": sum(bool(r["ok"]) for r in sil), "either_n": sum(r["expect"] == "either" for r in rs),
                   "errors": sum(r["status"] != 200 for r in rs)}
    out.write_text(json.dumps({"stamp": stamp, "spent_usd": round(D.spent, 4), "summary": summ, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(summ, indent=1))
    print("spent", round(D.spent, 4), "->", out)


if __name__ == "__main__":
    main()
