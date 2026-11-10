#!/usr/bin/env python3
"""K35 live check: phone tools in Standardläge (push to talk) against the deployed /answer (Haiku), anonymous user.
Prints per case the tool called (or none) and what would be spoken; writes reports/eval/k35-tools-<date>.json.
  python -X utf8 -I scripts/k35-tools-live.py"""
import datetime, json, pathlib, sys, urllib.request
U = "https://xjczbzfkmbjdebwlccki.supabase.co"; K = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design
TA = ["calendar_add", "calendar_list", "reminder_add", "timer_start", "alarm_set", "note_add"]
CASES = [  # [utterance, expected tool or None]
    ["lägg in tandläkaren på torsdag klockan tre", "calendar_add"],
    ["boka in fotbollsträning på lördag klockan tio", "calendar_add"],
    ["sätt en timer på fem minuter", "timer_start"],
    ["påminn mig att ta med gympakläder i morgon klockan sju", "reminder_add"],
    ["väck mig klockan halv sju", "alarm_set"],
    ["vad har jag i kalendern i morgon", "calendar_list"],
    ["spara en anteckning: köp mjölk och bröd", "note_add"],
    ["vad är huvudstaden i Frankrike", None],
    ["hur lång tid tar det att koka ägg", None],
    ["vad betyder ordet påminnelse", None],
    ["när var franska revolutionen", None],
    ["min kompis sa att hon skulle boka biljetter", None],
]
def post(path, body, tok=None):
    h = {"apikey": K, "content-type": "application/json", **({"authorization": "Bearer " + tok} if tok else {})}
    r = urllib.request.Request(U + path, data=json.dumps(body).encode(), headers=h, method="POST")
    with urllib.request.urlopen(r, timeout=40) as x:
        return x.read().decode()
def evs(t):
    out = []
    for f in t.split("\n\n"):
        e = [l[7:] for l in f.split("\n") if l.startswith("event: ")]; d = [l[6:] for l in f.split("\n") if l.startswith("data: ")]
        if e and d: out.append((e[0], json.loads(d[0])))
    return out
tok = json.loads(post("/auth/v1/signup", {}))["access_token"]
rows = []
for frag, want in CASES:
    e = evs(post("/functions/v1/answer", {"fragment": frag, "mode": "push_to_talk", "language": "sv", "context": {}, "tools_available": TA}, tok))
    tc = next((d for n, d in e if n == "tool_call"), None)
    said = "".join(d.get("text", "") for n, d in e if n == "delta")
    got = tc["name"] if tc else None
    rows.append({"fragment": frag, "want": want, "got": got, "ok": got == want, "input": tc and tc["input"], "confirm": tc and tc["confirm"], "said": said})
    print("OK " if got == want else "BAD", frag, "->", got, tc and tc["input"], "| said:", said[:90])
s = {"cases": len(rows), "right": sum(r["ok"] for r in rows), "spoken_before_tool": sum(1 for r in rows if r["got"] and r["said"].strip())}
print(s)
out = pathlib.Path(__file__).resolve().parents[1] / "reports" / "eval" / f"k35-tools-{datetime.date.today()}.json"
out.write_text(json.dumps({"summary": s, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
