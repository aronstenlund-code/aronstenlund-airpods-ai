#!/usr/bin/env python3
"""K36 live check: the new phone tools (call_contact, music_open) next to the K35 ones, against the deployed /answer
(Standardläge, push to talk, Haiku), anonymous user; plus /connect without Spotify secrets (503, list, callback).
Writes reports/eval/<stamp>-k36-tools-live.json.
  python3 -X utf8 -I scripts/k36-tools-live.py"""
import datetime, json, pathlib, urllib.error, urllib.request, zoneinfo
U = "https://xjczbzfkmbjdebwlccki.supabase.co"; K = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design
TA = ["calendar_add", "calendar_list", "reminder_add", "timer_start", "alarm_set", "note_add", "call_contact", "music_open"]
import os
MODE = os.environ.get("MODE", "push_to_talk")  # O41: the app sends Standardläge as "auto"
PREFIX = "Lumen, " if MODE == "auto" else ""
CASES = [  # [utterance, expected tool or None, expected input subset]
    ["ring mamma", "call_contact", {"name": "mamma"}],
    ["kan du ringa Elin", "call_contact", {"name": "Elin"}],
    ["ring 070 123 45 67", "call_contact", {"number": True}],
    ["slå en signal till pappa", "call_contact", {"name": "pappa"}],
    ["ring tandläkaren", "call_contact", {"no_number": True}],
    ["spela lugn pluggmusik", "music_open", {}],
    ["sätt på lite musik av Veronica Maggio", "music_open", {}],
    ["vad är huvudstaden i Norge", None, {}],
    ["vem ringde Graham Bell först", None, {}],
    ["vad betyder ordet signal", None, {}],
    ["hur spelar man gitarr", None, {}],
    ["min kompis ringde mig i går", None, {}],
    ["sätt en timer på tio minuter", "timer_start", {}],
    ["ring 112", "call_contact", {"number": True}],
    ["mamma ringde nyss", None, {}],
    ["kör lite lofi", "music_open", {}],
]


def req(method, path, body=None, tok=None):
    h = {"apikey": K, "content-type": "application/json", **({"authorization": "Bearer " + tok} if tok else {})}
    r = urllib.request.Request(U + path, data=json.dumps(body).encode() if body is not None else None, headers=h, method=method)

    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *a, **k):
            return None
    try:
        with urllib.request.build_opener(NoRedirect).open(r, timeout=40) as x:
            return x.status, x.read().decode(), dict(x.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(), dict(e.headers)


def evs(t):
    out = []
    for f in t.split("\n\n"):
        e = [l[7:] for l in f.split("\n") if l.startswith("event: ")]; d = [l[6:] for l in f.split("\n") if l.startswith("data: ")]
        if e and d: out.append((e[0], json.loads(d[0])))
    return out


tok = json.loads(req("POST", "/auth/v1/signup", {})[1])["access_token"]
rows = []
for frag, want, sub in CASES:
    if MODE == "auto" and want:
        frag = PREFIX + frag  # an addressed request in Standardläge
    e = evs(req("POST", "/functions/v1/answer", {"fragment": frag, "mode": MODE, "language": "sv", "context": {}, "tools_available": TA}, tok)[1])
    tc = next((d for n, d in e if n == "tool_call"), None)
    said = "".join(d.get("text", "") for n, d in e if n == "delta")
    got = tc["name"] if tc else None
    inp = (tc or {}).get("input") or {}
    ok = got == want
    if ok and sub.get("name"): ok = inp.get("name", "").lower() == sub["name"].lower()
    if ok and sub.get("number"): ok = bool(inp.get("number"))
    if ok and sub.get("no_number"): ok = "number" not in inp
    rows.append({"fragment": frag, "want": want, "got": got, "ok": ok, "input": inp, "confirm": tc and tc.get("confirm"), "said": said})
    print("OK " if ok else "BAD", frag, "->", got, inp, "| said:", said[:90], flush=True)
connect = {
    "post_unconfigured": req("POST", "/functions/v1/connect", {"provider": "spotify"}, tok)[0],
    "list": json.loads(req("GET", "/functions/v1/connect", None, tok)[1]),
    "no_jwt": req("GET", "/functions/v1/connect")[0],
    "callback_forged": req("GET", "/functions/v1/connect/callback?code=x&state=forged.y")[2].get("Location") or req("GET", "/functions/v1/connect/callback?code=x&state=forged.y")[2].get("location"),
}
print(json.dumps(connect, ensure_ascii=False))
s = {"cases": len(rows), "right": sum(r["ok"] for r in rows), "spoken_before_tool": sum(1 for r in rows if r["got"] and r["said"].strip())}
print(s)
stamp = datetime.datetime.now(zoneinfo.ZoneInfo("Europe/Stockholm")).strftime("%Y-%m-%d-%H%M")
out = pathlib.Path(__file__).resolve().parents[1] / "reports" / "eval" / f"{stamp}-k36-tools-live-{MODE}.json"
out.write_text(json.dumps({"summary": s, "rows": rows, "connect": connect}, ensure_ascii=False, indent=1), encoding="utf-8")
print(out)
