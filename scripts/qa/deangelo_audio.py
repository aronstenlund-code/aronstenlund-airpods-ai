#!/usr/bin/env python3
"""Deangelo, 2026-11-10: hela kedjan med bakgrundsljud. Tal från /tts (3 röster) -> bakgrundsljud -> AirPods-filter ->
Scribe v2 Realtime som appen (stt-token, VAD, keyterms i Provläge) -> /answer (Frågor = auto, Provläge = tutor + profil).
Varje fall körs i ett bakgrundsljud (roterande); 16 fall körs i alla ljud för jämförelse.
  python -I scripts/qa/deangelo_audio.py --audio-dir <scratch>   -> reports/qa/data/2026-11-10-deangelo-audio.json
Ljud sparas aldrig i git. Budget /answer 1,0 USD."""
import sys as _d180s, pathlib as _d180p; _d180s.path.insert(0, str(_d180p.Path(__file__).resolve().parent)); import qa_testaccount; qa_testaccount.install()  # D180: bara testkonton, aldrig riktiga ElevenLabs
import argparse, asyncio, importlib.util, json, os, pathlib, sys, time
import numpy as np
from scipy.signal import butter, sosfilt

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("E", ROOT / "scripts/audio-eval.py")
E = importlib.util.module_from_spec(spec)
spec.loader.exec_module(E)
spec = importlib.util.spec_from_file_location("o8", ROOT / "scripts/qa/o8_latency.py")
O8 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(O8)
SR = E.SR
VOICES = {"Adam": "x0u3EW21dbrORJzOq1m9", "Saga": "tPrL2xYfkQnwJhHMMdRM", "Max": "JhAQDwsLijg4qbxGNQGH"}

PROF = {
    "bio": ("Prov i Biologi nästa vecka. Årskurs: Åk 9. Ämne: Biologi. Förklaringar: mellanlånga förklaringar.",
            ["fotosyntes", "mitokondrie", "klorofyll", "cellandning", "meios", "mitos", "kromosom", "ribosom", "DNA", "evolution"]),
    "kem": ("Prov i Kemi om två veckor. Årskurs: Åk 9. Ämne: Kemi. Förklaringar: mellanlånga förklaringar.",
            ["kovalent bindning", "jonbindning", "oxoniumjon", "pH", "molmassa", "elektron", "proton", "syra", "bas", "neutralisation"]),
    "his": ("Prov i Historia på fredag. Årskurs: Åk 8. Ämne: Historia. Förklaringar: korta förklaringar.",
            ["franska revolutionen", "Napoleon", "industriella revolutionen", "Westfaliska freden", "trettioåriga kriget", "upplysningen", "Gustav Vasa", "stormaktstiden"]),
    "mat": ("Prov i Matematik nästa vecka. Årskurs: Gymnasiet 1. Ämne: Matematik. Förklaringar: mellanlånga förklaringar.",
            ["pq-formeln", "andragradsekvation", "derivata", "funktion", "lutning", "procent", "sannolikhet", "Pythagoras sats"]),
    "fys": ("Prov i Fysik nästa vecka. Årskurs: Åk 9. Ämne: Fysik. Förklaringar: mellanlånga förklaringar.",
            ["Ohms lag", "spänning", "resistans", "ström", "densitet", "acceleration", "energiprincipen", "tryck"]),
    "eng": ("Prov i Engelska på måndag. Årskurs: Åk 9. Ämne: Engelska. Förklaringar: korta förklaringar.",
            ["present perfect", "past simple", "irregular verbs", "adjective", "adverb"]),
    "sam": ("Prov i Samhällskunskap nästa vecka. Årskurs: Gymnasiet 1. Ämne: Samhällskunskap. Förklaringar: mellanlånga förklaringar.",
            ["riksdagen", "regeringen", "demokrati", "grundlag", "inflation", "styrränta", "Riksbanken"]),
}
# (grupp, läge 'f'/'p', profil, text som sägs, förväntan 'svar'/'tyst', nyckelord som ska höras)
C = [
    # tydliga skolfrågor
    ("skolfråga", "p", "bio", "Vad är skillnaden mellan mitos och meios?", "svar", "mitos meios"),
    ("skolfråga", "p", "bio", "Vad gör klorofyllet i bladen?", "svar", "klorofyll"),
    ("skolfråga", "p", "kem", "Vad är en kovalent bindning?", "svar", "kovalent"),
    ("skolfråga", "p", "kem", "Vad händer när man blandar en syra och en bas?", "svar", "syra bas"),
    ("skolfråga", "p", "his", "Varför började franska revolutionen?", "svar", "franska revolutionen"),
    ("skolfråga", "p", "his", "Vad bestämdes i Westfaliska freden?", "svar", "westfaliska"),
    ("skolfråga", "p", "mat", "Hur använder man pq-formeln?", "svar", "pq"),
    ("skolfråga", "p", "mat", "Vad är derivatan av x i kvadrat?", "svar", "derivata"),
    ("skolfråga", "p", "fys", "Vad säger Ohms lag?", "svar", "ohms"),
    ("skolfråga", "p", "fys", "Hur räknar man ut densitet?", "svar", "densitet"),
    ("skolfråga", "p", "eng", "När använder man present perfect?", "svar", "present perfect"),
    ("skolfråga", "p", "sam", "Vad gör Riksbanken när inflationen är hög?", "svar", "riksbanken inflation"),
    # nyckelord och halva frågor
    ("nyckelord", "p", "bio", "Cellandning.", "svar", "cellandning"),
    ("nyckelord", "p", "kem", "Molmassa.", "svar", "molmassa"),
    ("nyckelord", "p", "his", "Stormaktstiden, orsaker.", "svar", "stormaktstiden"),
    ("nyckelord", "p", "fys", "Energiprincipen?", "svar", "energiprincipen"),
    ("nyckelord", "p", "mat", "Pythagoras sats.", "svar", "pythagoras"),
    ("nyckelord", "f", None, "Huvudstaden i Norge?", "svar", "norge"),
    ("halv", "p", "bio", "Det där med ribosomerna, vad gör de?", "svar", "ribosom"),
    ("halv", "p", "his", "Napoleon alltså, varför var han så viktig typ?", "svar", "napoleon"),
    ("halv", "p", "kem", "Hur var det nu med pH, vad betyder det egentligen?", "svar", "ph"),
    ("halv", "p", "mat", "Om man ska räkna ut lutningen på en linje, hur gör man då?", "svar", "lutning"),
    # talspråk, slang, omtag
    ("talspråk", "p", "bio", "Asså vad e grejen med DNA liksom?", "svar", "dna"),
    ("talspråk", "p", "fys", "Jag fattar inte accelerationen, kan du förklara?", "svar", "acceleration"),
    ("talspråk", "p", "sam", "Vad e skillnaden på riksdagen och regeringen typ?", "svar", "riksdagen regeringen"),
    ("talspråk", "f", None, "Yo, hur långt är det till månen?", "svar", "månen"),
    ("omtag", "p", "his", "Vem var kung under, nej vänta, vem startade trettioåriga kriget?", "svar", "trettioåriga"),
    ("omtag", "p", "bio", "Vad är mitokondrien, eller nej, vad är kloroplasten?", "svar", "kloroplast"),
    # vardagsfrågor (Frågor)
    ("vardag", "f", None, "Hur länge ska man koka pasta?", "svar", "pasta"),
    ("vardag", "f", None, "Vad är tjugo procent av fyrahundra?", "svar", "procent"),
    ("vardag", "f", None, "Vem skrev Harry Potter?", "svar", "harry potter"),
    ("vardag", "f", None, "När är det jul i år?", "svar", "jul"),
    ("vardag", "f", None, "Hur många minuter är tre och en halv timme?", "svar", "timme"),
    ("vardag", "f", None, "Vad betyder ordet empati?", "svar", "empati"),
    # lärare i klassrummet (Frågor ska svara på lärarens fråga)
    ("lärare", "f", None, "Kan någon förklara vad evolution är?", "svar", "evolution"),
    ("lärare", "f", None, "Vilket år föll Berlinmuren?", "svar", "berlinmuren"),
    ("lärare", "f", None, "Vad heter Sveriges längsta flod?", "svar", "flod"),
    ("lärare", "f", None, "Vem vet vad en metafor är?", "svar", "metafor"),
    # inte frågor: ska vara tyst
    ("inte fråga", "f", None, "Okej, öppna boken på sidan fyrtiotvå.", "tyst", ""),
    ("inte fråga", "f", None, "Har du gjort läxan till idag?", "tyst", ""),
    ("inte fråga", "f", None, "Ska vi ta bussen hem sen?", "tyst", ""),
    ("inte fråga", "f", None, "Kan du räcka mig suddet?", "tyst", ""),
    ("inte fråga", "f", None, "Jag är så trött idag.", "tyst", ""),
    ("inte fråga", "p", "bio", "Mamma, jag kommer snart!", "tyst", ""),
    ("inte fråga", "p", "bio", "Vad är klockan?", "svar", "klockan"),
    ("inte fråga", "f", None, "Jaha, okej.", "tyst", ""),
    # kommandon och följdord
    ("kommando", "p", "bio", "Förhör mig på fotosyntesen.", "svar", "förhör"),
    ("kommando", "p", "his", "Ge mig fem snabba frågor.", "svar", "frågor"),
    ("kommando", "p", "mat", "Förklara enklare.", "svar", "enklare"),
    ("kommando", "p", "kem", "Ge ett exempel.", "svar", "exempel"),
    # engelska och blandspråk
    ("engelska", "p", "eng", "What is the past tense of the word bring?", "svar", "bring"),
    ("engelska", "f", None, "What does the word awkward mean?", "svar", "awkward"),
    ("blandat", "p", "eng", "Hur säger man jag har aldrig varit i London på engelska?", "svar", "london"),
    # siffror och räkning
    ("räkning", "p", "mat", "Vad är sju gånger åtta minus tolv?", "svar", "sju åtta"),
    ("räkning", "p", "mat", "Lös ekvationen två x plus sex är lika med tjugo.", "svar", "ekvation"),
    ("räkning", "p", "fys", "Om spänningen är tolv volt och resistansen är fyra ohm, vad blir strömmen?", "svar", "volt ohm"),
    ("räkning", "f", None, "Hur mycket är femton procent av tvåhundrafemtio kronor?", "svar", "procent"),
    # svåra ord för taligenkänning
    ("svåra ord", "p", "bio", "Vad är fagocytos?", "svar", "fagocytos"),
    ("svåra ord", "p", "kem", "Vad är en oxoniumjon?", "svar", "oxoniumjon"),
    ("svåra ord", "p", "his", "Vad var upplysningen?", "svar", "upplysningen"),
    ("svåra ord", "p", "bio", "Vad gör ribosomerna i cellen?", "svar", "ribosom"),
    ("svåra ord", "p", "sam", "Vad är en styrränta?", "svar", "styrränta"),
]
COMPARE = [0, 4, 8, 13, 22, 28, 34, 38, 39, 41, 46, 53, 55, 58, 59, 26]  # körs i alla ljud


def brown(n, rng):
    w = rng.normal(0, 1, n).astype(np.float32)
    b = np.cumsum(w)
    b -= np.convolve(b, np.ones(SR) / SR, mode="same")
    return b / (np.max(np.abs(b)) + 1e-9)


def make_noises(babble, rng):
    n = SR * 240
    bab = np.resize(babble, n)
    # matsal: mer prat + korta klirr
    canteen = bab + np.roll(bab, n // 5) * 0.8
    for s in rng.integers(0, n - 800, 220):
        t = np.arange(800) / SR
        canteen[s:s + 800] += 0.6 * np.sin(2 * np.pi * rng.uniform(2500, 5000) * t) * np.exp(-t * 40)
    # tunnelbana: mullrande brus + 80 Hz
    t = np.arange(n) / SR
    subway = brown(n, rng) + 0.5 * np.sin(2 * np.pi * 80 * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.2 * t))
    # musik: ackord som byts varannan sekund + takt
    music = np.zeros(n, dtype=np.float32)
    chords = [[220, 277, 330], [196, 247, 294], [174, 220, 262], [196, 247, 294]]
    for i in range(0, n, 2 * SR):
        tt = np.arange(min(2 * SR, n - i)) / SR
        for f in chords[(i // (2 * SR)) % 4]:
            music[i:i + len(tt)] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * 0.7)
    for i in range(0, n, SR // 2):
        tt = np.arange(min(1200, n - i)) / SR
        music[i:i + len(tt)] += 1.5 * np.sin(2 * np.pi * 60 * tt) * np.exp(-tt * 30)
    # vind/gata: lågpassat brus i byar
    sos = butter(2, 600, btype="low", fs=SR, output="sos")
    wind = sosfilt(sos, rng.normal(0, 1, n)).astype(np.float32) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 0.15 * t)))
    return {
        "tyst": None,
        "klassrumsprat 10 dB": (bab, 10),
        "matsal 5 dB": (canteen, 5),
        "tunnelbana 5 dB": (subway, 5),
        "musik 10 dB": (music, 10),
        "vind/gata 8 dB": (wind, 8),
    }


def condition(x, cond, k):
    if cond[1] is None:
        y = x
    else:
        y = E.mix(x, cond[1][0], cond[1][1], k * 7919)
    return E.airpods(y, k)


def body(case, text):
    grp, mode, prof, said, exp, kw = case
    if mode == "f":
        return {"fragment": text, "mode": "auto", "language": "sv", "context": {}}
    return {"fragment": text, "mode": "tutor", "language": "sv", "persona": "tutor", "persona_setup": PROF[prof][0], "context": {}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audio-dir", required=True)
    a = ap.parse_args()
    rng = np.random.default_rng(7)
    tok = E.signup()
    vnames = list(VOICES)
    speech = []
    for i, c in enumerate(C):
        v = vnames[i % 3]
        speech.append((v, E.tts(tok, c[3], VOICES[v])))
        if i % 14 == 13:
            tok = E.signup()
    babble = np.concatenate([E.tts(tok, l, VOICES["Max"]) for l in E.BABBLE_LINES[:6]])
    babble = babble + np.roll(babble, len(babble) // 3)
    noises = make_noises(babble, rng)
    names = list(noises)
    jobs = {n: [] for n in names}  # cond -> [(case_idx)]
    for i in range(len(C)):
        jobs[names[i % len(names)]].append(i)
    for i in COMPARE:
        for n in names:
            if i not in jobs[n]:
                jobs[n].append(i)
    # Scribe: one stream per (cond, mode-group with same keyterms) -> group by profile so keyterms match the app
    async def run_all():
        tasks, meta = [], []
        for n in names:
            groups = {}
            for i in jobs[n]:
                groups.setdefault(C[i][2] or "-", []).append(i)
            for prof, idxs in groups.items():
                clips = [condition(speech[i][1], (n, noises[n]), i) for i in idxs]
                kt = PROF[prof][1] if prof in PROF else []
                meta.append((n, idxs))
                tasks.append(E.scribe_stream(E.signup(), clips, kt))
        sem = asyncio.Semaphore(6)

        async def lim(t):
            async with sem:
                return await t
        res = await asyncio.gather(*[lim(t) for t in tasks], return_exceptions=True)
        return meta, res
    meta, res = asyncio.run(run_all())
    rows, spent, ntok, tok = [], 0.0, 99, None
    for (n, idxs), r in zip(meta, res):
        if isinstance(r, Exception):
            for i in idxs:
                rows.append({"fall": i, "ljud": n, "fel": repr(r)[:200]})
            continue
        for i, parts in zip(idxs, r):
            heard = " ".join(parts).strip()
            row = {"fall": i, "grupp": C[i][0], "läge": C[i][1], "röst": speech[i][0], "ljud": n, "sagt": C[i][3],
                   "hört": heard, "förväntan": C[i][4], "nyckelord": C[i][5]}
            if heard and spent < 1.0:
                if ntok >= 14:
                    tok, ntok = E.signup(), 0
                ntok += 1
                ans = O8.timed_answer(tok, body(C[i], heard))
                u = (ans["done_ev"] or {}).get("usage") or {}
                pi, po = O8.D.PRICES.get(u.get("model"), O8.D.PRICES["claude-sonnet-5-5"])
                c = (u.get("input_tokens") or 0) * pi / 1e6 + (u.get("output_tokens") or 0) * po / 1e6 + (u.get("web_searches") or 0) * 0.01
                spent += c
                row.update({"svar": ans["text"], "första_text_ms": ans["first_text"], "status": ans["status"], "modell": u.get("model")})
                time.sleep(3.2)
            rows.append(row)
            print(json.dumps(row, ensure_ascii=False)[:600], flush=True)
    p = ROOT / "reports/qa/data/2026-11-10-deangelo-audio.json"
    p.write_text(json.dumps({"spent_answer_usd": round(spent, 4), "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("spent", round(spent, 4), "->", p)


if __name__ == "__main__":
    main()
