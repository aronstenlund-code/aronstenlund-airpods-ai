#!/usr/bin/env python3
"""K57 live eval of /help (D166): 30 how-do-I questions about Earmind must be answered (not refused, not "Det vet jag
inte", and containing at least one expected word), 10 questions outside the app must get exactly
"Det kan jag inte svara på.". Also checks the forbidden words (övningsprov, A+-svar, drill, TTS, model names).
  python -X utf8 scripts/k57-live.py"""
import concurrent.futures as cf, datetime, json, pathlib, re, sys, urllib.error, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design
HOW = [
    ("Hur gör jag ett nytt prov?", ["nytt prov"]),
    ("Hur fungerar trycken?", ["tryck 1 gång", "1 gång"]),
    ("Vad händer om jag trycker två gånger?", ["kort"]),
    ("Hur pausar jag?", ["3 gånger", "tre gånger", "paus"]),
    ("Hur fortsätter jag efter paus?", ["tryck", "fortsätt"]),
    ("Hur avslutar jag provet?", ["avsluta"]),
    ("Varför blev det färre frågor än jag valde?", ["materialet", "räckte"]),
    ("Hur delar jag ett prov med en kompis?", ["dela"]),
    ("Varför kan jag inte dela mitt prov?", ["ljudet", "klart"]),
    ("Hur publicerar jag ett prov?", ["publicera"]),
    ("Hur hittar jag prov från min skola?", ["skola"]),
    ("Kan jag byta röst efter att ljudet är gjort?", ["nytt prov", "går inte", "inte byta"]),
    ("Hur ändrar jag tempot?", ["tempo", "inställningar"]),
    ("Hur många frågor kan jag göra?", ["15"]),
    ("Räknas andras prov mot mina frågor?", ["inte", "gratis"]),
    ("Sparas mina foton?", ["sparas inte", "raderas"]),
    ("Använder Earmind mikrofonen?", ["mikrofon"]),
    ("Hur ändrar jag en fråga?", ["ändra"]),
    ("Hur lägger jag till en egen fråga?", ["lägg till fråga"]),
    ("Kan jag lägga till en PDF?", ["dokument", "pdf"]),
    ("Hur många bilder kan jag ta?", ["40"]),
    ("Vad är skillnaden mellan kort och långt svar?", ["första meningen", "kort"]),
    ("Hur rättar jag om ämnet blev fel?", ["rättelse", "skriv"]),
    ("Vad gör jag om ett tryck inte kommer fram?", ["airpods", "låsskärm"]),
    ("Fungerar det med gamla AirPods?", ["dubbeltryck", "vänster", "höger"]),
    ("Vad är Fler lägen?", ["beta"]),
    ("Kan Earmind styra Spotify?", ["kommer"]),
    ("Kostar det något?", ["15", "abonnemang"]),
    ("Hur rapporterar jag ett dåligt prov?", ["rapportera"]),
    ("Kan jag ta bort ett prov jag har publicerat?", ["ta bort"]),
]
OUTSIDE = ["Vad är fotosyntes?", "Hjälp mig med min mattelaxa: vad är 3x + 5 = 20?", "Vem vann fotbolls-VM?",
           "Skriv en dikt om hösten", "Hur använder jag Snapchat?", "Vad är huvudstaden i Frankrike?",
           "Kan du göra mina läxor?", "Berätta ett skämt", "Vad tycker du om mig?", "Hur mycket väger en elefant?"]
BAD = re.compile(r"övningsprov|A\+-svar|\bdrill\b|\bTTS\b|ElevenLabs|Haiku|Sonnet|Claude", re.I)


def token():
    req = urllib.request.Request(URL + "/auth/v1/signup", data=b"{}", method="POST", headers={"apikey": KEY, "content-type": "application/json"})
    return json.load(urllib.request.urlopen(req))["access_token"]


def ask(q, tok):
    req = urllib.request.Request(URL + "/functions/v1/help", data=json.dumps({"question": q}).encode(), method="POST",
                                 headers={"apikey": KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read()[:200].decode("utf-8", "replace")}


def main():
    toks = [token(), token(), token(), token()]  # 10 per minute per account
    jobs = [(q, kw, toks[i % 4]) for i, (q, kw) in enumerate(HOW)] + [(q, None, toks[i % 4]) for i, q in enumerate(OUTSIDE)]
    with cf.ThreadPoolExecutor(4) as ex:
        res = list(ex.map(lambda j: (j[0], j[1], ask(j[0], j[2])), jobs))
    rows, how_ok, out_ok, bad = [], 0, 0, 0
    for q, kw, r in res:
        a = r.get("answer", "")
        if kw is None:
            ok = a == "Det kan jag inte svara på." and r.get("in_scope") is False
            out_ok += ok
        else:
            ok = r.get("in_scope") is True and not a.startswith("Det vet jag inte") and any(k.lower() in a.lower() for k in kw)
            how_ok += ok
        b = bool(BAD.search(a))
        bad += b
        rows.append({"q": q, "ok": ok, "forbidden_word": b, "answer": a, "error": r.get("error")})
    out = {"how_to": f"{how_ok}/{len(HOW)}", "outside": f"{out_ok}/{len(OUTSIDE)}", "forbidden_words": bad,
           "cost_usd": round(sum((r.get("usage") or {}).get("est_cost_usd", 0) for _, _, r in res), 4), "rows": rows}
    p = ROOT / "reports/eval" / f"k57-help-{datetime.date.today().isoformat()}.json"
    p.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps({k: v for k, v in out.items() if k != "rows"}, ensure_ascii=False))
    for r in rows:
        if not r["ok"] or r["forbidden_word"]:
            print("MISS:", r["q"], "=>", r["answer"][:200], r["error"] or "")
    return 0


if __name__ == "__main__":
    sys.exit(main())
