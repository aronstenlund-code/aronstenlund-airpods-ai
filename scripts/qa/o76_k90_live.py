"""O76: K90 (D213, krediter per tecken, 1 500 i månaden) live med testkonton (Oscar moln, 2026-11-17).
Kör i Actions (oscar-live.yml):  python -I -X utf8 scripts/qa/o76_k90_live.py
Bara testkonton (qa_testaccount: x-earmind-test + script-UA), teströsten, 0 ElevenLabs. Claude: en liten /exam read.
Skriver ut siffrorna för varje fall (cost, audio.cost, used, remaining, limit) så att rapporten kan visa dem."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import json, random, re, string, time, urllib.request  # noqa: E402

sys = _s
sys.stdout.reconfigure(encoding="utf-8")
OK = []
RNG = random.Random(time.time())


def word():
    return "".join(RNG.choice("bdfghjklmnprstv") + RNG.choice("aeiouy") for _ in range(3))


def text(n):
    """En unik text på exakt n tecken: påhittade ord, versal först, punkt sist, inga dubbla blanksteg."""
    out = word().capitalize()
    while len(out) < n:
        out += " " + word()
    out = out[: n - 1]
    if out.endswith(" "):
        out = out[:-1] + "a"
    return out + "."


def call(body, tok, mode=None):
    extra = {"x-earmind-test": f"oscar-qa {mode}"} if mode else None
    req = urllib.request.Request(T.URL + "/functions/v1/" + body.pop("_fn", "drill"), data=json.dumps(body).encode(), method="POST",
                                 headers=T.headers(tok, True, extra))
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def quota(tok):
    q = call({"action": "quota"}, tok)[1]
    return {k: q.get(k) for k in ("unit", "limit", "used", "remaining", "resets_day")}


def nums(j):
    a = j.get("audio") or {}
    return {k: v for k, v in {"cost": j.get("cost"), "audio.cost": a.get("cost"), "unit": j.get("unit"), "already_saved": j.get("already_saved"),
                              "refunded_credits": j.get("refunded_credits"), "error": (j.get("error") or {}).get("message"),
                              "remaining": j.get("remaining"), "drill": ((j.get("drill") or {}).get("id") or "")[:8]}.items() if v is not None}


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:700], flush=True)


def save_text(tok, parts, defer=True, mode=None, title="O76"):
    body = {"action": "save", "drill": {"kind": "text", "title": f"{title} (QA)", "subject": "Historia"},
            "items": [{"kind": k, "text": t} for k, t in parts]}
    if defer:
        body["defer_audio"] = True
    return call(body, tok, mode)


def count(tok):
    return len(call({"action": "list"}, tok)[1].get("drills") or [])


# 7 först: återbetalning vid fejkat kvotfel (kräver att inget fejkat kvotfel kom de senaste 10 minuterna)
E = T.signup(True)[0]
qe0 = quota(E)
pe = [("para", text(300)), ("para", text(200))]
st, j = save_text(E, pe, defer=False, mode="unavailable", title="O76-7")
did = (j.get("drill") or {}).get("id")
v, ref = {}, 0
for _ in range(15):
    s2, v = call({"action": "status", "id": did}, E, "unavailable")
    ref += v.get("refunded_credits") or 0
    a = v.get("audio") or {}
    if a.get("total") and a.get("done", 0) + a.get("failed", 0) >= a.get("total"):
        break
    time.sleep(2)
qe1 = quota(E)
held = bool(j.get("audio_unavailable")) and not (j.get("cost") or 0) and qe1["used"] == qe0["used"]
check("7 fejkat kvotfel: krediterna tillbaka (eller hållet tillbaka utan dragning)",
      st == 200 and qe1["used"] == qe0["used"] and (held or ref == 500),
      {"spara": [st, nums(j)], "status": nums(v), "refunded_credits summa": ref, "kvot före/efter": [qe0, qe1], "hölls tillbaka direkt": held})

# 1: en text på N tecken kostar N
A = T.signup(True)[0]
q0 = quota(A)
p1 = [("heading", text(40)), ("para", text(400)), ("para", text(260))]
n1 = sum(len(t) for _, t in p1)
st, j = save_text(A, p1, title="O76-1")
d1 = (j.get("drill") or {}).get("id")
st2, js = call({"action": "start", "id": d1}, A)
q1 = quota(A)
check(f"1 text på {n1} tecken: audio.cost före start = {n1}, start drar {n1}",
      st == 200 and (j.get("audio") or {}).get("cost") == n1 and q1["used"] - q0["used"] == n1 and q1["used"] + q1["remaining"] == q1["limit"] == 1500,
      {"spara (defer_audio)": [st, nums(j)], "start": [st2, nums(js)], "kvot före": q0, "kvot efter": q1})

# 2: samma text igen (nytt prov, samma konto) och upprepade delar kostar 0
st, j2 = save_text(A, p1, title="O76-2 samma text")
st3, js2 = call({"action": "start", "id": (j2.get("drill") or {}).get("id")}, A)
q2 = quota(A)
check("2a samma text i ett nytt prov kostar 0", (j2.get("audio") or {}).get("cost") == 0 and q2["used"] == q1["used"],
      {"spara": [st, nums(j2)], "start": [st3, nums(js2)], "kvot": q2})
rep = text(150)
st, j3 = save_text(A, [("para", rep), ("para", rep), ("para", rep)], title="O76-2b upprepning")
st4, js3 = call({"action": "start", "id": (j3.get("drill") or {}).get("id")}, A)
q3 = quota(A)
check("2b samma stycke tre gånger i ett prov kostar en gång (150)", (j3.get("audio") or {}).get("cost") == 150 and q3["used"] - q2["used"] == 150,
      {"spara": [st, nums(j3)], "start": [st4, nums(js3)], "kvot": q3})

# 3: delade prov kostar 0 (import) och samma text på ett annat konto kostar 0
B = T.signup(True)[0]
qb0 = quota(B)
s_sh, sh = call({"action": "share", "id": d1}, A)
s_im, im = call({"action": "import", "code": sh.get("code")}, B)
qb1 = quota(B)
st, jb = save_text(B, p1, title="O76-3 B samma text")
s_b, jbs = call({"action": "start", "id": (jb.get("drill") or {}).get("id")}, B)
qb2 = quota(B)
check("3 import och samma text på ett annat konto kostar 0", s_im == 200 and qb1["used"] == qb0["used"] and (jb.get("audio") or {}).get("cost") == 0 and qb2["used"] == qb0["used"],
      {"import": [s_im, nums(im)], "B spara samma text": [st, nums(jb)], "B start": [s_b, nums(jbs)], "B kvot före/efter import/efter egen": [qb0, qb1, qb2]})

# 4: gränsen. Nytt konto: exakt 1500 går, sedan 1 tecken till nekas med 402 och sparar inget
C = T.signup(True)[0]
qc0 = quota(C)
st, jc = save_text(C, [("para", text(750)), ("para", text(750))], title="O76-4 1500")
s_c, jcs = call({"action": "start", "id": (jc.get("drill") or {}).get("id")}, C)
qc1 = quota(C)
n_before = count(C)
st5, jx = save_text(C, [("para", text(40))], title="O76-4 över")
qc2 = quota(C)
n_after = count(C)
check("4 exakt 1500 går; 40 till ger 402 med text och sparar inget",
      s_c == 200 and qc1["used"] == 1500 and qc1["remaining"] == 0 and st5 == 402 and (jx.get("error") or {}).get("code") == "quota_exceeded"
      and n_after == n_before and qc2["used"] == 1500,
      {"1500 spara/start": [st, nums(jc), s_c, nums(jcs)], "kvot efter 1500": qc1, "40 till": [st5, nums(jx), {k: jx.get(k) for k in ("cost", "remaining", "limit", "used", "resets")}],
       "prov före/efter": [n_before, n_after], "kvot efter 402": qc2})
st6, jy = save_text(C, [("para", text(40))], defer=False, title="O76-4 över, ljud direkt")
check("4b samma sak utan defer_audio: 402, inget sparat", st6 == 402 and count(C) == n_before, {"svar": [st6, nums(jy)], "prov": count(C)})

# 5: frågeprov: cost = fråga + långt svar (visade tecken)
D = T.signup(True)[0]
qd0 = quota(D)
its = [{"question": text(30)[:-1] + "?", "short": "Kort.", "long": "Kort. " + text(120)}, {"question": text(25)[:-1] + "?", "short": "Ja.", "long": "Ja. " + text(80)}]
expect = sum(len(i["question"]) + len(i["long"]) for i in its)
st, jq = call({"action": "save", "defer_audio": True, "drill": {"title": "O76-5 (QA)", "subject": "Biologi"}, "items": its}, D)
s_q, jqs = call({"action": "start", "id": (jq.get("drill") or {}).get("id")}, D)
qd1 = quota(D)
check(f"5 frågeprov: kostnad = fråga + långt svar = {expect}", (jq.get("audio") or {}).get("cost") == expect and qd1["used"] - qd0["used"] == expect,
      {"spara": [st, nums(jq)], "start": [s_q, nums(jqs)], "kvot": [qd0, qd1], "väntat": expect})

# 6: blanktecken slås ihop och trimmas
raw = "  " + text(60).replace(" ", "   ", 3) + "\n\n  "
clean = re.sub(r"\s+", " ", raw).strip()
st, jw = save_text(D, [("para", raw)], title="O76-6 blanktecken")
check(f"6 blanktecken: kostnad = {len(clean)} (inte {len(raw)})", (jw.get("audio") or {}).get("cost") == len(clean),
      {"spara": [st, nums(jw)], "rå längd": len(raw), "ihopslagen": len(clean)})

# 8: /exam read ger cost
st, jr = call({"_fn": "exam", "action": "read", "text": "# Rubrik\n\n" + text(300), "subject": "Historia"}, D)
chars = sum(len(p["text"]) for p in jr.get("parts") or [])
check("8 /exam read ger cost (= visade tecken)", st == 200 and jr.get("cost") is not None, {"svar": [st, {"cost": jr.get("cost"), "chars": jr.get("chars"), "delarnas tecken": chars, "counts_as": jr.get("counts_as")}]})

for tok in (A, B, C, D, E):
    for d in call({"action": "list"}, tok)[1].get("drills") or []:
        call({"action": "delete", "id": d["id"]}, tok)
print(f"\n=== O76 {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
