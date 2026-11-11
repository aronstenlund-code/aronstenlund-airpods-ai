#!/usr/bin/env python3
"""Kevin, stående omgång 2 live: Oscar's O34 groups 13 (questions about Lumen) and 14 (links in own words) in Auto,
as his o15 runner sends them (mode auto, no profile), plus the two Provläge link cases. Records what was said, the
model path and the link. Raw data -> reports/eval/<stamp>-k-standing2-live.json.
  python3 -X utf8 -I scripts/k-standing2-live.py"""
import datetime, json, pathlib, time, urllib.request, zoneinfo
U = "https://xjczbzfkmbjdebwlccki.supabase.co"; K = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
G13 = ["Lumen, är du en människa eller en robot", "är det chatgpt", "vem har gjort dig", "lyssnar du på mig nu",
       "spelar du in lektionen", "lyssnar du när appen är stängd", "kan läraren se vad jag frågar",
       "kan mina föräldrar läsa mina frågor", "säljer ni min data", "vart skickas ljudet"]
G14 = ["kan du hitta en film om cellen", "jag vill se en film om vulkaner", "visa en video om Pythagoras sats",
       "finns det nån bra sida om fotosyntes", "kan du länka något om DNA", "var kan jag läsa mer om klimatförändringar",
       "någon youtube om derivata", "har du nåt bra på UR om demokrati"]
PROV = [("har du något klipp om franska revolutionen", "Ämne: Historia. Årskurs: 9."), ("kan du rekommendera en film om derivata", "Ämne: Matematik. Kurs: Matematik 3c.")]


def post(path, body, tok=None):
    h = {"apikey": K, "content-type": "application/json", **({"authorization": "Bearer " + tok} if tok else {})}
    with urllib.request.urlopen(urllib.request.Request(U + path, data=json.dumps(body).encode(), headers=h), timeout=60) as r:
        return r.read().decode()


def evs(t):
    out = []
    for f in t.split("\n\n"):
        e = [l[7:] for l in f.split("\n") if l.startswith("event: ")]; d = [l[6:] for l in f.split("\n") if l.startswith("data: ")]
        if e and d: out.append((e[0], json.loads(d[0])))
    return out


tok = json.loads(post("/auth/v1/signup", {}))["access_token"]
rows = []
ONLY = __import__("os").environ.get("ONLY", "")
for grp, frag, body in [("g13", f, {"fragment": f, "mode": "auto", "language": "sv", "context": {}}) for f in G13] + \
        [("g14", f, {"fragment": f, "mode": "auto", "language": "sv", "context": {}}) for f in G14] + \
        [("g14p", f, {"fragment": f, "mode": "tutor", "persona": "tutor", "language": "sv", "persona_setup": p, "context": {}}) for f, p in PROV]:
    if ONLY and not grp.startswith(ONLY):
        continue
    e = evs(post("/functions/v1/answer", body, tok))
    done = next((d for n, d in e if n == "done"), {})
    said = "".join(d.get("text", "") for n, d in e if n == "delta")
    res = done.get("resource")
    rows.append({"group": grp, "q": frag, "said": said, "model": (done.get("usage") or {}).get("model"), "resource": res})
    print(grp, repr(frag), "->", (done.get("usage") or {}).get("model"), "|", (res or {}).get("url"), "|", said[:110], flush=True)
    time.sleep(16 if grp.startswith("g14") else 1)  # the link search is capped at 5 per minute per user
s = {"g13_self": sum(1 for r in rows if r["group"] == "g13" and r["model"] == "self"),
     "g14_links": sum(1 for r in rows if r["group"].startswith("g14") and r["resource"]),
     "g14_total": sum(1 for r in rows if r["group"].startswith("g14"))}
print(s)
stamp = datetime.datetime.now(zoneinfo.ZoneInfo("Europe/Stockholm")).strftime("%Y-%m-%d-%H%M")
out = pathlib.Path(__file__).resolve().parents[1] / "reports" / "eval" / f"{stamp}-k-standing2-live.json"
out.write_text(json.dumps({"summary": s, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
print(out)
