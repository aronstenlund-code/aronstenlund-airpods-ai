#!/usr/bin/env python3
"""K44 live (Standardläge, mode auto): 30 'kan du …?' for things the app can do (yes or done), 10 for things it cannot
(an honest no), identity questions (never 'studieassistent'), help questions. Raw data -> reports/eval/<stamp>-k44-live.json.
  python3 -X utf8 -I scripts/k44-live.py"""
import datetime, json, pathlib, re, time, urllib.error, urllib.request, zoneinfo
U = "https://xjczbzfkmbjdebwlccki.supabase.co"; K = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
CAN = ["Kan du sätta en timer på tio minuter?", "Kan du spela musik?", "Kan du lägga in ett möte i min kalender?", "kan du påminna mig om saker",
       "kan du väcka mig i morgon bitti", "kan du ringa folk", "kan du förhöra mig", "kan du spara en anteckning", "kan du översätta saker",
       "kan du hjälpa mig med läxan", "kan du ge mig ett träningspass", "kan du ställa ett larm", "har du en timer", "går det att boka in ett möte",
       "kan du söka på nätet", "kan du kolla vädret", "kan du hjälpa mig inför en jobbintervju", "kan du hjälpa mig att plugga", "kan du komma ihåg saker åt mig",
       "kan du ringa mamma", "kan du spela en låt", "kan du svara på frågor", "kan du ta tid när jag springer", "kan du skriva ner det jag säger",
       "kan du hjälpa mig med vad jag ska säga", "kan du se vad jag har i dag", "går det att få en påminnelse", "kan du öppna spotify",
       "klarar du att sätta en äggklocka", "kan du väcka mig"]
CANNOT = ["kan du skicka sms till Elin", "kan du skicka ett mejl", "kan du läsa mina mejl", "kan du betala", "kan du beställa pizza",
          "kan du ta en bild", "kan du styra lamporna", "kan du ge mig vägbeskrivning", "kan du läsa mina notiser", "kan du boka resor"]
IDENT = ["Vad är Earmind?", "Vad kan du göra?", "vem är du", "vad är du för app", "vad kan du hjälpa mig med", "vad heter du"]
HELP = ["Hur stänger jag av dig?", "hur pausar jag dig", "hur byter jag läge", "hur byter jag röst", "hur startar jag appen"]


def post(path, body, tok=None):
    h = {"apikey": K, "content-type": "application/json", **({"authorization": "Bearer " + tok} if tok else {})}
    for i in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request(U + path, data=json.dumps(body).encode(), headers=h), timeout=90) as r:
                return r.read().decode()
        except urllib.error.HTTPError as e:
            if e.code != 429 or i == 5: raise
            time.sleep(20)


def ask(tok, q):
    t = post("/functions/v1/answer", {"fragment": q, "mode": "auto", "language": "sv", "context": {"transcript": q}}, tok)
    said = "".join(json.loads(f.split("data: ", 1)[1]).get("text", "") for f in t.split("\n\n") if f.startswith("event: delta"))
    return said.strip(), ("tool_call" in t or "app_command" in t)


tok = json.loads(post("/auth/v1/signup", {}))["access_token"]
rows, s = [], {}
DENY = re.compile(r"jag kan (?:tyvärr )?inte|kan jag (?:tyvärr )?inte|har inte möjlighet|inte möjligt för mig", re.I)
for part, qs in [("can", CAN), ("cannot", CANNOT), ("identity", IDENT), ("help", HELP)]:
    ok = 0
    for q in qs:
        said, acted = ask(tok, q); low = said.lower()
        # yes, or done (the model carried it out: "Här är ett pass …", "Absolut, …"), never a denial or silence
        if part == "can": good = acted or (bool(said) and not DENY.search(said) and not re.match(r"nej\b", low) and "studieassistent" not in low)
        elif part == "cannot": good = low.startswith("nej") or bool(DENY.search(said)) or "inte än" in low
        elif part == "identity": good = "studieassistent" not in low and "studiehjälp" not in low and bool(said)
        else: good = bool(said) and len(said) < 260
        ok += good
        rows.append({"part": part, "q": q, "said": said, "acted": acted, "ok": good})
        print("OK " if good else "BAD", part, q, "->", said[:100], flush=True)
        time.sleep(0.4)
    s[part] = f"{ok}/{len(qs)}"
s["studieassistent"] = sum("studieassistent" in r["said"].lower() for r in rows)
print(s)
stamp = datetime.datetime.now(zoneinfo.ZoneInfo("Europe/Stockholm")).strftime("%Y-%m-%d-%H%M")
out = pathlib.Path(__file__).resolve().parents[1] / "reports" / "eval" / f"{stamp}-k44-live.json"
out.write_text(json.dumps({"summary": s, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
print(out)
