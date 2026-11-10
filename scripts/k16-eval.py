#!/usr/bin/env python3
"""K16 (owner 2026-11-09 21:58: search instead of inventing, never change your mind without a reason) against the
deployed backend, Frågor with push-to-talk:
  A. 10 recipes and instructions: searched (source in `done`), amounts and steps only from the source (read by hand);
  B. 10 follow-up chains of 3 steps: recent_qa carries the earlier answers and their source; no contradiction
     (numbers of step 1 kept unless corrected; read by hand);
  C. 10 questions the model cannot know for sure: it searches or says it does not know, never a bare guess.
Cost per answer with search is reported.
  python -X utf8 -I scripts/k16-eval.py --tokens FILE -> reports/eval/k16-<date>.{json,md}"""
import argparse, datetime, importlib.util, json, os, pathlib, re, sys, time

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


PE = load("pe", ROOT / "scripts/provlage-eval.py")
D = load("demo", ROOT / "scripts/qa/demo.py")

A = ["recept på pannkakor", "hur mycket mjöl i en kladdkaka", "recept på kanelbullar", "hur länge ska en hel kyckling i ugnen",
     "hur gör man köttbullar", "hur återställer man en iphone till fabriksinställningar", "hur parkopplar man airpods med en iphone",
     "hur byter man batteri i en brandvarnare", "steg för steg hur man startar om en router", "hur mycket vatten till ett deciliter ris"]
B = [
    ["recept på pannkakor", "hur mycket mjölk ska jag ha", "kan jag byta vetemjölet mot havremjöl"],
    ["recept på kladdkaka", "hur länge i ugnen", "vilken temperatur"],
    ["hur kokar man ägg", "hur länge för löskokt", "och hårdkokt?"],
    ["recept på kanelbullar", "hur länge ska degen jäsa", "kan jag frysa dem"],
    ["hur återställer man en iphone", "försvinner mina bilder då", "och sen?"],
    ["hur parkopplar man airpods med en android", "vad gör jag om lampan inte blinkar", "och om det ändå inte går?"],
    ["hur gör man köttbullar", "hur mycket ströbröd", "kan jag ugnsbaka dem istället"],
    ["recept på våfflor", "hur många blir det", "kan jag använda havremjölk"],
    ["hur byter man batteri i en brandvarnare", "vilket batteri ska jag köpa", "hur ofta ska man testa den"],
    ["hur lång tid tar det att koka potatis", "och mandelpotatis?", "ska jag salta vattnet"],
]
C = ["hur många invånare har Ockelbo kommun", "vad heter rektorn på KTH", "hur lång är Ölandsbron i meter",
     "vilket år grundades IFK Kalmar", "vad är öppettiderna för Moderna museet på måndagar", "hur många kalorier är det i en semla",
     "vilken åldersgräns gäller för att köpa energidryck i Sverige", "hur hög är Kebnekaises sydtopp",
     "vem är kommunstyrelsens ordförande i Ludvika", "hur många mil är det mellan Umeå och Luleå"]
NOT_SURE = re.compile(r"vet inte säkert|inte säker|vet inte|kan inte (?:säga|svara) säkert|kolla (?:på|hos)|kontrollera", re.I)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", required=True)
    ap.add_argument("--only", help="A, B or C")
    ap.add_argument("--out", default=str(ROOT / "reports" / "eval"))
    ap.add_argument("--slots", default="0,1,2,3", help="token slots (web: 20 searches per user and day)")
    ap.add_argument("--pause", type=float, default=2.0, help="seconds after each call (web: 3/min per user)")
    a = ap.parse_args()
    toks = [PE.signup(a.tokens, int(i)) for i in a.slots.split(",")]  # web: 3/min and 20/day per user
    n = [0]

    def ask(frag, recent):
        tok = toks[n[0] % len(toks)]
        n[0] += 1
        r = D.ask(tok, {"fragment": frag, "mode": "push_to_talk", "language": "sv", "context": {"recent_qa": recent}})
        time.sleep(a.pause)
        done = r.get("done") or {}
        u = done.get("usage") or {}
        return {"q": frag, "status": r["status"], "answer": r.get("text", ""), "source": done.get("source"),
                "web_searches": u.get("web_searches"), "model": u.get("model"), "cost": round(r.get("cost") or 0, 5),
                "first_ms": r.get("first_ms"), "ms": r.get("ms")}

    rows = []
    if a.only in (None, "A"):
        for q in A:
            x = ask(q, [])
            x["part"] = "A"
            rows.append(x)
            print("A", x["status"], x["source"], x["web_searches"], x["cost"], "|", x["answer"][:150].replace("\n", " / "), flush=True)
    if a.only in (None, "B"):
        for ci, chain in enumerate(B):
            recent = []
            for si, q in enumerate(chain):
                x = ask(q, recent)
                x.update(part="B", chain=ci, step=si)
                rows.append(x)
                print("B", ci, si, x["status"], x["source"], x["web_searches"], "|", x["answer"][:150].replace("\n", " / "), flush=True)
                recent = recent + [{"q": q, "a": x["answer"][:1200], **({"source": x["source"]} if x["source"] else {})}]
    if a.only in (None, "C"):
        for q in C:
            x = ask(q, [])
            x["part"] = "C"
            x["searched"] = bool(x["source"]) or (x["web_searches"] or 0) > 0
            x["says_not_sure"] = bool(NOT_SURE.search(x["answer"]))
            rows.append(x)
            print("C", x["status"], x["source"], x["web_searches"], x["says_not_sure"], "|", x["answer"][:150].replace("\n", " / "), flush=True)
    web = [x for x in rows if (x["web_searches"] or 0) > 0]
    s = {
        "A_searched": f"{sum(bool(x['source']) or (x['web_searches'] or 0) > 0 for x in rows if x['part'] == 'A')}/{sum(x['part'] == 'A' for x in rows)}",
        "B_steps_searched": f"{sum(bool(x['source']) or (x['web_searches'] or 0) > 0 for x in rows if x['part'] == 'B')}/{sum(x['part'] == 'B' for x in rows)}",
        "C_searched_or_not_sure": f"{sum(x.get('searched') or x.get('says_not_sure') for x in rows if x['part'] == 'C')}/{sum(x['part'] == 'C' for x in rows)}",
        "errors": sum(x["status"] != 200 or not x["answer"].strip() for x in rows),
        "cost_per_web_answer_usd": round(sum(x["cost"] for x in web) / max(1, len(web)), 4),
        "cost_total_usd": round(sum(x["cost"] for x in rows), 3),
    }
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    base = os.path.join(a.out, f"k16-{date}" + (f"-{a.only}" if a.only else ""))
    json.dump({"summary": s, "rows": rows}, open(base + ".json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    md = [f"# K16 mot driftsatt backend ({date})", "", "```", json.dumps(s, ensure_ascii=False, indent=1), "```", ""]
    for x in rows:
        tag = x["part"] + (f" kedja {x['chain'] + 1} steg {x['step'] + 1}" if x["part"] == "B" else "")
        md.append(f"- **{tag}** \"{x['q']}\" ({x['status']}, källa {x['source']}, sökningar {x['web_searches']}, {x['cost']} USD)  \n  > {x['answer'][:500]}")
    open(base + ".md", "w", encoding="utf-8").write("\n".join(md) + "\n")
    print(json.dumps(s, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
