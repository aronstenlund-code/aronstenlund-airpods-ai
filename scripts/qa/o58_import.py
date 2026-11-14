"""O58 (2): 20 varianter av ett ChatGPT-svar mot `/drill` action `import_text` (K58, D169).
Skrivet av Oscar (QA). Påhittat innehåll (vulkaner, 6 frågor), aldrig elevtext. Ingen Claude, ingen ElevenLabs.
Krav (oscar.md O58): rätt antal frågor, inget tappas (hela svaret finns kvar ord för ord), tydliga fel.
För varje variant kollas:
  count     antal frågor == väntat
  questions varje väntad fråga finns (utan markdown och numrering)
  full      det långa svaret har exakt samma ord som svaret i texten (inget kortat, inget tillagt)
  short     det korta svaret är första meningen i svaret, och det långa börjar med det (D145)
  clean     inga markdowntecken kvar i fråga eller svar
  errors    skipped/warnings har en svensk orsak och ett radnummer; 422 import_unreadable när inget går att läsa
  python -I -X utf8 scripts/qa/o58_import.py
Resultat: reports/qa/data/<tid>-o58-import.json"""
import datetime as dt, json, pathlib, re, sys, time, urllib.error, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # publik nyckel, finns i appen

P = [
    ("Vad är magma?",
     "Magma är smält berg under jordytan som består av mineraler, gaser och vatten. När magman når ytan kallas den lava. "
     "Den bildas där temperaturen är så hög att berget smälter, till exempel där en platta trycks ner under en annan. "
     "Magmans innehåll av kiseldioxid avgör hur trögflytande den är, och det påverkar hur vulkanen får utbrott."),
    ("Varför får vissa vulkaner explosiva utbrott?",
     "Vissa vulkaner får explosiva utbrott eftersom deras magma är trögflytande och håller kvar gaserna tills trycket blir "
     "för stort. Det liknar en skakad läskflaska som öppnas. Sådan magma har mycket kiseldioxid, t.ex. vid Vesuvius. "
     "Tunnflytande magma släpper i stället ut gaserna lugnt, och då rinner lavan ut i strömmar som på Hawaii."),
    ("Hur bildas en sköldvulkan?",
     "En sköldvulkan bildas när tunnflytande lava rinner ut gång på gång och stelnar i breda, flacka lager. Lavan hinner "
     "rinna långt, ofta flera kilometer, innan den stelnar. Därför blir vulkanen bred som en sköld som ligger på marken. "
     "Mauna Loa på Hawaii är ett exempel, och den är ca 120 km bred vid basen."),
    ("Var finns de flesta vulkaner?",
     "De flesta vulkaner finns längs plattgränserna, särskilt runt Stilla havet i den så kallade eldringen. Där trycks "
     "havsplattor ner under andra plattor och smälter. Vulkaner finns också vid heta fläckar mitt på en platta, som "
     "Hawaii, och där plattor glider isär, som på Island."),
    ("Hur kan ett utbrott påverka klimatet?",
     "Ett stort utbrott kan sänka temperaturen på jorden i några år eftersom svavelgaser bildar små droppar som "
     "reflekterar solljus. Efter Pinatubo 1991 sjönk medeltemperaturen med ungefär 0,5 grader. Vulkaner släpper också "
     "ut koldioxid, men mycket mindre än människan gör varje år."),
    ("Hur varnar forskare för utbrott?",
     "Forskare varnar för utbrott genom att mäta jordskalv, att marken höjer sig och att mer gas kommer ut ur vulkanen. "
     "Små skalv visar att magma rör sig uppåt. Satelliter kan se att berget sväller några centimeter. Ingen kan säga exakt "
     "när ett utbrott kommer, men varningarna har räddat många liv, bl.a. vid Pinatubo."),
]
LONG = ("Lavan stelnar till basalt när den svalnar. " + " ".join(
    f"Mening {i} om hur lava svalnar och bildar sten med kristaller som syns i mikroskop." for i in range(1, 45)))


def std(pairs, qf="Fråga: {q}", af="Svar: {a}", sep="\n\n", mid="\n"):
    return sep.join(qf.format(q=q, i=i + 1) + mid + af.format(a=a, i=i + 1) for i, (q, a) in enumerate(pairs))


def variants():
    v = []
    add = lambda name, text, exp, pairs=P, status=200, note="": v.append(
        {"name": name, "text": text, "count": exp, "pairs": pairs, "status": status, "note": note})
    add("01 ren", std(P), 6)
    add("02 inledning och avslutning", "Självklart! Här är 6 provfrågor om vulkaner med svar:\n\n" + std(P)
        + "\n\nLycka till på provet! Vill du att jag gör fler frågor?", 6)
    add("03 fetstil på etiketterna", std(P, "**Fråga:** {q}", "**Svar:** {a}"), 6)
    add("04 numrering", std(P, "{i}. Fråga: {q}"), 6)
    add("05 rubriker, utan tom rad före", "\n".join(f"### Fråga {i + 1}\nFråga: {q}\nSvar: {a}" for i, (q, a) in enumerate(P)), 6,
        note="rubriken kommer direkt efter förra svaret")
    add("06 Fråga 1: / Svar 1:", std(P, "Fråga {i}: {q}", "Svar {i}: {a}"), 6)
    add("07 en fråga utan svar", "\n\n".join(f"Fråga: {q}" + ("" if i == 2 else f"\nSvar: {a}") for i, (q, a) in enumerate(P)), 5,
        pairs=[p for i, p in enumerate(P) if i != 2], note="ska synas i skipped")
    add("08 extra blankrader", std(P, sep="\n\n\n\n", mid="\n\n") + "\n\n\n", 6, note="tom rad också mellan fråga och svar")
    add("09 inga blankrader", std(P, sep="\n"), 6)
    add("10 CRLF", std(P).replace("\n", "\r\n"), 6)
    add("11 svaret radbrutet", std([(q, a.replace(". ", ".\n")) for q, a in P]), 6, pairs=P)
    add("12 svaret i två stycken", std([(q, a.replace(". ", ".\n\n", 1)) for q, a in P]), 6, pairs=P,
        note="tom rad inne i svaret")
    add("13 gemener och versaler", "\n\n".join((f"fråga: {q}\nsvar: {a}" if i % 2 else f"FRÅGA: {q}\nSVAR: {a}") for i, (q, a) in enumerate(P)), 6)
    add("14 frågan utan etikett, fetstil och numrerad", "\n\n".join(f"**{i + 1}. {q}**\nSvar: {a}" for i, (q, a) in enumerate(P)), 6,
        note="ChatGPT glömmer Fråga:; svaren får inte tappas tyst")
    add("15 punktlista", "\n".join(f"- Fråga: {q}\n  Svar: {a}" if i % 2 else f"• Fråga: {q}\n• Svar: {a}" for i, (q, a) in enumerate(P)), 6)
    add("16 kodblock, indrag, tabb och hårt mellanslag", "```\n" + "\n\n".join(f"\tFråga: {q}\n    Svar: {a}" for q, a in P) + "\n```", 6)
    spec = [("Vad bildas när vatten och CO₂ löses?", "Det bildas kolsyra, H₂CO₃, som gör vattnet ½ grad surare → pH sjunker. "
             "Ett ”surt” vatten 🌋 kan lösa upp kalksten, t.ex. i grottor, och det tar 3,5 år eller mer.")] + P[1:]
    add("17 specialtecken och förkortningar", std(spec), 6, pairs=spec)
    lp = P[:5] + [("Vad händer när lava svalnar?", LONG)]
    add("18 mycket långt svar", std(lp), 6, pairs=lp, note=f"sista svaret är {len(LONG)} tecken")
    add("19 samma fråga två gånger", std(P + [P[0]]), 7, pairs=P + [P[0]], note="dubbletten: ska den varnas?")
    add("20 inget går att läsa (engelska etiketter och skräp)",
        "Sure! Here are your questions:\n\n" + std(P[:3], "Q: {q}", "A: {a}") + "\n\nSvar: ett svar utan fråga", 0, pairs=[], status=422)
    return v


W = re.compile(r"[\wåäöÅÄÖ₂½,.-]+", re.U)


def norm(s):
    s = re.sub(r"\*\*|__|`|#+\s", "", s)
    return [w.strip(".,").lower() for w in W.findall(s) if w.strip(".,")]


def first_sentence(a):
    m = re.search(r"(?<!t\.ex)(?<!bl\.a)(?<!\bca)[.!?](?=\s+[A-ZÅÄÖ0-9])", a)
    return a[: m.end()] if m else a


def token():
    req = urllib.request.Request(URL + "/auth/v1/signup", data=b"{}", method="POST",
                                 headers={"apikey": KEY, "content-type": "application/json"})
    return json.load(urllib.request.urlopen(req, timeout=30))["access_token"]


def call(text, tok):
    req = urllib.request.Request(URL + "/functions/v1/drill", data=json.dumps({"action": "import_text", "text": text}).encode(),
                                 method="POST", headers={"apikey": KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        b = e.read().decode("utf-8", "replace")
        try:
            return e.code, json.loads(b)
        except ValueError:
            return e.code, {"raw": b[:300]}


def check(v, status, d):
    items = d.get("items", [])
    res = {"status_ok": status == v["status"], "count_ok": len(items) == v["count"]}
    by_q = {}
    for it in items:
        by_q.setdefault(" ".join(norm(it["question"])), []).append(it)
    missing, not_full, bad_short, d145, dirty = [], [], [], 0, []
    for q, a in v["pairs"]:
        cands = by_q.get(" ".join(norm(q)), [])
        if not cands:
            missing.append(q)
            continue
        it = cands[0]
        if norm(it["long"]) != norm(a):
            na, nl = norm(a), norm(it["long"])
            not_full.append({"q": q, "words_expected": len(na), "words_got": len(nl),
                             "lost": [w for w in na if w not in nl][:12], "extra": [w for w in nl if w not in na][:12]})
        if norm(it["short"]) != norm(first_sentence(a)):
            bad_short.append({"q": q, "short": it["short"], "expected": first_sentence(a)})
        d145 += it["long"].startswith(it["short"].rstrip("."))
        if re.search(r"\*\*|__|`|^#|\t", it["question"] + it["long"]):
            dirty.append(q)
    probs = d.get("skipped", []) + d.get("warnings", [])
    res.update({"missing": missing, "not_full": not_full, "bad_short": bad_short, "dirty": dirty,
                "d145": f"{d145}/{len(items)}", "skipped": d.get("skipped", []), "warnings": d.get("warnings", []),
                "error": d.get("error"),
                "reasons_ok": all(p.get("reason") and isinstance(p.get("line"), int) for p in probs)})
    res["ok"] = (res["status_ok"] and res["count_ok"] and not missing and not not_full and not bad_short and not dirty
                 and res["reasons_ok"] and (status != 422 or (d.get("error") or {}).get("code") == "import_unreadable"))
    return res


def main():
    tok = token()
    rows = []
    for v in variants():
        t0 = time.time()
        status, d = call(v["text"], tok)
        r = {"name": v["name"], "note": v["note"], "http": status, "seconds": round(time.time() - t0, 2),
             "count": len(d.get("items", [])), "expected": v["count"], **check(v, status, d), "text": v["text"], "response": d}
        rows.append(r)
        extra = "; ".join(x for x in [
            f"saknas {len(r['missing'])}" if r["missing"] else "", f"ej hela {len(r['not_full'])}" if r["not_full"] else "",
            f"kort fel {len(r['bad_short'])}" if r["bad_short"] else "", f"markdown {len(r['dirty'])}" if r["dirty"] else "",
            f"skipped {len(r['skipped'])}" if r["skipped"] else "", f"warnings {len(r['warnings'])}" if r["warnings"] else ""] if x)
        print(f"{'ok ' if r['ok'] else 'BAD'} {v['name']:48s} http {status} {r['count']}/{v['count']} {extra}", flush=True)
        time.sleep(3.2)  # gränsen är 20 per minut
    summ = {"ok": sum(r["ok"] for r in rows), "n": len(rows), "count_ok": sum(r["count_ok"] for r in rows),
            "not_full": sum(bool(r["not_full"]) for r in rows), "missing": sum(bool(r["missing"]) for r in rows)}
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o58-import.json")
    out.write_text(json.dumps({"summary": summ, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(summ, ensure_ascii=False), "->", out)


if __name__ == "__main__":
    main()
