#!/usr/bin/env python3
"""Oscar QA, O11: independent test of Kevin's K13 (short answer first, more on 'ja', learned length), live, new cases.
  1-3. 18 two-level Provläge questions (new): the short part (delta) and the developed part (more_delta / done.more),
       timed per SSE event: first spoken word, end of the short part, the developed part complete. 'Time to the long
       answer after ja' = how long after the short part ends the developed one is ready (<= 0 = already there).
       Short/long quality and repetition are read by hand.
  4.   Learning with scope: Biologi q1 'ja', q2 'ja' -> q3 long at once; then a Kemi question in the same mode
       (the Biologi setting must not leak); then 'kortare' -> Biologi q4 short-first again.
  5.   'nej' / silence three times -> still short-first, not wordier.
  python -I scripts/qa/o11_k13.py   -> reports/qa/data/<stamp>-o11.json   (cap 0,32 USD)"""
import datetime as dt, importlib.util, json, pathlib, re, sys, time, urllib.error, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o15", ROOT / "scripts/qa/o15.py")
O = importlib.util.module_from_spec(spec)
spec.loader.exec_module(O)
D = O.D
CAP = 0.32
P = lambda g, s: f"Prov i {s} nästa vecka. Årskurs: {g}. Ämne: {s}. Förklaringar: mellanlånga förklaringar."
CASES = [
    (P("Åk 9", "Biologi"), "Biologi", "vad gör de vita blodkropparna"),
    (P("Åk 9", "Biologi"), "Biologi", "varför behöver vi sova"),
    (P("Åk 8", "Biologi"), "Biologi", "hur fungerar naturligt urval"),
    (P("Gymnasiet 1", "Kemi"), "Kemi", "vad är en exoterm reaktion"),
    (P("Gymnasiet 1", "Kemi"), "Kemi", "varför leder saltvatten ström"),
    (P("Åk 9", "Kemi"), "Kemi", "vad är skillnaden mellan ett grundämne och en kemisk förening"),
    (P("Åk 9", "Fysik"), "Fysik", "varför flyter en båt av stål"),
    (P("Gymnasiet 1", "Fysik"), "Fysik", "vad är skillnaden mellan fart och hastighet"),
    (P("Åk 8", "Fysik"), "Fysik", "hur fungerar en elmotor"),
    (P("Åk 9", "Historia"), "Historia", "varför började den industriella revolutionen i England"),
    (P("Åk 9", "Historia"), "Historia", "vad var apartheid"),
    (P("Gymnasiet 1", "Historia"), "Historia", "vad var Marshallplanen"),
    (P("Åk 9", "Samhällskunskap"), "Samhällskunskap", "vad gör en kommun"),
    (P("Gymnasiet 1", "Samhällskunskap"), "Samhällskunskap", "vad är skillnaden mellan höger och vänster i politiken"),
    (P("Gymnasiet 1", "Svenska"), "Svenska", "vad är en krönika"),
    (P("Åk 9", "Engelska"), "Engelska", "när använder man some och any"),
    (P("Gymnasiet 2", "Matematik"), "Matematik", "vad är en logaritm"),
    (P("Åk 8", "Matematik"), "Matematik", "hur räknar man ut medelvärde och median"),
]
BIO = P("Åk 9", "Biologi")
KEM = P("Åk 9", "Kemi")


def timed(tok, body):
    req = urllib.request.Request(D.URL + "/functions/v1/answer", data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": D.KEY, "content-type": "application/json", "Authorization": "Bearer " + tok})
    t0 = time.perf_counter()
    o = {"status": None, "short": "", "more": "", "t_first": None, "t_short_end": None, "t_more_first": None, "t_more_end": None,
         "t_done": None, "done": None, "err": None}
    try:
        r = urllib.request.urlopen(req, timeout=90)
    except urllib.error.HTTPError as e:
        o["status"], o["err"] = e.code, e.read()[:300].decode("utf-8", "replace")
        return o
    o["status"] = r.status
    ev = None
    while True:
        line = r.readline()
        if not line:
            break
        now = round((time.perf_counter() - t0) * 1000)
        line = line.decode("utf-8", "replace").rstrip("\r\n")
        if line.startswith("event: "):
            ev = line[7:]
        elif line.startswith("data: "):
            try:
                d = json.loads(line[6:])
            except Exception:
                continue
            if ev == "delta" and d.get("text"):
                o["t_first"] = o["t_first"] or now
                o["t_short_end"] = now
                o["short"] += d["text"]
            elif ev == "more_delta" and d.get("text"):
                o["t_more_first"] = o["t_more_first"] or now
                o["t_more_end"] = now
                o["more"] += d["text"]
            elif ev == "done":
                o["done"], o["t_done"] = d, now
            elif ev == "error":
                o["err"] = d
    if o["done"] and o["done"].get("more") and not o["more"]:
        o["more"] = o["done"]["more"]
    if o["done"]:
        D.cost(o["done"])
    time.sleep(3.2)
    return o


def words(t):
    return len(re.findall(r"\w+", t or ""))


def ask(tok, setup, subject, q, settings=None, two=True):
    b = {"fragment": q, "mode": "tutor", "language": "sv", "persona": "tutor", "persona_setup": setup, "context": {},
         "two_level": two, "pref_context": {"subject": subject}, **({"preferences": settings} if settings else {})}
    return timed(tok, b)


def memory(tok, payload):
    o = D.call("POST", "/functions/v1/memory", payload, tok)
    time.sleep(1.5)
    return D.jbody(o) or {}


def main():
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    out = ROOT / "reports/qa/data" / f"{stamp}-o11.json"
    res = {"cases": [], "learn": [], "no": []}
    save = lambda: out.write_text(json.dumps({"stamp": stamp, "spent_usd": round(D.spent, 4), **res}, ensure_ascii=False, indent=1), encoding="utf-8")
    tok = O.signup()
    for setup, subj, q in CASES:
        if D.spent >= CAP:
            break
        x = ask(tok, setup, subj, q)
        row = {"q": q, "subject": subj, "status": x["status"], "short": x["short"], "more": x["more"], "short_words": words(x["short"]),
               "more_words": words(x["more"]), "t_first": x["t_first"], "t_short_end": x["t_short_end"], "t_more_end": x["t_more_end"],
               "t_done": x["t_done"], "more_ready_after_short_ms": (x["t_more_end"] or x["t_done"] or 0) - (x["t_short_end"] or 0),
               "model": ((x["done"] or {}).get("usage") or {}).get("model"), "err": x["err"]}
        res["cases"].append(row)
        print("case", x["status"], row["short_words"], row["more_words"], row["t_first"], row["more_ready_after_short_ms"], "|", q, "=>", x["short"][:120], flush=True)
        save()
    # 4. learning with scope
    tok = O.signup()
    ctx = lambda subj: {"mode": "prov", "subject": subj, "answer_type": "explanation"}
    settings = []
    steps = [("bio", BIO, "Biologi", "vad är en enzym", "yes"), ("bio", BIO, "Biologi", "vad gör levern", "yes"),
             ("bio", BIO, "Biologi", "vad är fotosyntesens motsats", None), ("kem", KEM, "Kemi", "vad är en syra", None)]
    for tag, setup, subj, q, sig in steps:
        x = ask(tok, setup, subj, q, settings)
        r = {"step": q, "subject": subj, "settings_sent": list(settings), "short_words": words(x["short"]), "more_words": words(x["more"]),
             "two_level_split": bool(x["more"]), "short": x["short"], "status": x["status"]}
        if sig:
            m = memory(tok, {"length_signal": {"signal": sig, "context": ctx(subj)}, "settings": settings})
            settings = m.get("settings", settings)
            r["after_signal"] = {"settings": settings, "long_first": m.get("long_first")}
        res["learn"].append(r)
        print("learn", subj, q, "split", r["two_level_split"], r["short_words"], r["more_words"], settings, flush=True)
        save()
    m = memory(tok, {"correction": {"text": "kortare", "context": ctx("Biologi")}, "settings": settings})
    settings = m.get("settings", settings)
    x = ask(tok, BIO, "Biologi", "vad är en cellkärna", settings)
    res["learn"].append({"step": "efter 'kortare': vad är en cellkärna", "settings_sent": list(settings), "two_level_split": bool(x["more"]),
                         "short_words": words(x["short"]), "more_words": words(x["more"]), "short": x["short"], "status": x["status"], "correction_reply": m})
    print("after kortare split", bool(x["more"]), words(x["short"]), settings, flush=True)
    save()
    # 5. no / silence three times
    tok = O.signup()
    settings = []
    for q in ["vad är en art", "vad är en näringskedja", "vad är ett ekosystem", "vad är biologisk mångfald"]:
        x = ask(tok, BIO, "Biologi", q, settings)
        res["no"].append({"q": q, "settings_sent": list(settings), "split": bool(x["more"]), "short_words": words(x["short"]),
                          "more_words": words(x["more"]), "short": x["short"]})
        print("no", q, bool(x["more"]), words(x["short"]), settings, flush=True)
        m = memory(tok, {"length_signal": {"signal": "no", "context": ctx("Biologi")}, "settings": settings})
        settings = m.get("settings", settings)
        save()
    print("spent", round(D.spent, 4), "->", out)


if __name__ == "__main__":
    main()
