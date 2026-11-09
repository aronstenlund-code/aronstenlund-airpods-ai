#!/usr/bin/env python3
"""Oscar QA, O8: time to first text and to first audio after the Sonnet switch (D90, K7.6 thinking for word problems).
For every case: POST /answer streamed and timed per SSE event (first delta = first text; first full sentence), then
POST /tts with that first sentence (pcm_24000, like the app) timed to the first audio byte.
First audio (as the app does it) = time to the first full sentence + /tts time to first byte.
  python -I scripts/qa/o8_latency.py      -> reports/qa/data/<stamp>-o8.json
Measured from this Windows machine in Sweden over the internet to eu-north-1. Budget 0,50 USD (stops at 0,45)."""
import datetime as dt, importlib.util, json, pathlib, random, re, sys, time, urllib.error, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("demo", ROOT / "scripts/qa/demo.py")
D = importlib.util.module_from_spec(spec)
spec.loader.exec_module(D)
CAP = 0.45
SENT_END = re.compile(r"[.!?…](?=\s|$)")

WORD = [  # K7.6 word/logic problems: >= 8 words, a WP_ASK phrase and numbers -> thinking on in Provläge
    "Lisa är dubbelt så gammal som Tom. Om tre år är Lisa tjugo. Hur gammal är Tom nu?",
    "Ett tåg kör i nittio kilometer i timmen. Hur långt kommer det på två och en halv timme?",
    "En tröja kostar fyrahundra kronor och sänks med tjugofem procent. Vad kostar den nu?",
    "Anna och Erik cyklar mot varandra från två byar som ligger trettio kilometer isär. Anna cyklar femton och Erik tio kilometer i timmen. När möts de?",
    "I en klass är det tjugoåtta elever och tre fjärdedelar har cykel. Hur många har inte cykel?",
    "Om fem maskiner gör fem saker på fem minuter, hur lång tid tar det för hundra maskiner att göra hundra saker?",
    "En pappa är fyrtio år och hans son är tio. Om hur många år är pappan dubbelt så gammal som sonen? Hur gammal är sonen då?",
    "En bil drar sex liter per mil och bensinen kostar tjugo kronor litern. Vad kostar en resa på tolv mil?",
    "Tre kompisar delar på en pizza för hundratjugo kronor och en läsk för tjugoen kronor. Hur mycket betalar var och en?",
    "En simbassäng fylls av en kran på sex timmar och av en annan på tre timmar. Hur lång tid tar det med båda?",
    "Mira har femtio kronor mer än Leo, och tillsammans har de trehundra kronor. Hur mycket har Leo?",
    "Ett recept för fyra personer kräver tre deciliter mjölk. Hur mycket mjölk behövs för tio personer?",
]
FRAGOR = [  # Frågor (Auto, Haiku): ordinary spoken questions
    "vem skrev Röda rummet", "hur högt är Kebnekaise", "när började andra världskriget", "vad är huvudstaden i Australien",
    "hur fungerar en värmepump", "varför är himlen blå", "vad är skillnaden mellan virus och bakterier", "hur många invånare har Sverige",
    "vem uppfann telefonen", "vad betyder ordet empati", "hur lång är en maraton", "vad är inflation", "när landade människan på månen",
    "hur fungerar vaccin", "vad är en svart hål", "vilket är världens längsta flod", "vad är fotosyntes", "hur många ben har en spindel",
    "vem var Gustav Vasa", "vad är skillnaden mellan väder och klimat", "hur gör man en omelett", "vad är pi", "varför har vi skottår",
    "vad är en algoritm", "hur fungerar ett kärnkraftverk", "vad står FN för", "hur gammal blir en elefant", "vad är ett prefix",
    "vilken planet är störst", "vad är demokrati", "hur många grader är en rät vinkel", "vad är koldioxid", "vem målade Mona Lisa",
    "vad är skillnaden mellan its och it's", "hur fungerar blixten", "vad är en metafor", "vad heter Sveriges statsminister",
    "hur långt är det till solen", "vad är en kalori", "varför flyter is",
]


def signup():
    return D.signup()


def timed_answer(tok, body, timeout=120):
    req = urllib.request.Request(D.URL + "/functions/v1/answer", data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": D.KEY, "content-type": "application/json", "Authorization": "Bearer " + tok})
    t0 = time.perf_counter()
    out = {"status": None, "first_byte": None, "first_text": None, "first_sentence": None, "done": None, "text": "", "done_ev": None, "err": None}
    try:
        r = urllib.request.urlopen(req, timeout=timeout)
    except urllib.error.HTTPError as e:
        out["status"], out["err"] = e.code, e.read()[:300].decode("utf-8", "replace")
        return out
    except Exception as e:
        out["err"] = "exception " + repr(e)[:200]
        out["total"] = round((time.perf_counter() - t0) * 1000)
        return out
    out["status"] = r.status
    ev = None
    try:
        while True:
            line = r.readline()
            if not line:
                break
            now = round((time.perf_counter() - t0) * 1000)
            if out["first_byte"] is None:
                out["first_byte"] = now
            line = line.decode("utf-8", "replace").rstrip("\r\n")
            if line.startswith("event: "):
                ev = line[7:]
            elif line.startswith("data: "):
                try:
                    d = json.loads(line[6:])
                except Exception:
                    continue
                if ev == "delta" and d.get("text"):
                    if out["first_text"] is None:
                        out["first_text"] = now
                    out["text"] += d["text"]
                    if out["first_sentence"] is None and SENT_END.search(out["text"]):
                        out["first_sentence"] = now
                elif ev == "done":
                    out["done_ev"] = d
                elif ev == "error":
                    out["err"] = d
    except Exception as e:
        out["err"] = "exception while streaming " + repr(e)[:200]
    out["done"] = round((time.perf_counter() - t0) * 1000)
    if out["first_sentence"] is None and out["text"]:
        out["first_sentence"] = out["done"]  # a one-sentence answer without a stop: ready at the end
    return out


def timed_tts(tok, text):
    req = urllib.request.Request(D.URL + "/functions/v1/tts", method="POST", data=json.dumps({"text": text, "language": "sv", "output_format": "pcm_24000"}).encode(),
                                 headers={"apikey": D.KEY, "content-type": "application/json", "Authorization": "Bearer " + tok})
    t0 = time.perf_counter()
    try:
        r = urllib.request.urlopen(req, timeout=60)
        r.read(1)
        fb = round((time.perf_counter() - t0) * 1000)
        r.read()
        return {"status": r.status, "first_byte": fb, "total": round((time.perf_counter() - t0) * 1000)}
    except urllib.error.HTTPError as e:
        return {"status": e.code, "err": e.read()[:200].decode("utf-8", "replace")}
    except Exception as e:
        return {"status": None, "err": repr(e)[:200]}


def first_sentence(text):
    m = SENT_END.search(text)
    return text[: m.end()].strip() if m else text.strip()


def cases():
    bank = json.loads((ROOT / "scripts/provlage-bank.json").read_text(encoding="utf-8"))
    random.seed(808)
    pick = lambda kind, n: random.sample([c for c in bank if c["kind"] == kind], n)
    out = []
    for c in pick("term", 10) + pick("exam", 6) + pick("followup", 12):
        out.append(("prov", c["kind"], c["q"], c["profile"], c["context"]))
    profs = ["Årskurs: Åk 8. Ämne: Matematik. Förklaringar: mellanlånga förklaringar.", "Årskurs: Åk 9. Ämne: Matematik. Förklaringar: korta förklaringar."]
    for i, q in enumerate(WORD):
        out.append(("prov", "word", q, profs[i % 2], []))
    for q in FRAGOR:
        out.append(("fragor", "fact", q, None, []))
    # O5: the 3rd "vad är en derivata" in a row (Åk 8) did not answer in 90 s: try it first, six in a row
    return [("prov", "hang-repro", "vad är en derivata", "Prov i Matte imorgon. Årskurs: Åk 8.", [])] * 6 + out


def main():
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    rows, tok, n_user = [], None, 99
    todo = cases()
    if "--fragor" in sys.argv:  # second pass: Frågor only (the first pass hit the cap before them)
        global CAP
        todo, CAP = [c for c in todo if c[0] == "fragor"], 0.06
        stamp += "-fragor"
    for i, (mode, kind, q, prof, ctx) in enumerate(todo):
        if D.spent >= CAP:
            print("budget cap reached", D.spent)
            break
        if n_user >= 15:  # the new-session window: 20 answers in the first hour per anonymous user
            tok, n_user = signup(), 0
        if mode == "prov":
            body = {"fragment": q, "mode": "tutor", "language": "sv", "persona": "tutor", "persona_setup": prof, "context": {"recent_qa": ctx[-3:]} if ctx else {}}
        else:
            body = {"fragment": q, "mode": "auto", "language": "sv", "context": {}}
        a = timed_answer(tok, body)
        n_user += 1
        u = (a["done_ev"] or {}).get("usage") or {}
        cost = D.cost(a["done_ev"]) if a["done_ev"] else 0.0
        fs = first_sentence(a["text"])
        t = timed_tts(tok, fs) if fs else {}
        audio = (a["first_sentence"] + t["first_byte"]) if (a.get("first_sentence") is not None and t.get("first_byte") is not None) else None
        row = {"i": i, "mode": mode, "kind": kind, "q": q, "status": a["status"], "err": a["err"], "first_byte_ms": a["first_byte"], "first_text_ms": a["first_text"],
               "first_sentence_ms": a["first_sentence"], "done_ms": a["done"], "tts_first_byte_ms": t.get("first_byte"), "tts_status": t.get("status"),
               "first_audio_ms": audio, "model": u.get("model"), "thinking": u.get("thinking_tokens") or u.get("think") or None, "in_tok": u.get("input_tokens"),
               "out_tok": u.get("output_tokens"), "cache_read": u.get("cache_read_tokens"), "cost": round(cost, 5), "first_sentence": fs[:200], "text": a["text"][:400],
               "answered": (a["done_ev"] or {}).get("answered"), "tts_chars": len(fs)}
        rows.append(row)
        print(i, mode, kind, a["status"], "text", a["first_text"], "sent", a["first_sentence"], "audio", audio, "done", a["done"], u.get("model"), round(cost, 4), "|", q[:50], flush=True)
        time.sleep(3.2)
    path = ROOT / "reports/qa/data" / f"{stamp}-o8.json"
    path.write_text(json.dumps({"stamp": stamp, "spent_usd": round(D.spent, 4), "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("spent", round(D.spent, 4), "->", path)


if __name__ == "__main__":
    main()
