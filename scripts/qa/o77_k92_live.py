"""O77: K92 (D215 punkt 8, POST /drill action "cost") live med testkonton (Oscar moln, 2026-11-17).
Kör i Actions (oscar-live.yml):  python -I -X utf8 scripts/qa/o77_k92_live.py
Bara testkonton (qa_testaccount: x-earmind-test + script-UA), teströsten, 0 ElevenLabs, 0 Claude.
Kollar: förhandsvisningens cost = det save sedan drar, ny text kostar sitt antal tecken, text med ljud kostar 0,
inget sparas/köas/räknas, enough, och gränsen 20/min och 300/dag (429 rate_limited). Gränsdelen tar cirka 15 min."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import json, random, re, time, urllib.request  # noqa: E402

sys = _s
sys.stdout.reconfigure(encoding="utf-8")
OK = []
RNG = random.Random(time.time())


def word():
    return "".join(RNG.choice("bdfghjklmnprstv") + RNG.choice("aeiouy") for _ in range(3))


def text(n):
    out = word().capitalize()
    while len(out) < n:
        out += " " + word()
    out = out[: n - 1]
    if out.endswith(" "):
        out = out[:-1] + "a"
    return out + "."


def call(body, tok, mode=None):
    extra = {"x-earmind-test": f"oscar-qa {mode}"} if mode else None
    req = urllib.request.Request(T.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST", headers=T.headers(tok, True, extra))
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return r.status, json.loads(r.read() or b"{}"), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}"), dict(e.headers)


def quota(tok):
    q = call({"action": "quota"}, tok)[1]
    return {k: q.get(k) for k in ("limit", "used", "remaining")}


def count(tok):
    return len(call({"action": "list"}, tok)[1].get("drills") or [])


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:900], flush=True)


def tbody(action, parts, did=None, defer=True, title="O77"):
    d = {"kind": "text", "title": f"{title} (QA)", "subject": "Historia"}
    if did:
        d["id"] = did
    b = {"action": action, "drill": d, "items": [{"kind": k, "text": t} for k, t in parts]}
    if defer and action == "save":
        b["defer_audio"] = True
    return b


def cv(j):  # förhandsvisningens fält
    return {k: j.get(k) for k in ("cost", "remaining", "limit", "unit", "enough")} | ({"error": (j.get("error") or {}).get("code")} if j.get("error") else {})


def sv(j):  # save/start-fält
    a = j.get("audio") or {}
    return {k: v for k, v in {"cost": j.get("cost"), "audio.cost": a.get("cost"), "error": (j.get("error") or {}).get("message"), "drill": ((j.get("drill") or {}).get("id") or "")[:8]}.items() if v is not None}


def wait_audio(tok, did):
    a = {}
    for _ in range(30):
        a = call({"action": "status", "id": did}, tok)[1].get("audio") or {}
        if a.get("total") and a.get("done") == a.get("total"):
            break
        time.sleep(2)
    return {k: a.get(k) for k in ("total", "done", "failed")}


DAY_ONLY = "--day-only" in sys.argv[1:]
if DAY_ONLY:
    print("bara gränsen per dag (7)", flush=True)
# 1: ny text, förhandsvisning två gånger med paus emellan, inget sparat/köat/räknat, sedan save = samma cost
if not DAY_ONLY:
    A = T.signup(True)[0]
    p1 = [("heading", text(40)), ("para", text(300)), ("para", text(180))]
    n1 = sum(len(t) for _, t in p1)
    q0, c0 = quota(A), count(A)
    s1, j1, _ = call(tbody("cost", p1), A)
    time.sleep(20)
    s1b, j1b, _ = call(tbody("cost", p1), A)
    q1, c1 = quota(A), count(A)
    check(f"1 ny text på {n1} tecken: cost {n1} två gånger (20 s emellan), inget prov, kvoten orörd",
          s1 == s1b == 200 and j1.get("cost") == j1b.get("cost") == n1 and j1.get("enough") is True and j1.get("unit") == "chars"
          and c1 == c0 == 0 and q1 == q0 and j1.get("remaining") == q0["remaining"] and j1.get("limit") == 1500,
          {"cost 1": [s1, cv(j1)], "cost 2": [s1b, cv(j1b)], "prov före/efter": [c0, c1], "kvot före/efter": [q0, q1]})

    # 1b: B förhandsvisar samma text: ingen annan har ljud, så också B ska få full kostnad (inget köat av A:s förhandsvisning)
    B = T.signup(True)[0]
    s, jb, _ = call(tbody("cost", p1), B)
    check(f"1b samma text från konto B efter A:s förhandsvisning: cost {n1} (inget ljud gjort)", s == 200 and jb.get("cost") == n1, {"B cost": [s, cv(jb)]})

    # 2: save + start drar det förhandsvisningen sa
    s2, j2, _ = call(tbody("save", p1), A)
    d1 = (j2.get("drill") or {}).get("id")
    s2s, j2s, _ = call({"action": "start", "id": d1}, A)
    q2 = quota(A)
    check(f"2 save/start drar samma som förhandsvisningen ({n1})",
          s2 == s2s == 200 and (j2.get("audio") or {}).get("cost") == j1.get("cost") and q2["used"] - q1["used"] == j1.get("cost"),
          {"save": [s2, sv(j2)], "start": [s2s, sv(j2s)], "kvot": [q1, q2]})

    # 3: när ljudet finns kostar samma text 0, för A och för B, och en blandning kostar bara det nya
    au = wait_audio(A, d1)
    s3a, j3a, _ = call(tbody("cost", p1), A)
    s3b, j3b, _ = call(tbody("cost", p1), B)
    new = text(120)
    mix = [p1[1], ("para", new)]
    s3m, j3m, _ = call(tbody("cost", mix), B)
    s3ms, j3ms, _ = call(tbody("save", mix, title="O77-3 B blandning"), B)
    check("3 text med ljud kostar 0 (A och B); blandning kostar bara de nya 120, och B:s save säger samma",
          j3a.get("cost") == 0 and j3b.get("cost") == 0 and j3m.get("cost") == 120 and (j3ms.get("audio") or {}).get("cost") == 120,
          {"ljud": au, "A cost": cv(j3a), "B cost": cv(j3b), "B blandning cost": cv(j3m), "B save": [s3ms, sv(j3ms)]})

    # 4: ändring av A:s prov (drill.id): ett nytt stycke på 90 tecken; förhandsvisning = save
    ed = p1 + [("para", text(90))]
    s4, j4, _ = call(tbody("cost", ed, did=d1), A)
    c4 = count(A)
    q4a = quota(A)
    s4s, j4s, _ = call(tbody("save", ed, did=d1), A)
    q4b = quota(A)
    check("4 ändring med drill.id: cost 90 = save, inget nytt prov av förhandsvisningen",
          j4.get("cost") == 90 and j4s.get("cost") == 90 and c4 == 1 and q4b["used"] - q4a["used"] == 90,  # startat prov: save köar direkt, audio.cost 0, cost = det som dras
          {"cost": [s4, cv(j4)], "prov efter cost": c4, "save": [s4s, sv(j4s)], "kvot före/efter save": [q4a, q4b]})

    # 5: frågeprov och blanktecken
    C = T.signup(True)[0]
    its = [{"question": text(30)[:-1] + "?", "short": "Kort.", "long": "Kort. " + text(120)}, {"question": text(25)[:-1] + "?", "short": "Ja.", "long": "Ja. " + text(80)}]
    exp = sum(len(i["question"]) + len(i["long"]) for i in its)
    s5, j5, _ = call({"action": "cost", "drill": {"title": "O77-5 (QA)", "subject": "Biologi"}, "items": its}, C)
    s5s, j5s, _ = call({"action": "save", "defer_audio": True, "drill": {"title": "O77-5 (QA)", "subject": "Biologi"}, "items": its}, C)
    raw = "  " + text(60).replace(" ", "   ", 3) + "\n\n  "
    cl = len(re.sub(r"\s+", " ", raw).strip())
    s6, j6, _ = call(tbody("cost", [("para", raw)]), C)
    check(f"5 frågeprov cost {exp} = save; blanktecken: cost {cl} (rå {len(raw)})",
          j5.get("cost") == exp == (j5s.get("audio") or {}).get("cost") and j6.get("cost") == cl,
          {"frågor cost": cv(j5), "frågor save": [s5s, sv(j5s)], "väntat": exp, "blanktecken cost": cv(j6), "rå": len(raw), "ihop": cl})

    # 6: räcker inte: enough false, inget sparat; save ger 402 med samma cost
    D = T.signup(True)[0]
    big = [("para", text(800)), ("para", text(800))]
    s7, j7, _ = call(tbody("cost", big), D)
    c7 = count(D)
    s7s, j7s, _ = call(tbody("save", big), D)
    check("6 1 600 tecken: enough false, inget prov; save ger 402 med samma cost",
          s7 == 200 and j7.get("cost") == 1600 and j7.get("enough") is False and c7 == 0 and s7s == 402 and j7s.get("cost") == 1600 and count(D) == 0,
          {"cost": [s7, cv(j7)], "prov": c7, "save": [s7s, sv(j7s), {k: j7s.get(k) for k in ("cost", "remaining")}]})

    # städa före gränstestet
    for tok in (A, B, C, D):
        for d in call({"action": "list"}, tok)[1].get("drills") or []:
            call({"action": "delete", "id": d["id"]}, tok)

# 7: gränsen 20/min och 300/dag på ett nytt konto. Fasta fönster: börja direkt efter ett minutskifte.
R = T.signup(True)[0]
small = [("para", text(20))]
okc, per_min, first429, day429 = 0, [], None, None
while time.time() % 60 > 2:
    time.sleep(0.5)
for w in range(18):
    win_ok, t_end = 0, (int(time.time() // 60) + 1) * 60
    for i in range(22):
        s, j, h = call(tbody("cost", small), R)
        if s == 200:
            okc += 1
            win_ok += 1
        elif s == 429:
            info = {"anrop": i + 1, "fönster": w + 1, "kod": (j.get("error") or {}).get("code"), "text": (j.get("error") or {}).get("message"), "retry-after": h.get("Retry-After") or h.get("retry-after")}
            if first429 is None:
                first429 = info
            if okc >= 300 and i == 0:
                day429 = info  # första anropet i ett nytt minutfönster nekas: dagens gräns, inte minutens
            break
        else:
            print("     oväntat", s, j, flush=True)
            break
    per_min.append(win_ok)
    if day429:
        break
    while time.time() < t_end + 1:
        time.sleep(0.5)
print("     godkända per minutfönster:", per_min, flush=True)
check("7a gränsen per minut: 20 godkända, anrop 21 ger 429 rate_limited", first429 and first429["anrop"] == 21 and first429["kod"] == "rate_limited" and all(x <= 20 for x in per_min),
      {"första 429": first429, "per minut": per_min})
check("7b gränsen per dag: 300 godkända totalt, sedan 429 (lång retry-after)", okc == 300 and day429 is not None and int(day429.get("retry-after") or 0) > 60,
      {"godkända totalt": okc, "dagens 429": day429, "kvot": quota(R), "prov": count(R)})

print(f"\n=== O77 {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
