#!/usr/bin/env python3
"""Oscar QA, O43: one-word answers in a quiz (Arons phone test 2026-11-11: "Nilen" heard as "Nilan" / "om ni har redan
svarat"; "Seine" said "sän" heard as "såg en"). 40 quiz questions with a one-word answer, written by Oscar before K40.
Pipeline per case and condition (quiet / classroom babble):
  cached speech (ElevenLabs /tts ONCE, scripts/qa/audio-cache/o43/, git-ignored; D120) -> Scribe v2 Realtime like the app
  (stt-token, Provläge VAD, keyterms = what the app sends for the exam: ExamKeyterms(subject, topics, /study-profile
  terms), sanitised to <= 20 terms of <= 20 code points; --a62 puts the right answer (+ alternatives from --alts or
  the K40 field) first) -> /answer as the student's reply to Lumen's check question (mode tutor, persona tutor,
  recent_qa ends with the question, last_answer_age_sec 6) -> graded right when the reply starts with "Rätt" or says
  "Rätt i så fall". Foreign names are spoken as a Swedish student says them ("Sän", "Loar", "Marsej").
Babble: four espeak-ng Swedish voices talking over each other (free), mixed at --snr dB (default 10: the AirPods mic is close to the mouth) under the answer.
  O6_LIB=<scipy+websockets> python -I scripts/qa/o43_short_answers.py --tag fore [--only geo] [--cond quiet,babble]
  -> reports/qa/data/<stamp>-o43-<tag>.json"""
import sys as _d180s, pathlib as _d180p; _d180s.path.insert(0, str(_d180p.Path(__file__).resolve().parent)); import qa_testaccount; qa_testaccount.install()  # D180: bara testkonton, aldrig riktiga ElevenLabs
import argparse, asyncio, datetime as dt, importlib.util, json, os, pathlib, re, subprocess, sys, tempfile, time, unicodedata, urllib.request, wave

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
if os.environ.get("O6_LIB"):
    sys.path.insert(0, os.environ["O6_LIB"])
import numpy as np
from scipy.signal import resample_poly

sys.argv, _argv = sys.argv[:1], sys.argv
sp = importlib.util.spec_from_file_location("o16", ROOT / "scripts/qa/o16_keyterms.py")
K = importlib.util.module_from_spec(sp)
sp.loader.exec_module(K)
sys.argv = _argv
O = K.O15
D = O.D
CACHE = ROOT / "scripts/qa/audio-cache/o43"

EXAMS = {
    "geo": {"subject": "Geografi", "topics": "de 50 mest kända sjöarna, floderna och kuststäderna",
            "setup": "Prov i Geografi nästa vecka om de 50 mest kända sjöarna, floderna och kuststäderna. Årskurs: Åk 9. Ämne: Geografi. Förklaringar: korta förklaringar. Kontrollfrågor: korta frågor."},
    "bio": {"subject": "Biologi", "topics": "cellen, fotosyntesen, genetik och kroppen",
            "setup": "Prov i Biologi nästa vecka om cellen, fotosyntesen, genetik och kroppen. Årskurs: Åk 9. Ämne: Biologi. Förklaringar: korta förklaringar. Kontrollfrågor: korta frågor."},
    "his": {"subject": "Historia", "topics": "Sveriges historia, revolutioner och antiken",
            "setup": "Prov i Historia nästa vecka om Sveriges historia, revolutioner och antiken. Årskurs: Åk 9. Ämne: Historia. Förklaringar: korta förklaringar. Kontrollfrågor: korta frågor."},
}
# id, exam, Lumen's check question, right answer, what the student says (TTS text), accepted spellings (letters only)
CASES = [
    ("g01", "geo", "Vilken flod rinner genom Egypten?", "Nilen", "Nilen", []),
    ("g02", "geo", "Vilken flod rinner genom Paris?", "Seine", "Sän", ["sän"]),
    ("g03", "geo", "Vilken är Frankrikes längsta flod?", "Loire", "Loar", ["loar"]),
    ("g04", "geo", "Vilken flod rinner genom Köln och Basel?", "Rhen", "Rhen", ["rhein", "ren"]),
    ("g05", "geo", "Vilken flod rinner genom Wien och Budapest?", "Donau", "Donau", []),
    ("g06", "geo", "Vilken är Europas längsta flod?", "Volga", "Volga", ["wolga"]),
    ("g07", "geo", "Vilken flod rinner genom Brasiliens regnskog?", "Amazonas", "Amazonas", ["amazon"]),
    ("g08", "geo", "Vilken flod mynnar vid New Orleans?", "Mississippi", "Mississippi", []),
    ("g09", "geo", "Vilken flod rinner genom London?", "Themsen", "Themsen", ["temsen", "thames"]),
    ("g10", "geo", "Vilken flod är helig för hinduer?", "Ganges", "Ganges", []),
    ("g11", "geo", "Vilken är Europas största sjö?", "Ladoga", "Ladoga", ["ladogasjön"]),
    ("g12", "geo", "Vilken är Afrikas största sjö?", "Viktoriasjön", "Viktoriasjön", ["victoriasjön"]),
    ("g13", "geo", "Vilken är Frankrikes största hamnstad vid Medelhavet?", "Marseille", "Marsej", ["marsej", "marseilles"]),
    ("g14", "geo", "Vilken är Sveriges största sjö?", "Vänern", "Vänern", []),
    ("g15", "geo", "Vilken är världens djupaste sjö?", "Bajkalsjön", "Bajkalsjön", ["baikalsjön", "bajkal", "baikal"]),
    ("g16", "geo", "Vilken italiensk kuststad ligger vid Vesuvius?", "Neapel", "Neapel", ["napoli"]),
    ("g17", "geo", "Vilken är Portugals huvudstad vid Atlanten?", "Lissabon", "Lissabon", ["lisboa"]),
    ("g18", "geo", "Vilken är världens största insjö?", "Kaspiska havet", "Kaspiska havet", ["kaspiskahavet"]),
    ("g19", "geo", "Vilken är Sveriges största hamnstad?", "Göteborg", "Göteborg", []),
    ("g20", "geo", "Vilken polsk hamnstad vid Östersjön är känd för varvet där Solidaritet bildades?", "Gdańsk", "Gdansk", ["gdansk", "danzig"]),
    ("b01", "bio", "Vilken del av cellen gör energi?", "Mitokondrien", "Mitokondrien", ["mitokondrie", "mitokondrierna"]),
    ("b02", "bio", "Vad heter processen där växter gör socker med hjälp av ljus?", "Fotosyntes", "Fotosyntes", ["fotosyntesen"]),
    ("b03", "bio", "I vilken del av växtcellen sker fotosyntesen?", "Kloroplasten", "Kloroplasten", ["kloroplast", "kloroplasterna"]),
    ("b04", "bio", "Vilken del av cellen bygger proteiner?", "Ribosomen", "Ribosomen", ["ribosom", "ribosomerna"]),
    ("b05", "bio", "Var i cellen finns DNA?", "Cellkärnan", "Cellkärnan", ["kärnan", "cellkärna"]),
    ("b06", "bio", "Vilken gas bildas vid fotosyntesen?", "Syre", "Syre", ["syrgas"]),
    ("b07", "bio", "Vilket hormon sänker blodsockret?", "Insulin", "Insulin", []),
    ("b08", "bio", "Vilken celldelning ger könsceller?", "Meios", "Meios", []),
    ("b09", "bio", "Vilket ämne i de röda blodkropparna binder syre?", "Hemoglobin", "Hemoglobin", []),
    ("b10", "bio", "Vem formulerade teorin om det naturliga urvalet?", "Darwin", "Darwin", ["charlesdarwin"]),
    ("h01", "his", "Vem blev Sveriges kung 1523?", "Gustav Vasa", "Gustav Vasa", ["gustavvasa"]),
    ("h02", "his", "Vilket år började franska revolutionen?", "1789", "sjuttonhundraåttionio", ["1789", "sjuttonhundraåttionio"]),
    ("h03", "his", "Vem kröntes till kejsare av Frankrike 1804?", "Napoleon", "Napoleon", []),
    ("h04", "his", "Var stupade Gustav II Adolf?", "Lützen", "Lützen", ["lutzen", "lytsen"]),
    ("h05", "his", "Var uppstod de första städerna, mellan Eufrat och Tigris?", "Mesopotamien", "Mesopotamien", []),
    ("h06", "his", "Vem startade reformationen 1517?", "Luther", "Luther", ["martinluther"]),
    ("h07", "his", "Vilket år slutade andra världskriget?", "1945", "nittonhundrafyrtiofem", ["1945", "nittonhundrafyrtiofem"]),
    ("h08", "his", "Vem ledde ryska revolutionen 1917?", "Lenin", "Lenin", []),
    ("h09", "his", "Vad hette unionen mellan Sverige, Danmark och Norge från 1397?", "Kalmarunionen", "Kalmarunionen", []),
    ("h10", "his", "Vilken kung i Babylon skrev en av de första lagsamlingarna?", "Hammurabi", "Hammurabi", ["hammurabis"]),
]
BABBLE = [
    "Har du gjort läxan i matte till imorgon eller ska vi göra den på lunchen?",
    "Asså jag fattar inte varför vi måste ha prov på fredag igen.",
    "Kan någon låna ut en penna, jag har glömt min i skåpet.",
    "Vi ses efter skolan vid busshållplatsen, okej?",
    "Han sa att träningen är inställd idag på grund av regnet.",
    "Vad fick du på uppgiften, jag fick bara hälften rätt.",
]


def letters(t):
    return re.sub(r"[^a-zåäöéüñ0-9]", "", unicodedata.normalize("NFC", t.lower()).replace("ń", "n").replace("ü", "u"))


def heard_match(heard, accepted):
    """Whole words only ("säng" is not "sän"): one to three heard words joined must equal an accepted spelling."""
    hw = [letters(w) for w in heard.split()]
    hw = [w for w in hw if w]
    for i in range(len(hw)):
        for j in range(i + 1, min(len(hw), i + 3) + 1):
            if "".join(hw[i:j]) in accepted:
                return True
    return False


def sanitize(terms):
    """App's ScribeKeyterms (A8.5) as Scribe counts it (O16): <= 20 terms of <= 20 code points, whole words."""
    out = []
    for raw in terms:
        t = unicodedata.normalize("NFC", " ".join(raw.split()))
        pieces = [t] if len(t) <= 20 else []
        if not pieces:
            run = ""
            for w in t.split(" "):
                w = w[:20]
                if not run:
                    run = w
                elif len(run) + 1 + len(w) <= 20:
                    run += " " + w
                else:
                    pieces.append(run); run = w
            if len(run) >= 2:
                pieces.append(run)
        for p in pieces:
            if p and len(out) < 20 and not any(p.lower() == x.lower() for x in out):
                out.append(p)
    return out


# Oscar's own plausible wrong answers per case (written 2026-11-11 12:55, not taken from backend/testdata/k40-quiz-sound.json):
# the quiz_key the model's [[SVAR]] line would give, sent back as context.quiz_key with --quiz-key (A62) and put in the
# keyterms with --a62.
ALTS = {
    "g01": ["Kongo", "Niger", "Zambezi", "Eufrat"], "g02": ["Loire", "Rhône", "Garonne", "Themsen"],
    "g03": ["Seine", "Rhône", "Garonne", "Rhen"], "g04": ["Donau", "Elbe", "Main", "Rhône"],
    "g05": ["Rhen", "Elbe", "Volga", "Oder"], "g06": ["Donau", "Dnepr", "Ural", "Rhen"],
    "g07": ["Orinoco", "Paraná", "Mississippi", "Nilen"], "g08": ["Missouri", "Ohio", "Colorado", "Hudson"],
    "g09": ["Seine", "Severn", "Mersey", "Rhen"], "g10": ["Indus", "Brahmaputra", "Mekong", "Nilen"],
    "g11": ["Onega", "Vänern", "Peipus", "Saimen"], "g12": ["Tanganyikasjön", "Malawisjön", "Tchadsjön", "Turkanasjön"],
    "g13": ["Nice", "Toulon", "Bordeaux", "Lyon"], "g14": ["Vättern", "Mälaren", "Hjälmaren", "Storsjön"],
    "g15": ["Tanganyikasjön", "Kaspiska havet", "Ladoga", "Övre sjön"], "g16": ["Rom", "Genua", "Venedig", "Palermo"],
    "g17": ["Porto", "Madrid", "Sevilla", "Faro"], "g18": ["Övre sjön", "Bajkalsjön", "Aralsjön", "Victoriasjön"],
    "g19": ["Malmö", "Stockholm", "Helsingborg", "Gävle"], "g20": ["Szczecin", "Gdynia", "Warszawa", "Kaliningrad"],
    "b01": ["Ribosomen", "Cellkärnan", "Kloroplasten", "Golgiapparaten"], "b02": ["Cellandning", "Fotolys", "Osmos", "Jäsning"],
    "b03": ["Mitokondrien", "Cellkärnan", "Vakuolen", "Cellväggen"], "b04": ["Mitokondrien", "Cellkärnan", "Golgiapparaten", "Lysosomen"],
    "b05": ["Cytoplasman", "Mitokondrien", "Ribosomen", "Cellmembranet"], "b06": ["Koldioxid", "Kväve", "Väte", "Vattenånga"],
    "b07": ["Glukagon", "Adrenalin", "Kortisol", "Tyroxin"], "b08": ["Mitos", "Delning", "Knoppning", "Klyvning"],
    "b09": ["Myoglobin", "Insulin", "Plasma", "Järn"], "b10": ["Mendel", "Lamarck", "Linné", "Wallace"],
    "h01": ["Gustav II Adolf", "Karl XII", "Kristian II", "Erik XIV"], "h02": ["1776", "1799", "1815", "1689"],
    "h03": ["Ludvig XVI", "Robespierre", "Karl den store", "Ludvig XIV"], "h04": ["Breitenfeld", "Narva", "Poltava", "Lund"],
    "h05": ["Egypten", "Grekland", "Indusdalen", "Persien"], "h06": ["Calvin", "Zwingli", "Olaus Petri", "Erasmus"],
    "h07": ["1918", "1939", "1944", "1946"], "h08": ["Stalin", "Trotskij", "Tsar Nikolaj", "Kerenskij"],
    "h09": ["Kalmarkriget", "Hansan", "Nordiska rådet", "Unionen"], "h10": ["Nebukadnessar", "Sargon", "Gilgamesh", "Kyros"],
}


def exam_terms(tok, exam):
    e = EXAMS[exam]
    o = D.call("POST", "/functions/v1/study-profile", {"text": e["setup"], "profile": {"subject": e["subject"], "grade": "y9"}, "language": "sv"}, tok)
    terms = (D.jbody(o) or {}).get("terms") or []
    kt = [e["subject"]] + [p.strip() for part in re.split(r"[,;\n]", e["topics"]) for p in part.split(" och ") if p.strip()] + terms
    return terms, o["status"]


def tts(tok, cid, text, chars):
    CACHE.mkdir(parents=True, exist_ok=True)
    f = CACHE / f"{cid}.pcm"
    if not f.exists():
        o = D.call("POST", "/functions/v1/tts", {"text": text + ".", "language": "sv", "output_format": "pcm_24000"}, tok)
        if o["status"] != 200:
            raise SystemExit(f"tts {o['status']} {o['body'][:200]!r}")
        f.write_bytes(o["body"])
        chars[0] += len(text) + 1
    x = np.frombuffer(f.read_bytes(), dtype=np.int16).astype(np.float32) / 32768
    return resample_poly(x, 2, 3).astype(np.float32)  # 24 -> 16 kHz


def babble_track():
    f = CACHE / "babble16k.npy"
    if f.exists():
        return np.load(f)
    voices = ["sv+m1", "sv+f2", "sv+m3", "sv+f4"]
    tracks = []
    with tempfile.TemporaryDirectory() as td:
        for i, v in enumerate(voices):
            parts = []
            for j in range(6):
                w = pathlib.Path(td) / f"{i}-{j}.wav"
                subprocess.run(["espeak-ng", "-v", v, "-s", str(150 + 15 * i), "-p", str(35 + 10 * i), "-w", str(w), BABBLE[(i + j) % len(BABBLE)]], check=True)
                with wave.open(str(w)) as wf:
                    y = np.frombuffer(wf.readframes(wf.getnframes()), dtype=np.int16).astype(np.float32) / 32768
                    parts.append(resample_poly(y, 16000, wf.getframerate()).astype(np.float32))
                parts.append(np.zeros(int(16000 * 0.15 * (i + 1)), dtype=np.float32))
            tracks.append(np.concatenate(parts))
    n = min(len(t) for t in tracks)
    b = sum(np.roll(t[:n], 4000 * i) for i, t in enumerate(tracks))
    b = b / (np.sqrt(np.mean(b ** 2)) + 1e-9)
    CACHE.mkdir(parents=True, exist_ok=True)
    np.save(f, b.astype(np.float32))
    return b.astype(np.float32)


def with_babble(speech, k, snr):
    pad = np.concatenate([np.zeros(4800, dtype=np.float32), speech, np.zeros(8000, dtype=np.float32)])
    b = babble_track()
    off = (k * 7919) % (len(b) - len(pad) - 1)
    rms_s = np.sqrt(np.mean(speech ** 2)) + 1e-9
    noise = b[off:off + len(pad)] * rms_s / (10 ** (snr / 20))
    y = pad + noise
    return (y / max(1.0, np.max(np.abs(y)))).astype(np.float32)


def sse(text):
    ev = []
    for f in text.split("\n\n"):
        e = [l[7:] for l in f.split("\n") if l.startswith("event: ")]
        d = [l[6:] for l in f.split("\n") if l.startswith("data: ")]
        if e and d:
            try:
                ev.append((e[0], json.loads(d[0])))
            except ValueError:
                pass
    return ev


def answer(tok, exam, question, heard, quiz_key=None):
    body = {"fragment": heard, "mode": "tutor", "language": "sv", "persona": "tutor", "persona_setup": EXAMS[exam]["setup"],
            "context": {"recent_qa": [{"q": "Förhör mig", "a": question}], "last_answer_age_sec": 6}}
    if quiz_key:
        body["context"]["quiz_key"] = quiz_key
    req = urllib.request.Request(D.URL + "/functions/v1/answer", data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": D.KEY, "content-type": "application/json", "authorization": "Bearer " + tok})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=60) as x:
            ev = sse(x.read().decode())
            st = x.status
    except urllib.error.HTTPError as e:
        return {"status": e.code, "err": e.read().decode()[:200]}
    said = "".join(d.get("text", "") for n, d in ev if n == "delta")
    done = next((d for n, d in ev if n == "done"), {}) or {}
    meta = next((d for n, d in ev if n == "meta"), {}) or {}
    return {"status": st, "said": said, "ms": round((time.time() - t0) * 1000), "done": done, "meta": meta}


def verdict(said):
    s = said.strip().lower()
    if re.match(r"^(rätt|helt rätt|ja, rätt|precis|korrekt)\b", s) or "rätt i så fall" in s:
        return "right"
    if s.startswith("nästan"):
        return "almost"
    if s.startswith("inte riktigt") or s.startswith("fel"):
        return "wrong"
    return "other" if s else "silent"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tag", required=True)
    ap.add_argument("--only", default="")
    ap.add_argument("--cond", default="quiet,babble")
    ap.add_argument("--snr", type=float, default=10.0)
    ap.add_argument("--a62", action="store_true", help="put the right answer (+ K40 alternatives) first in the keyterms")
    ap.add_argument("--quiz-key", action="store_true", help="send context.quiz_key {answer, alternatives} back like the app after A62")
    ap.add_argument("--cap", type=float, default=0.60)
    a = ap.parse_args()
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M%S")
    out = ROOT / "reports/qa/data" / f"{stamp}-o43-{a.tag}.json"
    tok, n = O.signup(), 0
    chars, secs, rows = [0], 0.0, []
    terms = {}
    for ex in EXAMS:
        t, st = exam_terms(tok, ex)
        e = EXAMS[ex]
        base = [e["subject"]] + [p.strip() for part in re.split(r"[,;\n]", e["topics"]) for p in part.split(" och ") if p.strip()] + t
        terms[ex] = {"study_profile_status": st, "study_profile_terms": t, "keyterms": sanitize(base)}
        print(ex, "keyterms:", terms[ex]["keyterms"], flush=True)
    cost = 0.0
    for k, (cid, exam, q, right, say, acc) in enumerate(CASES):
        if a.only and not any(cid.startswith(p) or exam == p for p in a.only.split(",")):
            continue
        speech = tts(tok, cid, say, chars)
        for cond in a.cond.split(","):
            if cost >= a.cap:
                break
            if n >= 30:
                tok, n = O.signup(), 0
            audio = with_babble(speech, k, a.snr) if cond == "babble" else np.concatenate(
                [np.zeros(1600, dtype=np.float32), speech, np.zeros(8000, dtype=np.float32)])
            kt = terms[exam]["keyterms"]
            qk = {"answer": right, "alternatives": ALTS[cid]}
            if a.a62:
                kt = sanitize([right] + ALTS[cid] + kt)
            r = asyncio.run(K.probe(tok, audio, kt))
            secs += len(audio) / 16000
            heard = " ".join(c or "" for c in r["commits"]).strip()
            heard_ok = heard_match(heard, [letters(right)] + acc)
            res = answer(tok, exam, q, heard, qk if a.quiz_key else None) if heard else {"status": None, "said": "", "note": "nothing heard"}
            n += 1
            u = (res.get("done") or {}).get("usage") or {}
            m = u.get("model") or ""
            c = D.cost(res.get("done")) if res.get("done") else 0.0  # demo.py prices, cache reads discounted
            cost += c
            v = verdict(res.get("said", ""))
            rows.append({"id": cid, "exam": exam, "cond": cond, "question": q, "right": right, "said_by_student": say, "keyterms": kt,
                         "heard": heard, "heard_ok": heard_ok, "scribe_msgs": [m2 for m2 in r["msgs"] if "Zero retention" not in m2][:2],
                         "reply": res.get("said", ""), "verdict": v, "graded_right": v == "right", "model": m, "cost": round(c, 5),
                         "ms": res.get("ms"), "status": res.get("status"),
                         "done_extra": {kk: vv for kk, vv in (res.get("done") or {}).items() if kk not in ("timing", "breakdown", "usage", "summary", "relation", "source", "memory_add")}})
            print(cid, cond, "RIGHT" if v == "right" else v.upper(), "| heard:", heard[:40], "| reply:", res.get("said", "")[:70].replace("\n", " "), flush=True)
            out.write_text(json.dumps({"stamp": stamp, "tag": a.tag, "a62": a.a62, "quiz_key": a.quiz_key, "snr_db": a.snr, "terms": terms, "rows": rows,
                                       "elevenlabs_chars_new": chars[0], "scribe_seconds": round(secs, 1), "est_cost_usd": round(cost, 4)},
                                      ensure_ascii=False, indent=1), encoding="utf-8")
            time.sleep(10.5)  # stt-token: 6 per user per minute
    summ = {}
    for cond in a.cond.split(","):
        rs = [r for r in rows if r["cond"] == cond]
        summ[cond] = {"n": len(rs), "graded_right": sum(r["graded_right"] for r in rs), "heard_ok": sum(r["heard_ok"] for r in rs),
                      "almost": sum(r["verdict"] == "almost" for r in rs), "wrong": sum(r["verdict"] == "wrong" for r in rs),
                      "other_or_silent": sum(r["verdict"] in ("other", "silent") for r in rs)}
    print(json.dumps(summ, ensure_ascii=False), "ElevenLabs chars", chars[0], "Scribe s", round(secs, 1), "cost", round(cost, 4), "->", out)
    data = json.loads(out.read_text(encoding="utf-8"))
    data["summary"] = summ
    out.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
