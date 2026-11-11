#!/usr/bin/env python3
"""Oscar QA, O39: K37 "Mina svar" live. (1) /answer in Provläge (mode tutor, persona tutor) with the exam's saved
answers from scripts/qa/o39_k37_cases.json (written before Kevin's code): did done.saved_answer pick the expected
saved answer, none when expect is null (a FALSE HIT is the thing to avoid), and is the text word for word?
(2) /my-answers proofread on the spelling cases (fix errors, never touch subject terms), suggest x2, compress x1 on an
invented transcript. No ElevenLabs, no Scribe. --cap stops at a cost.
  python -I scripts/qa/o39_k37_live.py [--only hit,near] [--cap 0.40]   -> reports/qa/data/<stamp>-o39-live.json"""
import argparse, datetime as dt, importlib.util, json, pathlib, sys, time

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o15", ROOT / "scripts/qa/o15.py")
O = importlib.util.module_from_spec(spec)
spec.loader.exec_module(O)
D = O.D
B = O.load("bank", "scripts/qa/o15_bank.py")
C = json.loads((ROOT / "scripts/qa/o39_k37_cases.json").read_text(encoding="utf-8"))
PROF = {"bio": B.PROFILES["bio9"], "hist": B.PROFILES["hist9"]}

INVENTED_TRANSCRIPT = ("Okej allihop, tyst nu. Så, fotosyntesen, eh, det är alltså när växterna tar koldioxid från luften och "
                       "vatten från rötterna, och med solljuset gör de glukos, socker alltså. Och syre släpps ut. Det händer i "
                       "kloroplasterna, i det gröna, klorofyllet. Kalle, lägg undan mobilen. Ja, och glukosen använder växten "
                       "sen som energi eller bygger stärkelse av. Okej, det var det, nästa gång tar vi cellandningen.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--cap", type=float, default=0.40)
    ap.add_argument("--skip-my-answers", action="store_true")
    a = ap.parse_args()
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    out = ROOT / "reports/qa/data" / f"{stamp}-o39-live.json"
    tok, n, rows, extra = O.signup(), 0, [], []

    def save():
        out.write_text(json.dumps({"stamp": stamp, "spent_usd": round(D.spent, 4), "rows": rows, "my_answers": extra},
                                  ensure_ascii=False, indent=1), encoding="utf-8")

    for c in C["cases"]:
        if a.only and c["group"] not in a.only.split(","):
            continue
        if D.spent >= a.cap:
            print("budget cap", D.spent, flush=True)
            break
        if n >= 30:
            tok, n = O.signup(), 0
        saved = C["other_user_saved"][c["exam"]] if c["group"] == "other_user" else C["saved"][c["exam"]]
        body = {"fragment": c["ask"], "mode": "tutor", "language": "sv", "persona": "tutor", "persona_setup": PROF[c["exam"]],
                "context": {}, "saved_answers": saved}
        r = D.ask(tok, body)
        n += 1
        if r["status"] == 429:
            time.sleep(int(r.get("retry_after") or 30) + 1)
            r = D.ask(tok, body)
        done = r.get("done") or {}
        sa = done.get("saved_answer")
        got = sa.get("id") if sa else None
        exp_a = next((s["a"] for s in saved if s["id"] == got), None)
        row = {"id": c["id"], "group": c["group"], "exam": c["exam"], "ask": c["ask"], "expect": c["expect"], "got": got,
               "via": sa.get("via") if sa else None, "verbatim": (sa.get("text") == exp_a) if sa else None,
               "spoken": (r.get("text") or "")[:600], "answered": done.get("answered"), "status": r["status"],
               "model": (done.get("usage") or {}).get("model"), "ms": r.get("ms"), "cost": round(r.get("cost", 0) or 0, 5)}
        row["ok"] = got == c["expect"]
        row["false_hit"] = got is not None and got != c["expect"]
        rows.append(row)
        print(c["id"], "ok" if row["ok"] else ("FALSE HIT" if row["false_hit"] else "MISS"), r["status"], got, row["via"], "|", c["ask"][:50],
              "|", row["spoken"][:80].replace("\n", " "), flush=True)
        save()

    if not a.skip_my_answers and D.spent < a.cap:
        def my(body):
            time.sleep(6.5)  # /my-answers allows 10 per minute
            o = D.call("POST", "/functions/v1/my-answers", body, tok)
            j = D.jbody(o) or {}
            u = j.get("usage") or {}
            return o["status"], j, u
        for kind in ("fix", "keep"):
            for s in C["spelling"][kind]:
                st, j, u = my({"action": "proofread", "q": "Vad är det?", "a": s["in"]})
                outa = j.get("a") or ""
                ok = st == 200 and all(w in outa for w in s["must_contain"]) and (kind == "fix" or outa == s["in"])
                extra.append({"action": "proofread", "kind": kind, "in": s["in"], "out": outa, "changed": j.get("changed"), "status": st, "ok": ok, "usage": u})
                print("proofread", kind, "ok" if ok else "FAIL", st, "|", outa[:100], flush=True)
                save()
        for q, ex in (("vad är fotosyntes", "bio"), ("varför bröt forsta världskriget ut", "hist")):
            st, j, u = my({"action": "suggest", "q": q, "subject": "Biologi" if ex == "bio" else "Historia", "grade": "Åk 9"})
            extra.append({"action": "suggest", "q_in": q, "q": j.get("q"), "answer": j.get("answer"), "status": st, "usage": u})
            print("suggest", st, j.get("q"), "|", (j.get("answer") or "")[:120], flush=True)
            save()
        st, j, u = my({"action": "compress", "transcript": INVENTED_TRANSCRIPT, "subject": "Biologi"})
        extra.append({"action": "compress", "transcript": INVENTED_TRANSCRIPT, "q": j.get("q"), "answer": j.get("answer"), "status": st, "usage": u})
        print("compress", st, j.get("q"), "|", j.get("answer"), flush=True)
        st, j, u = my({"action": "compress", "transcript": "eh. okej. hallå? nej men sluta. haha. ok hej då", "subject": "Biologi"})
        extra.append({"action": "compress", "transcript": "(bara sidoprat)", "q": j.get("q"), "answer": j.get("answer"), "status": st, "usage": u})
        print("compress side-talk", st, repr(j.get("q")), repr(j.get("answer")), flush=True)
        save()

    g = {}
    for r in rows:
        k = g.setdefault(r["group"], {"n": 0, "ok": 0, "false_hit": 0})
        k["n"] += 1; k["ok"] += r["ok"]; k["false_hit"] += r["false_hit"]
    print(json.dumps(g), "spent", round(D.spent, 4), "->", out)


if __name__ == "__main__":
    main()
