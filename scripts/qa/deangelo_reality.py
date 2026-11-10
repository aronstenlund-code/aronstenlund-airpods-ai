#!/usr/bin/env python3
"""Deangelo, 2026-11-10: verklighetstest av /answer med fall som riktiga användare säger.
  python -I scripts/qa/deangelo_reality.py -> reports/qa/data/2026-11-10-deangelo-reality.json
Frågor = mode auto (Haiku), Provläge = mode tutor + persona_setup (Sonnet). Budget 1,20 USD (stoppar vid 1,10).
expect: 'svar' = ska svara, 'tyst' = ska inte svara (inte riktat till Lumen / inte en fråga)."""
import importlib.util, json, pathlib, sys, time

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o8", ROOT / "scripts/qa/o8_latency.py")
O8 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(O8)
D = O8.D
CAP = 1.10

BIO = "Prov i Biologi nästa vecka. Årskurs: Åk 9. Ämne: Biologi. Förklaringar: mellanlånga förklaringar."
HIS = "Prov i Historia på fredag. Årskurs: Åk 8. Ämne: Historia. Förklaringar: korta förklaringar."
MAT = "Prov i Matematik nästa vecka. Årskurs: Gymnasiet 1. Ämne: Matematik. Förklaringar: mellanlånga förklaringar."
KEM = "Prov i Kemi om två veckor. Årskurs: Åk 9. Ämne: Kemi. Förklaringar: mellanlånga förklaringar."
ENG = "Prov i Engelska på måndag. Årskurs: Åk 9. Ämne: Engelska. Förklaringar: korta förklaringar."
SAM = "Prov i Samhällskunskap nästa vecka. Årskurs: Gymnasiet 1. Ämne: Samhällskunskap. Förklaringar: mellanlånga förklaringar."

# (grupp, läge, profil, fragment, förväntan)
F = "fragor"
P = "provlage"
CASES = [
    # 1. Bara nyckelord
    ("nyckelord", P, BIO, "fotosyntes", "svar"),
    ("nyckelord", P, BIO, "mitokondrien", "svar"),
    ("nyckelord", P, HIS, "franska revolutionen orsaker", "svar"),
    ("nyckelord", P, MAT, "pq formeln", "svar"),
    ("nyckelord", P, KEM, "jonbindning", "svar"),
    ("nyckelord", P, SAM, "riksdagen regeringen skillnad", "svar"),
    ("nyckelord", P, ENG, "past perfect", "svar"),
    ("nyckelord", F, None, "huvudstad australien", "svar"),
    ("nyckelord", F, None, "hur många gram är en deciliter mjöl", "svar"),
    ("nyckelord", F, None, "Gustav Vasa", "svar"),
    # 2. Halva, felformulerade frågor och omtag
    ("felformulerad", P, BIO, "vad är den där alltså grejen i cellen som gör energi typ", "svar"),
    ("felformulerad", P, BIO, "hur funkar det med alltså när växten tar in koldioxid och sen så blir det socker eller hur", "svar"),
    ("felformulerad", P, HIS, "varför började asså vad var det som gjorde att andra världskriget nej första världskriget började", "svar"),
    ("felformulerad", P, MAT, "om man har x i kvadrat plus fyra x minus fem och den ska vara noll hur gör man", "svar"),
    ("felformulerad", P, KEM, "vad är skillnaden på en atom och en jon eller är det samma", "svar"),
    ("felformulerad", F, None, "vem var det som uppfann den där telefonen", "svar"),
    ("felformulerad", F, None, "hur lång tid tar det att alltså koka ett ägg så det blir löst", "svar"),
    ("felformulerad", P, SAM, "demokrati alltså vad är det egentligen förutom att man röstar", "svar"),
    # 3. Hörfel som taligenkänning gör
    ("hörfel", P, BIO, "vad är foto syntes", "svar"),
    ("hörfel", P, BIO, "vad gör mito kondrierna", "svar"),
    ("hörfel", P, BIO, "vad är skillnaden mellan mit os och mej os", "svar"),
    ("hörfel", P, KEM, "vad är en kova lent bindning", "svar"),
    ("hörfel", P, HIS, "vad hände vid vest fahliska freden", "svar"),
    ("hörfel", P, MAT, "hur deriverar man e upp till två x", "svar"),
    ("hörfel", P, ENG, "när använder man present perfekt", "svar"),
    ("hörfel", F, None, "vem skrev röda rummen", "svar"),
    # 4. Talspråk, slang, svengelska
    ("slang", P, BIO, "asså vad e grejen me DNA typ", "svar"),
    ("slang", P, HIS, "bro vem var ens Napoleon", "svar"),
    ("slang", P, MAT, "jag fattar noll av derivata kan du explaina", "svar"),
    ("slang", P, KEM, "va e ph liksom", "svar"),
    ("slang", F, None, "yo vad e klockan i new york nu", "svar"),
    ("slang", F, None, "lowkey vad betyder ens rizz", "svar"),
    ("slang", P, ENG, "hur säger man typ jag har varit här i tre år på engelska", "svar"),
    ("slang", F, None, "vad e det för väder i stockholm imorgon", "svar"),
    # 5. Klassrum: lärarfrågor, kompisprat, inte frågor
    ("klassrum", F, None, "Okej allihop, sätt er ner nu så börjar vi.", "tyst"),
    ("klassrum", F, None, "Kan någon säga vad fotosyntes är?", "svar"),
    ("klassrum", F, None, "Vem har glömt sin bok idag?", "tyst"),
    ("klassrum", F, None, "Ska vi käka efter skolan eller?", "tyst"),
    ("klassrum", F, None, "Har du gjort läxan?", "tyst"),
    ("klassrum", F, None, "Ta fram era datorer och öppna classroom.", "tyst"),
    ("klassrum", F, None, "Vilket år började andra världskriget?", "svar"),
    ("klassrum", F, None, "Får jag gå på toa?", "tyst"),
    ("klassrum", F, None, "Mm.", "tyst"),
    ("klassrum", F, None, "Vad sa du?", "tyst"),
    ("klassrum", P, BIO, "hörru kan du sänka musiken lite", "tyst"),
    ("klassrum", P, BIO, "mamma jag kommer om fem minuter", "tyst"),
    # 6. Oväntat, kreativt, test av Lumen
    ("oväntat", F, None, "vad är meningen med livet", "svar"),
    ("oväntat", F, None, "Lumen är du en robot", "svar"),
    ("oväntat", F, None, "berätta ett skämt", "svar"),
    ("oväntat", F, None, "vad är två plus två och vem vann VM i fotboll 2022", "svar"),
    ("oväntat", P, BIO, "jag orkar inte plugga längre", "svar"),
    ("oväntat", P, BIO, "vad kommer på provet", "svar"),
    ("oväntat", P, MAT, "ge mig en svår fråga", "svar"),
    ("oväntat", P, HIS, "förklara som om jag var fem år varför romarriket föll", "svar"),
    ("oväntat", P, KEM, "jag vet inte ens vad jag ska fråga", "svar"),
    ("oväntat", F, None, "är det sant att man bara använder tio procent av hjärnan", "svar"),
    ("oväntat", F, None, "hur många ben har en spindel och hur många har en insekt", "svar"),
    ("oväntat", P, SAM, "är kapitalism bra eller dålig", "svar"),
    # 7. Engelska och blandspråk
    ("språk", F, None, "what is the capital of Canada", "svar"),
    ("språk", P, ENG, "what's the difference between affect and effect", "svar"),
    ("språk", P, BIO, "what does the cell membrane do", "svar"),
    # 8. Följdfrågor utan sammanhang (borde ta det som ny fråga eller vara tyst snarare än gissa vilt)
    ("ensamt", P, BIO, "och sen då", "tyst"),
    ("ensamt", P, BIO, "varför", "tyst"),
    ("ensamt", F, None, "den där", "tyst"),
]


def body(mode, profile, frag):
    if mode == F:
        return {"fragment": frag, "mode": "auto", "language": "sv", "context": {}}
    return {"fragment": frag, "mode": "tutor", "language": "sv", "persona": "tutor", "persona_setup": profile, "context": {}}


def main():
    out, spent, tok, n = [], 0.0, None, 99
    for grp, mode, prof, frag, exp in CASES:
        if spent > CAP:
            print("budget stop", spent)
            break
        if n >= 14:
            tok, n = D.signup(), 0
        n += 1
        a = O8.timed_answer(tok, body(mode, prof, frag))
        if a["status"] == 429:
            time.sleep(30)
            tok, n = D.signup(), 1
            a = O8.timed_answer(tok, body(mode, prof, frag))
        dn = a["done_ev"] or {}
        u = dn.get("usage") or {}
        pi, po = D.PRICES.get(u.get("model"), D.PRICES["claude-sonnet-5-5"])
        c = max((u.get("input_tokens") or 0) * pi / 1e6 + (u.get("output_tokens") or 0) * po / 1e6 + (u.get("web_searches") or 0) * 0.01,
                u.get("est_cost_usd") or 0)
        spent += c
        row = {"grupp": grp, "läge": mode, "fråga": frag, "förväntan": exp, "status": a["status"], "err": a["err"],
               "svarade": bool(a["text"].strip()), "svar": a["text"], "första_text_ms": a["first_text"], "klart_ms": a["done"],
               "modell": u.get("model"), "kostnad": round(c, 5)}
        out.append(row)
        print(json.dumps(row, ensure_ascii=False)[:700], flush=True)
        time.sleep(3.2)
    p = ROOT / "reports/qa/data/2026-11-10-deangelo-reality.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps({"spent_usd": round(spent, 4), "rows": out}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("spent", round(spent, 4), "->", p)


if __name__ == "__main__":
    main()
