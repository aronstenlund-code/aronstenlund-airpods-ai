#!/usr/bin/env python3
"""Oscar QA, O51: K42 (Arons telefontest 18:58) live in Standardläge (mode auto), cases in scripts/qa/o51_k42_cases.json
(written before Kevin's code). Grading in code, read the JSON by hand before reporting:
  name       ok = "earmind" in the answer
  facts      ok = one of the expected spellings in the answer
  length     ok = words within ±20 % (words), <= max_words, >= min_words, or sentence count equal (sentences)
  complaint  ok = no promise pattern and at most 45 words
  oneword    none: ok = no developed answer (< 20 words) and no app command; more: ok = a developed answer (>= 20 words)
  python -I scripts/qa/o51_k42_live.py --tag fore [--only name,facts]  -> reports/qa/data/<stamp>-o51-k42-<tag>.json"""
import argparse, datetime as dt, importlib.util, json, pathlib, re, sys, time
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o41", ROOT / "scripts/qa/o41_k36_live.py"); M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
C = json.loads((ROOT / "scripts/qa/o51_k42_cases.json").read_text(encoding="utf-8"))
import urllib.request, urllib.error


def ask(tok, frag, recent=None, stt=None):
    body = {"fragment": frag, "mode": "auto", "language": "sv", "context": {"recent_qa": recent or [], **(stt or {})}}
    req = urllib.request.Request(M.D.URL + "/functions/v1/answer", data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": M.D.KEY, "content-type": "application/json", "authorization": "Bearer " + tok})
    try:
        with urllib.request.urlopen(req, timeout=90) as x:
            text = x.read().decode()
    except urllib.error.HTTPError as e:
        return {"status": e.code, "said": "", "err": e.read().decode()[:200]}
    ev = []
    for f in text.split("\n\n"):
        e = [l[7:] for l in f.split("\n") if l.startswith("event: ")]; d = [l[6:] for l in f.split("\n") if l.startswith("data: ")]
        if e and d:
            try:
                ev.append((e[0], json.loads(d[0])))
            except ValueError:
                pass
    said = "".join(d.get("text", "") for n, d in ev if n == "delta")
    done = next((d for n, d in ev if n == "done"), {}) or {}
    meta = next((d for n, d in ev if n == "meta"), {}) or {}
    return {"status": 200, "said": said, "done_keys": sorted(done.keys()), "app_command": meta.get("app_command"), "more": done.get("more"),
            "continuation": (done.get("breakdown") or {}).get("continuation"), "usage": done.get("usage"), "qa_flag": done.get("qa_flag") or done.get("complaint")}


words = lambda s: len(re.findall(r"[\wåäöÅÄÖéü]+", s))
sentences = lambda s: len([x for x in re.split(r"(?<=[.!?])\s+", s.strip()) if re.search(r"\w", x)])


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--tag", required=True); ap.add_argument("--only", default=""); a = ap.parse_args()
    groups = a.only.split(",") if a.only else ["name", "facts", "length", "complaint", "oneword"]
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + f"-o51-k42-{a.tag}.json")
    tok, n, rows = M.O.signup(), 0, []

    def run(group, frag, grade, recent=None, extra=None, stt=None):
        nonlocal tok, n
        if n >= 30:
            tok, n = M.O.signup(), 0
        time.sleep(3.2)
        r = ask(tok, frag, recent, stt)
        n += 1
        ok, note = grade(r["said"], r)
        rows.append({"group": group, "fragment": frag, **(extra or {}), "stt": stt, "said": r["said"], "words": words(r["said"]), "ok": ok, "note": note,
                     **{k: r.get(k) for k in ("status", "app_command", "continuation", "qa_flag", "done_keys", "err")}})
        print(group, "OK " if ok else "BAD", "|", frag, "|", note, "|", r["said"][:90].replace("\n", " "), flush=True)
        out.write_text(json.dumps({"tag": a.tag, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")

    if "name" in groups:
        for f in C["name"]:
            run("name", f, lambda s, r: ("earmind" in s.lower(), "name" if "earmind" in s.lower() else "no Earmind"))
    if "facts" in groups:
        for f, exp in C["facts"]:
            alts = exp.lower().split("|")
            run("facts", f, lambda s, r, alts=alts: (any(x in s.lower() for x in alts), "" if any(x in s.lower() for x in alts) else f"want {alts[0]}"), extra={"expect": exp})
        pass
    if "length" in groups:
        for f, spec_ in C["length"]:
            def g(s, r, sp=spec_):
                w, se = words(s), sentences(s)
                if "words" in sp:
                    return abs(w - sp["words"]) <= 0.2 * sp["words"], f"{w} words (want {sp['words']}±20%)"
                if "max_words" in sp:
                    return 0 < w <= sp["max_words"], f"{w} words (max {sp['max_words']})"
                if "min_words" in sp:
                    return w >= sp["min_words"], f"{w} words (min {sp['min_words']})"
                return se == sp["sentences"], f"{se} sentences (want {sp['sentences']})"
            run("length", f, g, extra={"spec": spec_})
    if "complaint" in groups:
        pats = C["complaint_promise_patterns"]
        for f in C["complaint"]:
            def g(s, r):
                hit = [p for p in pats if p in s.lower()]
                return (not hit and 0 < words(s) <= 45), (f"PROMISE {hit}" if hit else f"{words(s)} words")
            run("complaint", f, g)
    if "oneword" in groups:
        ow = C["oneword"]; prev = [ow["previous"]]
        for f in ow["none"]:
            run("oneword_none", f, lambda s, r: (words(s) < 20 and not r.get("app_command"), f"{words(s)} words, cmd {r.get('app_command')}"), recent=prev, stt={"stt_confidence": 0.9, "utterance_ms": 450})
        for f in ow["more"]:
            run("oneword_more", f, lambda s, r: (words(s) >= 20, f"{words(s)} words"), recent=prev, stt={"stt_confidence": 0.95, "utterance_ms": 750})
        # K42.5 (Aron's "jaha" heard as "utveckla"): the command word with low confidence and too short to be said = silence
        for f in ("utveckla", "berätta mer", "fortsätt", "utveckla det", "säg mer"):
            run("misheard_cmd", f, lambda s, r: (words(s) < 20 and not r.get("app_command"), f"{words(s)} words"), recent=prev, stt={"stt_confidence": 0.45, "utterance_ms": 280})
    summ = {}
    for g in sorted({r["group"] for r in rows}):
        rs = [r for r in rows if r["group"] == g]; summ[g] = f"{sum(r['ok'] for r in rs)}/{len(rs)}"
    d = json.loads(out.read_text(encoding="utf-8")); d["summary"] = summ; out.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(summ, ensure_ascii=False), "->", out)


if __name__ == "__main__":
    main()
