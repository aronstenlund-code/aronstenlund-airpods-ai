#!/usr/bin/env python3
"""K18: are subject terms pronounced right? Each sentence is spoken by the deployed /tts (the app's default model,
pcm_24000), wrapped as WAV and transcribed by Scribe (provlage-eval "transcribe"); a term counts as right when the
transcript contains it (letters only, case and spacing ignored; a few close spellings accepted).
  python -X utf8 -I scripts/k18-pronunciation.py --tokens FILE [--tag before|after] -> reports/eval/k18-<tag>-<date>.json"""
import argparse, base64, datetime, importlib.util, io, json, pathlib, re, sys, time, unicodedata, urllib.request, wave

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


PE = load("pe", ROOT / "scripts/provlage-eval.py")
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design

# [term, sentence]: physics, maths, chemistry, biology, history, geography, languages
CASES = [
    ["Ohms lag", "Enligt Ohms lag är spänningen lika med strömmen gånger resistansen."],
    ["Pythagoras sats", "Med Pythagoras sats räknar du ut hypotenusan i en rätvinklig triangel."],
    ["cellandning", "Vid cellandning bryts druvsocker ner i mitokondrierna."],
    ["mitokondrierna", "Energin frigörs i mitokondrierna, cellens kraftverk."],
    ["fotosyntes", "Fotosyntes sker i kloroplasterna med hjälp av ljus."],
    ["kloroplasterna", "Klorofyllet finns i kloroplasterna i bladens celler."],
    ["osmos", "Osmos är vattnets rörelse genom ett halvgenomsläppligt membran."],
    ["meios", "Vid meios bildas könsceller med halva antalet kromosomer."],
    ["DNA", "DNA bär ärftlig information i form av gener."],
    ["pH-värde", "Ett lågt pH-värde betyder att lösningen är sur."],
    ["koldioxid", "Växterna tar upp koldioxid ur luften."],
    ["kovalent bindning", "I en kovalent bindning delar atomerna på elektronpar."],
    ["joner", "Salter är uppbyggda av positiva och negativa joner."],
    ["entalpi", "Entalpi är ett mått på energiinnehållet i ett system."],
    ["Newtons tredje lag", "Newtons tredje lag säger att varje kraft har en motkraft."],
    ["acceleration", "Acceleration är hur snabbt hastigheten ändras."],
    ["derivata", "Derivatan visar lutningen på kurvan i en punkt."],
    ["ekvationssystem", "Ett ekvationssystem har två ekvationer med två obekanta."],
    ["sannolikhet", "Sannolikheten att få en sexa är en sjättedel."],
    ["Gustav Vasa", "Gustav Vasa blev kung år femtonhundratjugotre."],
    ["Westfaliska freden", "Westfaliska freden avslutade trettioåriga kriget."],
    ["upplysningen", "Under upplysningen betonades förnuftet och de mänskliga rättigheterna."],
    ["Versaillesfreden", "Versaillesfreden lade skulden för kriget på Tyskland."],
    ["Napoleon", "Napoleon kröntes till kejsare i Notre-Dame."],
    ["demokrati", "I en demokrati väljer folket sina företrädare."],
    ["Riksdagen", "Riksdagen stiftar lagar och beslutar om skatter."],
    ["plattektonik", "Plattektonik förklarar varför jordbävningar uppstår."],
    ["Golfströmmen", "Golfströmmen gör att Norden har ett mildare klimat."],
    ["preteritum", "Preteritum av verbet springa är sprang."],
    ["Shakespeare", "Shakespeare skrev pjäsen Romeo och Julia."],
]
ALT = {"ohmslag": ["omslag", "omslag", "ohmslag"], "dna": ["dna", "deenna", "deena"], "phvärde": ["phvärde", "pehåvärde", "pehavärde"]}


def letters(t):
    t = unicodedata.normalize("NFC", t.lower())
    return re.sub(r"[^a-zåäöéü]", "", t)


def post(path, body, tok, timeout=60):
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
    return urllib.request.urlopen(req, timeout=timeout)


def wav_of(pcm, rate=24000):
    b = io.BytesIO()
    with wave.open(b, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm)
    return b.getvalue()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", required=True)
    ap.add_argument("--tag", default="before")
    a = ap.parse_args()
    tok = PE.signup(a.tokens, 4)
    rows = []
    for term, sentence in CASES:
        r = post("/functions/v1/tts", {"text": sentence, "language": "sv", "output_format": "pcm_24000"}, tok)
        model = r.headers.get("x-tts-model")
        pcm = r.read()
        t = json.loads(post("/functions/v1/provlage-eval", {"action": "transcribe", "audio_base64": base64.b64encode(wav_of(pcm)).decode()}, tok, 90).read())
        heard = t.get("text", "")
        want = letters(term)
        ok = want in letters(heard) or any(x in letters(heard) for x in ALT.get(want, []))
        rows.append({"term": term, "sentence": sentence, "heard": heard, "ok": ok, "model": model})
        print("ok " if ok else "BAD", term, "|", heard, flush=True)
        time.sleep(0.3)
    s = {"terms": len(rows), "right": sum(r["ok"] for r in rows), "wrong": [r["term"] for r in rows if not r["ok"]]}
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    json.dump({"summary": s, "rows": rows}, open(ROOT / "reports" / "eval" / f"k18-{a.tag}-{date}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(json.dumps(s, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
