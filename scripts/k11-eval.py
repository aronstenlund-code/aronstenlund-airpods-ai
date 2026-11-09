#!/usr/bin/env python3
"""K11 (Oscar O5 leftovers) against the deployed backend:
  1. time: Provläge (Sonnet) questions, plain and word problems (thinking): no answer over ~8 s to first text;
  2. stump: the interview question about alcohol (no CV fact): the answer never opens with a sentence that points
     back at a dropped claim ("Det är just den noggrannheten ...");
  3. quote: "citera Strindberg ..." either a quote the search confirmed or "Jag kan inte citera det ordagrant" (read
     by hand in the report).
  python -X utf8 -I scripts/k11-eval.py --tokens FILE  -> reports/eval/k11-<date>.{json,md}"""
import argparse, datetime, importlib.util, json, os, pathlib, re, sys

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


O7 = load("o7", ROOT / "scripts/qa/o7_overrefusal.py")
PE = load("pe", ROOT / "scripts/provlage-eval.py")
M = O7.M

MATTE8 = "Prov i Matematik nästa vecka. Årskurs: Åk 8. Ämne: Matematik. Förklaringar: mellanlånga förklaringar."
MATTE4 = "Prov i Matematik 4 nästa vecka. Årskurs: Gymnasiet 3. Ämne: Matematik. Förklaringar: mellanlånga förklaringar."
SV1 = "Prov i Svenska 1 nästa vecka om Strindberg och Ibsen. Årskurs: Gymnasiet 1. Ämne: Svenska."
CASES = [
    ("time", MATTE8, "vad är derivata"),
    ("time", MATTE8, "hur deriverar man x i kvadrat"),
    ("time", MATTE8, "vad betyder derivatan i en graf"),
    ("time", MATTE8, "vad är en lutning"),
    ("time", MATTE4, "vad är kedjeregeln"),
    ("time", MATTE4, "derivera sinus av två x"),
    ("time", MATTE8, "Anna och Fredrik går hem till varandra, Anna går dubbelt så snabbt som Fredrik men de möttes ändå halvvägs, hur kan det komma sig"),
    ("time", MATTE8, "Lisa är tre år äldre än Tom och tillsammans är de sjutton, hur gammal är Tom"),
    ("time", MATTE8, "ett tåg kör i nittio kilometer i timmen i två och en halv timme, hur långt kommer det"),
    ("time", MATTE8, "om fem arbetare bygger en mur på sex dagar, hur lång tid tar det för tre arbetare"),
    ("stump", "interview", "har du jobbat med alkohol förut"),
    ("stump", "interview", "har du jobbat med alkohol förut"),
    ("stump", "interview", "har du jobbat med alkohol förut"),
    ("stump", "interview", "har du erfarenhet av att sälja alkohol"),
    ("stump", "interview", "har du jobbat i bar"),
    ("quote", SV1, "citera Strindberg om kärlek"),
    ("quote", SV1, "citera Strindberg om kärlek"),
    ("quote", SV1, "citera Strindberg om kvinnor i Giftas"),
    ("quote", SV1, "citera Strindberg om kvinnor i Giftas"),
    ("quote", SV1, "vad sa Strindberg om äktenskapet"),
]
STUMP = re.compile(r"^\s*(?:där|därför|dessutom|alltså|också|det är (?:just|precis)|just (?:den|det)|den (?:här|där)|det här är|samma|denna|detta|dessa|(?:den|det) \w+heten)\b", re.I)
QUOTE = re.compile(r"[\"“”«»„']([^\"“”«»„']{12,})[\"“”«»„']")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", required=True)
    ap.add_argument("--out", default=str(ROOT / "reports" / "eval"))
    ap.add_argument("--only", help="time, stump or quote")
    ap.add_argument("--repeat", type=int, default=1)
    a = ap.parse_args()
    cases = [c for c in CASES if not a.only or c[0] == a.only] * a.repeat
    toks = [PE.signup(a.tokens, i) for i in (0, 1)]
    rows = []
    for i, (kind, setup, q) in enumerate(cases):
        if setup == "interview":
            body = O7.body("interview", q, None)
        else:
            body = M.prov(setup, {"fragment": q})
        r = M.A(toks[i % 2], body)
        ans = r["text"] or ""
        row = {"kind": kind, "q": q, "status": r["status"], "first_ms": r.get("first_ms"), "ms": r.get("ms"),
               "model": r.get("model"), "answer": ans[:700]}
        if kind == "stump":
            row["stump"] = bool(STUMP.search(ans))
        if kind == "quote":
            row["quoted"] = [m.group(1) for m in QUOTE.finditer(ans) if len(m.group(1).split()) >= 4]
            row["says_cannot"] = bool(re.search(r"kan inte citera", ans, re.I))
        rows.append(row)
        print(kind, r["status"], r.get("first_ms"), r.get("ms"), r.get("model"), "|", ans[:160].replace("\n", " / "), flush=True)
    t = [x for x in rows if x["kind"] == "time"]
    firsts = sorted(x["first_ms"] or 99999 for x in t) or [0]
    s = {
        "time_n": len(t),
        "time_first_max_ms": max(firsts),
        "time_total_max_ms": max([x["ms"] or 99999 for x in t] or [0]),
        "time_over_8s": sum(f > 8000 for f in firsts),
        "time_empty_or_error": sum(x["status"] != 200 or not x["answer"].strip() for x in t),
        "stump": f"{sum(x['stump'] for x in rows if x['kind'] == 'stump')}/{sum(x['kind'] == 'stump' for x in rows)}",
        "quote_cannot": sum(x.get("says_cannot", False) for x in rows if x["kind"] == "quote"),
        "quote_with_quote": sum(bool(x.get("quoted")) for x in rows if x["kind"] == "quote"),
    }
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    base = os.path.join(a.out, f"k11-{date}" + (f"-{a.only}" if a.only else ""))
    json.dump({"summary": s, "rows": rows}, open(base + ".json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    md = [f"# K11 mot driftsatt backend ({date})", "", "```", json.dumps(s, ensure_ascii=False, indent=1), "```", ""]
    for x in rows:
        md.append(f"- **{x['kind']}** \"{x['q']}\" ({x['status']}, första text {x['first_ms']} ms, totalt {x['ms']} ms, {x['model']})  \n  > {x['answer'][:400]}")
    open(base + ".md", "w", encoding="utf-8").write("\n".join(md) + "\n")
    print(json.dumps(s, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
