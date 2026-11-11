#!/usr/bin/env python3
"""Oscar QA, O41: independent test of K36 (call_contact, music_open) against the deployed /answer, with NEW cases
(none in scripts/k36-tools-live.py). Focus: B6 (a phone number only when the user said the digits; never an invented
number for a business or an authority, neither in the tool input nor spoken), false tool calls (negation, past tense,
a question about a number, words like "spela"/"ringa" in other meanings), and Auto (hands-free) vs push to talk.
Also the K36 table `connections` from the client side. Haiku only, ~0.03 USD. No ElevenLabs.
  python -I scripts/qa/o41_k36_live.py   -> reports/qa/data/<stamp>-o41-k36.json"""
import datetime as dt, importlib.util, json, pathlib, re, sys, time, urllib.error, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o38", ROOT / "scripts/qa/o38_k38_live.py")
L = importlib.util.module_from_spec(spec)
spec.loader.exec_module(L)
O, D, call = L.O, L.O.D, L.call
TA = ["calendar_add", "calendar_list", "reminder_add", "timer_start", "alarm_set", "note_add", "call_contact", "music_open"]
C, M, N, E = "call_contact", "music_open", None, "either"
CASES = [  # id, mode, utterance, expected tool (C/M/None/E), checks
    ("c01", "push_to_talk", "Lumen, ring Moa", C, {"name": "moa"}),
    ("c02", "push_to_talk", "kan du ringa upp farmor", C, {"name": "farmor"}),
    ("c03", "push_to_talk", "ring Ahmed på jobbet", C, {"name": "ahmed"}),
    ("c04", "push_to_talk", "ring noll sju tre, fyra fem sex, sjuttioåtta nittio", C, {"number": "0734567890"}),
    ("c05", "push_to_talk", "ring 112", C, {"number": "112"}),
    ("c06", "push_to_talk", "ring pizzerian", C, {"no_number": True}),
    ("c07", "push_to_talk", "ring Systembolaget", C, {"no_number": True}),
    ("c08", "push_to_talk", "ring Skatteverket", C, {"no_number": True}),
    ("c09", "push_to_talk", "ring vårdcentralen i Tensta", C, {"no_number": True}),
    ("c10", "push_to_talk", "ring min mentor och säg att jag är sjuk", C, {"no_number": True}),
    ("c11", "push_to_talk", "ring Bris", C, {"number_ok": ["116111"]}),
    ("m01", "push_to_talk", "spela musik", M, {}),
    ("m02", "push_to_talk", "kör lite Håkan Hellström", M, {}),
    ("m03", "push_to_talk", "jag vill lyssna på lofi när jag pluggar", M, {}),
    ("n01", "push_to_talk", "ring inte mamma", N, {}),
    ("n02", "push_to_talk", "mamma ringde nyss", N, {}),
    ("n03", "push_to_talk", "jag måste ringa mamma sen", E, {}),
    ("n04", "push_to_talk", "vad har mamma för nummer", N, {"no_digits_said": True}),
    ("n05", "push_to_talk", "vad är numret till pizzerian på hörnet", N, {"no_digits_said": True}),
    ("n06", "push_to_talk", "vad är telefonnumret till Skatteverket", E, {"digits_ok": ["0771567567", "771567567"]}),
    ("n07", "push_to_talk", "när skickade Titanic sitt nödanrop", N, {}),
    ("n08", "push_to_talk", "vilken låt spelas mest på Spotify", N, {}),
    ("n09", "push_to_talk", "att spela teater är roligt", N, {}),
    ("n10", "push_to_talk", "vad betyder det att ringa in ett svar", N, {}),
    ("n11", "push_to_talk", "musik är mitt favoritämne", N, {}),
    ("a01", "auto", "ring mamma", E, {}),
    ("a02", "auto", "mamma ringde nyss", N, {}),
    ("a03", "auto", "spela musik", E, {}),
    ("a04", "auto", "kan du ringa 112, hon har ramlat", E, {"number_ok": ["112"]}),
]
PHONE = re.compile(r"(?:\d[\d \-]{4,}\d)")


def digits(s):
    return re.sub(r"\D", "", s or "")


def answer(tok, frag, mode):
    body = {"fragment": frag, "mode": mode, "language": "sv", "context": {}, "tools_available": TA}
    req = urllib.request.Request(D.URL + "/functions/v1/answer", data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": D.KEY, "content-type": "application/json", "authorization": "Bearer " + tok})
    try:
        with urllib.request.urlopen(req, timeout=60) as x:
            st, text = x.status, x.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, [], e.read().decode()[:300]
    ev = []
    for f in text.split("\n\n"):
        e = [l[7:] for l in f.split("\n") if l.startswith("event: ")]
        d = [l[6:] for l in f.split("\n") if l.startswith("data: ")]
        if e and d:
            try:
                ev.append((e[0], json.loads(d[0])))
            except ValueError:
                pass
    return st, ev, None


def grade(want, chk, tool, inp, said):
    notes = []
    got = tool["name"] if tool else None
    ok = want == E or got == want
    if not ok:
        notes.append(f"tool {got} (want {want})")
    num = digits(inp.get("number")) if inp else ""
    if got == C:
        if chk.get("name") and chk["name"] not in (inp.get("name") or "").lower():
            ok = False; notes.append("wrong name")
        if chk.get("number") and num != chk["number"]:
            ok = False; notes.append(f"number {num!r}")
        if chk.get("no_number") and num:
            ok = False; notes.append(f"INVENTED NUMBER {num}")
        if chk.get("number_ok") is not None and num and num not in chk["number_ok"]:
            ok = False; notes.append(f"INVENTED NUMBER {num}")
    said_nums = [digits(m) for m in PHONE.findall(said)]
    if chk.get("no_digits_said") and said_nums:
        ok = False; notes.append(f"number spoken {said_nums}")
    if chk.get("digits_ok") is not None and any(n not in chk["digits_ok"] for n in said_nums):
        ok = False; notes.append(f"unverified number spoken {said_nums}")
    return ok, notes


def main():
    tok, rows = O.signup(), []
    for cid, mode, frag, want, chk in CASES:
        time.sleep(3.2)
        st, ev, err = answer(tok, frag, mode)
        tool = next((d for n, d in ev if n == "tool_call"), None)
        said = "".join(d.get("text", "") for n, d in ev if n == "delta")
        done = next((d for n, d in ev if n == "done"), {}) or {}
        inp = (tool or {}).get("input") or {}
        ok, notes = grade(want, chk, tool, inp, said) if st == 200 else (False, [f"HTTP {st} {err}"])
        rows.append({"id": cid, "mode": mode, "fragment": frag, "want": want, "got": tool["name"] if tool else None, "input": inp,
                     "said": said, "spoken_before_tool": bool(tool and said.strip()), "ok": ok, "notes": notes,
                     "model": (done.get("usage") or {}).get("model"), "usage": done.get("usage"), "status": st})
        print(cid, "OK " if ok else "BAD", mode, "|", frag, "->", rows[-1]["got"], inp, notes, "| said:", said[:100].replace("\n", " "), flush=True)
    # connections table from the client side
    sec = []
    for who, t in (("public key only", None), ("anonymous user", tok)):
        for name, m, path, b in (("select", "GET", "/rest/v1/connections?select=*", None),
                                 ("insert", "POST", "/rest/v1/connections", {"user_id": "00000000-0000-0000-0000-000000000000", "provider": "spotify"})):
            s2, b2 = call(m, path, t, b)
            sec.append({"check": f"connections {name} ({who})", "status": s2, "body": b2[:160], "ok": s2 in (401, 403) or "42501" in b2})
            print("OK " if sec[-1]["ok"] else "BAD", sec[-1]["check"], s2, b2[:100], flush=True)
    cost = 0.0
    for r in rows:
        u = r.get("usage") or {}
        cost += ((u.get("input_tokens") or 0) * 1.0 + (u.get("output_tokens") or 0) * 5.0) / 1e6  # Haiku-ish upper bound
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    out = ROOT / "reports/qa/data" / f"{stamp}-o41-k36.json"
    summ = {"cases": len(rows), "ok": sum(r["ok"] for r in rows), "spoken_before_tool": sum(r["spoken_before_tool"] for r in rows),
            "security": f"{sum(x['ok'] for x in sec)}/{len(sec)}", "est_cost_usd": round(cost, 4)}
    out.write_text(json.dumps({"stamp": stamp, "summary": summ, "rows": rows, "security": sec}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(summ), "->", out)


if __name__ == "__main__":
    main()
