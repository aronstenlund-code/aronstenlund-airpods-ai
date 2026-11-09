#!/usr/bin/env python3
"""Oscar QA, O14: independent test of Kevin's K11 (no hanging calls, no stump, no invented quotes) + 429 under rapid calls.
  python -I scripts/qa/o14.py [time stump quote rate]   -> reports/qa/data/<stamp>-o14.json
Cases are new (not in scripts/k11-eval.py). First text = first SSE delta with text (o8_latency.timed_answer).
Budget 0,40 USD (stops at 0,36)."""
import concurrent.futures as cf, datetime as dt, importlib.util, json, pathlib, re, sys, time

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


O8 = load("o8", "scripts/qa/o8_latency.py")
D = O8.D
M = load("d81", "scripts/qa/d81.py")
CAP = 0.36

P = lambda grade, subj, extra="": f"Prov i {subj} nästa vecka{extra}. Årskurs: {grade}. Ämne: {subj}. Förklaringar: mellanlånga förklaringar."
TIME = [  # (kind, profile, question)
    ("plain", P("Åk 9", "Biologi"), "vad är skillnaden mellan mitos och meios"),
    ("plain", P("Åk 9", "Biologi"), "vad gör ribosomerna"),
    ("plain", P("Gymnasiet 1", "Kemi"), "vad är en kovalent bindning"),
    ("plain", P("Gymnasiet 1", "Kemi"), "hur balanserar man förbränningen av metan"),
    ("plain", P("Åk 9", "Historia"), "vilka var orsakerna till första världskriget"),
    ("plain", P("Åk 8", "Fysik"), "vad är densitet och hur räknar man ut det"),
    ("plain", P("Gymnasiet 1", "Svenska"), "vad kännetecknar realismen"),
    ("plain", P("Gymnasiet 3", "Matematik"), "vad är en primitiv funktion"),
    ("plain", P("Gymnasiet 3", "Matematik"), "derivera e upphöjt till tre x"),
    ("plain", P("Åk 9", "Engelska"), "när använder man present perfect"),
    ("word", P("Åk 8", "Matematik"), "En cykel kostar tretusen kronor och priset höjs med tio procent och sänks sedan med tio procent. Vad kostar den nu?"),
    ("word", P("Åk 8", "Matematik"), "Sara läser trettio sidor om dagen och boken har fyrahundrafemtio sidor. Hur många dagar tar det att läsa ut den?"),
    ("word", P("Åk 9", "Matematik"), "Två tåg lämnar Stockholm och Göteborg samtidigt, avståndet är fyrahundrasjuttio kilometer, det ena kör hundra och det andra hundrafyrtio i timmen. När möts de?"),
    ("word", P("Åk 9", "Matematik"), "I en påse finns tre röda och fem blå kulor. Om jag drar två kulor utan återläggning, vad är sannolikheten att båda är röda?"),
    ("word", P("Åk 8", "Matematik"), "Ett rektangulärt staket är fyrtio meter runt och ena sidan är tolv meter. Hur stor är arean?"),
    ("word", P("Gymnasiet 1", "Fysik"), "En bil accelererar från noll till hundra kilometer i timmen på åtta sekunder. Hur stor är accelerationen i meter per sekundkvadrat?"),
    ("word", P("Åk 9", "Matematik"), "Om tre katter fångar tre möss på tre minuter, hur många katter behövs för att fånga hundra möss på hundra minuter?"),
    ("word", P("Gymnasiet 1", "Kemi"), "Hur många mol är tjugo gram natriumhydroxid om molmassan är fyrtio gram per mol, och hur många gram behövs för två mol?"),
    ("careful", P("Åk 9", "Historia"), "var säker, när var freden i Westfalen och vad bestämdes där"),
    ("careful", P("Gymnasiet 1", "Kemi"), "var säker, vilket är atomnumret för järn och hur många elektroner har det i yttersta skalet"),
]
STUMP_Q = [  # interview, facts the CV does not have -> the model's claim is filtered; the next sentence must stand alone
    "har du körkort", "har du jobbat på Systembolaget förut", "har du gått utbildningen i ansvarsfull alkoholservering",
    "kan du jobba nätter", "har du jobbat med barn", "hur gammal är du och när kan du börja",
]
SV = P("Gymnasiet 2", "Svenska", " om svensk litteratur")
QUOTE_Q = [
    "citera Karin Boye ur dikten Ja visst gör det ont", "ge mig ett citat av Hjalmar Söderberg ur Doktor Glas",
    "vad sa Astrid Lindgren om barn", "citera Selma Lagerlöf om Gösta Berling", "citera Vilhelm Moberg ur Utvandrarna",
]
STUMP = re.compile(r"^\s*(?:där|därför|dessutom|alltså|också|det är (?:just|precis)|just (?:den|det)|den (?:här|där)|det här är|samma|denna|detta|dessa|"
                   r"(?:den|det) \w+heten|det har (?:lärt|gett|gjort) mig)\b", re.I)
QUOTE = re.compile(r"[\"“”«»„']([^\"“”«»„']{12,})[\"“”«»„']")
rows = []


def rec(**kw):
    rows.append(kw)
    print(json.dumps(kw, ensure_ascii=False)[:500], flush=True)


class Tok:
    def __init__(self):
        self.tok, self.n = None, 99

    def get(self):
        if self.n >= 15:
            self.tok, self.n = D.signup(), 0
        self.n += 1
        return self.tok


def run(tk, kind, body, **extra):
    a = O8.timed_answer(tk.get(), body)
    u = (a["done_ev"] or {}).get("usage") or {}
    c = D.cost(a["done_ev"]) if a["done_ev"] else 0.0
    rec(kind=kind, q=body["fragment"], status=a["status"], err=a["err"], first_text_ms=a["first_text"], done_ms=a["done"],
        model=u.get("model"), web=u.get("web_searches"), cost=round(c, 5), answered=(a["done_ev"] or {}).get("answered"),
        text=a["text"][:900], **extra)
    time.sleep(3.2)
    return a


def sec_time(tk):
    for kind, prof, q in TIME:
        if D.spent >= CAP:
            return
        run(tk, "time:" + kind, M.prov(prof, {"fragment": q}))


def sec_stump(tk):
    for q in STUMP_Q:
        if D.spent >= CAP:
            return
        a = run(tk, "stump", {"fragment": q, "mode": "tutor", "language": "sv", "persona": "interview", "persona_setup": M.AD + " CV: " + M.CV,
                              "context": {}, "turn": "question"})
        rows[-1]["stump_regex"] = bool(STUMP.search(a["text"] or ""))


def sec_quote(tk):
    for q in QUOTE_Q:
        if D.spent >= CAP:
            return
        a = run(tk, "quote", M.prov(SV, {"fragment": q}))
        t = a["text"] or ""
        rows[-1]["quoted"] = [m.group(1) for m in QUOTE.finditer(t) if len(m.group(1).split()) >= 4]
        rows[-1]["says_cannot"] = bool(re.search(r"kan inte citera", t, re.I))


def raw(tok, body):
    o = D.call("POST", "/functions/v1/answer", body, tok, timeout=60)
    b = D.jbody(o) if o["status"] != 200 else None
    if o["status"] == 200:
        D.cost(D.sse(o)["done"])
    code = ((b or {}).get("error") or {}).get("code") if isinstance(b, dict) else None
    return {"status": o["status"], "ms": o["ms"], "retry_after": o["headers"].get("retry-after"), "code": code,
            "msg": ((b or {}).get("error") or {}).get("message") if isinstance(b, dict) else None}


def sec_rate():
    q = lambda i: {"fragment": f"vad är {i} plus {i}", "mode": "auto", "language": "sv", "context": {}}
    # R1: one fresh user, 25 calls back to back (sequential, no pause): where does the per-minute cap (20) bite?
    tok = D.signup()
    for i in range(25):
        r = raw(tok, q(i))
        rec(kind="rate:R1_sequential", i=i + 1, **r)
    # R2: like Kevin's rerun: 2 fresh users, interview questions alternating every 3 s, 20 calls
    toks = [D.signup(), D.signup()]
    iv = lambda t: {"fragment": t, "mode": "tutor", "language": "sv", "persona": "interview", "persona_setup": M.AD + " CV: " + M.CV, "context": {}, "turn": "question"}
    qs = ["berätta om dig själv", "varför vill du jobba här", "hur hanterar du en arg kund", "vad är din största styrka", "vad är din svaghet"] * 4
    for i, t in enumerate(qs):
        if D.spent >= CAP:
            break
        r = raw(toks[i % 2], iv(t))
        rec(kind="rate:R2_interview_3s", i=i + 1, user=i % 2, **r)
        time.sleep(3.0)
    # R3: 6 parallel calls from one fresh user (the app can overlap a cancelled and a new turn)
    tok = D.signup()
    with cf.ThreadPoolExecutor(6) as ex:
        for i, r in enumerate(ex.map(lambda i: raw(tok, q(100 + i)), range(6))):
            rec(kind="rate:R3_parallel6", i=i + 1, **r)


def main():
    secs = sys.argv[1:] or ["time", "stump", "quote", "rate"]
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    print("backend", M.backend_state(), flush=True)
    tk = Tok()
    for s in secs:
        if s == "rate":
            sec_rate()
        else:
            {"time": sec_time, "stump": sec_stump, "quote": sec_quote}[s](tk)
    path = ROOT / "reports/qa/data" / f"{stamp}-o14.json"
    path.write_text(json.dumps({"stamp": stamp, "spent_usd": round(D.spent, 4), "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("spent", round(D.spent, 4), "->", path)


if __name__ == "__main__":
    main()
