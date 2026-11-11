#!/usr/bin/env python3
"""K42 live (Aron's phone test 18:58, Standardläge): the name (10 phrasings), Swedish facts (21, Vättern/Vänern first)
and a spoken length ("hundra ord", "en mening", "kort", "utförligt") in Standardläge (mode auto) and text.
Raw data -> reports/eval/<stamp>-k42-live-<tag>.json.   TAG=before python3 -X utf8 -I scripts/k42-live.py [name|facts|length]"""
import datetime, json, os, pathlib, re, sys, time, urllib.error, urllib.request, zoneinfo
U = "https://xjczbzfkmbjdebwlccki.supabase.co"; K = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
NAMES = ["Vad heter du?", "vad är ditt namn", "har du ett namn", "Lumen, vad heter du?", "vad ska jag kalla dig",
         "vem är du", "hur heter du", "vad heter du egentligen", "heter du något", "Lumen vem är du"]
FACTS = [  # (question, any of these must be said, none of these)
    ("Vilken är Sveriges största sjö?", ["vänern"], ["vättern är sveriges största"]),
    ("Vilken är Sveriges näst största sjö?", ["vättern"], []),
    ("Vilken är Sveriges längsta flod?", ["klarälven", "göta älv"], []),
    ("Vilket är Sveriges högsta berg?", ["kebnekaise"], []),
    ("Vilken är Sveriges största ö?", ["gotland"], []),
    ("Vilken är Sveriges näst största stad?", ["göteborg"], []),
    ("Vilken är Sveriges tredje största stad?", ["malmö"], []),
    ("Vad är Norges huvudstad?", ["oslo"], []),
    ("Vad är Finlands huvudstad?", ["helsingfors"], []),
    ("Vad är Australiens huvudstad?", ["canberra"], ["sydney är huvudstad"]),
    ("Vad är Kanadas huvudstad?", ["ottawa"], []),
    ("Vilket år blev Gustav Vasa kung?", ["femtonhundratjugotre", "1523"], []),
    ("Vilket år började andra världskriget?", ["nittonhundratrettionio", "1939"], []),
    ("När fick kvinnor rösträtt i Sverige?", ["nittonhundratjugoett", "nittonhundranitton", "1921", "1919"], []),
    ("Vilket år gick Sverige med i EU?", ["nittonhundranittiofem", "1995"], []),
    ("Vilket år gick Sverige med i Nato?", ["tvåtusen tjugofyra", "2024"], []),
    ("Vilket är Sveriges största landskap?", ["lappland"], []),
    ("Vilket är Sveriges minsta landskap?", ["öland"], []),
    ("Vilken är Sveriges största nationalpark?", ["sarek", "padjelanta"], []),
    ("Hur många landskap har Sverige?", ["tjugofem"], []),
    ("Vilken är världens längsta flod?", ["nilen", "amazonas"], []),
]
LENGTH = [  # (question, target words, tolerance as share)
    ("Förklara fotosyntes med hundra ord eller mer", 100, "min"),
    ("Förklara fotosyntes med ungefär hundra ord", 100, 0.2),
    ("Berätta om andra världskriget med cirka hundrafemtio ord", 150, 0.2),
    ("Förklara cellandning med femtio ord", 50, 0.2),
    ("Förklara demokrati i en mening", 1, "sent"),
    ("Säg kort vad en atom är", 30, "max"),
    ("Förklara utförligt hur ett vaccin fungerar", 100, "min"),
    ("Förklara gravitation med två meningar", 2, "sent"),
    ("Förklara fotosyntes med trettio ord", 30, 0.2),
    ("Beskriv franska revolutionen med minst åttio ord", 80, "min"),
]


def post(path, body, tok=None):
    h = {"apikey": K, "content-type": "application/json", **({"authorization": "Bearer " + tok} if tok else {})}
    for i in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request(U + path, data=json.dumps(body).encode(), headers=h), timeout=90) as r:
                return r.read().decode()
        except urllib.error.HTTPError as e:
            if e.code != 429 or i == 5: raise
            time.sleep(20)


def ask(tok, q, mode="auto"):
    t = post("/functions/v1/answer", {"fragment": q, "mode": mode, "language": "sv", "context": {"transcript": q}}, tok)
    said, done = "", {}
    for f in t.split("\n\n"):
        if f.startswith("event: delta"): said += json.loads(f.split("data: ", 1)[1]).get("text", "")
        if f.startswith("event: more_delta"): said += json.loads(f.split("data: ", 1)[1]).get("text", "")
        if f.startswith("event: done"): done = json.loads(f.split("data: ", 1)[1])
    if done.get("more"): said = said + " " + done["more"] if isinstance(done["more"], str) else said
    return said.strip(), done


parts = sys.argv[1:] or ["name", "facts", "length"]
tok = json.loads(post("/auth/v1/signup", {}))["access_token"]
rows, summ = [], {}
if "name" in parts:
    ok = 0
    for q in NAMES:
        said, _ = ask(tok, q); good = "earmind" in said.lower() and "inget eget namn" not in said.lower(); ok += good
        rows.append({"part": "name", "q": q, "said": said, "ok": good}); print("OK " if good else "BAD", q, "->", said[:90], flush=True)
    summ["name"] = f"{ok}/{len(NAMES)}"
if "facts" in parts:
    ok = 0
    for q, must, mustnot in FACTS:
        said, _ = ask(tok, q); low = said.lower()
        good = any(m in low for m in must) and not any(n in low for n in mustnot); ok += good
        rows.append({"part": "facts", "q": q, "said": said, "ok": good}); print("OK " if good else "BAD", q, "->", said[:100], flush=True)
        time.sleep(0.5)
    summ["facts"] = f"{ok}/{len(FACTS)}"
if "length" in parts:
    ok = 0
    for q, n, tol in LENGTH:
        said, done = ask(tok, q); words = len(re.findall(r"\w+", said)); sents = len([s for s in re.split(r"[.!?]+", said) if s.strip()])
        if tol == "min": good = words >= n * 0.8
        elif tol == "max": good = words <= n * 1.2  # K42: ±20 %
        elif tol == "sent": good = sents == n
        else: good = abs(words - n) <= n * tol
        ok += good
        rows.append({"part": "length", "q": q, "words": words, "sentences": sents, "said": said, "ok": good})
        print("OK " if good else "BAD", q, "->", words, "ord,", sents, "meningar |", said[:70], flush=True)
    summ["length"] = f"{ok}/{len(LENGTH)}"
print(summ)
stamp = datetime.datetime.now(zoneinfo.ZoneInfo("Europe/Stockholm")).strftime("%Y-%m-%d-%H%M")
out = pathlib.Path(__file__).resolve().parents[1] / "reports" / "eval" / f"{stamp}-k42-live-{os.environ.get('TAG', 'run')}.json"
out.write_text(json.dumps({"summary": summ, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
print(out)
