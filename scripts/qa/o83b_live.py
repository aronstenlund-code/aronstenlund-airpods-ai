"""O83 del 3 (K101 radera kontot) + O80 F1 omtest (taggar med riktig svensk text), Oscar (moln) 2026-11-18.
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o83b_live.py
Bara testkonton (x-earmind-test, teströsten), 0 ElevenLabs. Claude: Haikus taggning (2 korta texter).
K101: konto X har en egen text (eget ljud) och en text som konto Y också har (delat ljud). X raderas. Sedan:
Y:s ljud finns kvar; ett nytt konto Z ser att X:s egna text kostar igen (ljudet raderat) och den delade 0 (kvar);
X:s token, prov och inbjudningskod fungerar inte längre."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import json, random, time, urllib.request  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
OK = []
RNG = random.Random(time.time())


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:1500], flush=True)


def req(method, fn, body=None, tok=None):
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=json.dumps(body).encode() if body is not None else None, method=method, headers=T.headers(tok, True))
    try:
        with urllib.request.urlopen(r, timeout=240) as x:
            return x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read() or b"{}"
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw[:200].decode(errors="replace")}


def err(j):
    e = j.get("error") or {}
    return {k: v for k, v in {"code": e.get("code"), "message": e.get("message")}.items() if v}


def word():
    return "".join(RNG.choice("bdfghjklmnprstv") + RNG.choice("aeiouy") for _ in range(3))


def sentence(n):
    out = word().capitalize()
    while len(out) < n:
        out += " " + word()
    return out[: n - 1].rstrip() + "."


def text_body(action, t, title, style=None):
    d = {"kind": "text", "title": f"{title} (QA)", "subject": "Historia"}
    if style:
        d["style"] = style
    b = {"action": action, "drill": d, "items": [{"kind": "para", "text": t}]}
    if action == "save":
        b["defer_audio"] = True
    return b


def save_start(tok, t, title, style=None):
    s, j = req("POST", "drill", text_body("save", t, title, style), tok)
    did = (j.get("drill") or {}).get("id")
    req("POST", "drill", {"action": "start", "id": did}, tok)
    a = {}
    for _ in range(30):
        a = req("POST", "drill", {"action": "status", "id": did}, tok)[1].get("audio") or {}
        if a.get("total") and a.get("done", 0) + a.get("failed", 0) >= a["total"]:
            break
        time.sleep(2)
    return did, (j.get("audio") or {}).get("cost"), {k: a.get(k) for k in ("total", "done", "failed")}


# ---------------- K101 ----------------
X, Y, Z = T.signup(True)[0], T.signup(True)[0], T.signup(True)[0]
own, shared = sentence(140), sentence(120)
dx_own, c_own, a_own = save_start(X, own, "K101 X eget")
dx_sh, c_sh, a_sh = save_start(X, shared, "K101 X delat")
dy, c_y, a_y = save_start(Y, shared, "K101 Y delat")
code = req("POST", "purchase", {"action": "invite_code"}, X)[1].get("code")
s0, j0 = req("POST", "account/delete", {}, X)
s1, j1 = req("POST", "account/delete", {"confirm": True}, X)
s2, j2 = req("POST", "drill", {"action": "get", "id": dx_own}, X)
s3, j3 = req("POST", "drill", {"action": "get", "id": dx_own}, Y)
s4, j4 = req("POST", "drill", {"action": "get", "id": dy}, Y)
ya = j4.get("audio") or {}
s5, c5 = req("POST", "drill", text_body("cost", own, "Z eget"), Z)
s6, c6 = req("POST", "drill", text_body("cost", shared, "Z delat"), Z)
s7, j7 = req("POST", "purchase", {"action": "invite_claim", "code": code}, Z)
s8, j8 = req("POST", "account/delete", {"confirm": True}, X)
s9, j9 = req("POST", "drill", {"action": "list"}, X)
check("O83 del 3 (K101): radera kontot tar bort kontots eget och lämnar delat ljud",
      s0 == 400 and s1 == 200 and j1.get("deleted") is True and s2 in (401, 404) and s3 == 404 and s4 == 200 and ya.get("done") == ya.get("total")
      and c5.get("cost") == len(own) and c6.get("cost") == 0 and s7 == 404 and s8 == 200,
      {"före": {"X eget": [c_own, a_own], "X delat": [c_sh, a_sh], "Y delat": [c_y, a_y], "X:s kod": code},
       "utan confirm": [s0, err(j0)], "radera": [s1, {k: j1.get(k) for k in ("deleted", "removed", "subscription", "notice")}],
       "X get eget prov": [s2, err(j2)], "Y get X:s prov": [s3, err(j3)], "Y:s prov med delat ljud": [s4, {k: ya.get(k) for k in ("total", "done", "chars")}],
       "Z cost X:s egna text": [s5, c5.get("cost"), "väntat", len(own)], "Z cost delade texten": [s6, c6.get("cost")],
       "Z tar X:s kod": [s7, err(j7)], "radera igen": [s8, j8.get("deleted")], "X list efteråt": [s9, err(j9)]})

# ---------------- O80 F1 omtest: taggar med riktig svensk text ----------------
A = T.signup(True)[0]
real = ("Gustav Vasa valdes till kung i Strängnäs år 1523. Han ville göra Sverige till ett starkt land, och därför tog han kyrkans "
        "jord och pengar. Bönderna i Dalarna hade hjälpt honom i kriget mot danskarna, men senare gjorde många av dem uppror mot honom.")
real2 = ("Fotosyntesen sker i växternas blad. Där fångar klorofyllet ljuset, och växten bygger socker av koldioxid och vatten. "
         "Syre släpps ut som en restprodukt, och det är det syret som djur och människor andas.")
out = {}
for t in (real, real2):
    d1, c1, a1 = save_start(A, t, "O80 stil", "Lugnt och tydligt, med pauser så att man hinner skriva")
    d2, c2, a2 = save_start(A, t, "O80 utan stil")
    g1 = req("POST", "drill", {"action": "get", "id": d1}, A)[1]
    g2 = req("POST", "drill", {"action": "get", "id": d2}, A)[1]
    out[t[:24]] = {"med stil": [(g1.get("drill") or {}).get("voice_model"), (g1.get("audio") or {}).get("chars"), a1],
                   "utan stil": [(g2.get("drill") or {}).get("voice_model"), (g2.get("audio") or {}).get("chars"), a2], "visade tecken": len(t)}
tagged = [v for v in out.values() if (v["med stil"][1] or 0) > (v["utan stil"][1] or 0)]
check("O80 F1 omtest: med riktig svensk text lägger Haiku in taggar (rösttexten med stil är längre än utan)", len(tagged) >= 1, out)

for tok in (A, Y, Z):
    for d in req("POST", "drill", {"action": "list"}, tok)[1].get("drills") or []:
        req("POST", "drill", {"action": "delete", "id": d["id"]}, tok)
print(f"\n=== O83b live {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
