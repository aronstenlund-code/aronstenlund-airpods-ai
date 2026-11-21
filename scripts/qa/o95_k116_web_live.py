"""O95 (K116/D254, Oscar moln 2026-11-21): testtrafik från webben utanför webbens tak, och testkonton i egen pott.
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o95_k116_web_live.py
Alla ljudanrop har x-earmind-test (tyst ljud, 0 ElevenLabs). Del B gör bara `quota` utan testhuvud (inget ljud, inget
Claude). Inga webbsök, inget Claude.
A. Krediter: tre testkonton från samma nät sparar och startar 1 100 tecken var (3 300 > nätets 3 000): ingen
   web_daily_cap, eftersom testtrafik inte räknas (D254 punkt 1).
B. Testpotten: fler testkonton med testhuvud tills 429 too_many_accounts (högst 5 per nät och dygn, A:s tre räknas).
C. Riktiga besökares pott är orörd: ett nytt konto utan testhuvud från samma nät släpps in (quota 200)."""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE))
import qa_testaccount as T  # noqa: E402
T.install()
import json, random, time, urllib.error, urllib.request, uuid  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
WEB = "https://earmind.vercel.app"
OK = []
RNG = random.Random(time.time())


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:2000], flush=True)


def signup(test):
    r = urllib.request.Request(T.URL + "/auth/v1/signup", data=b"{}", method="POST", headers=T.headers(None, test, {"origin": WEB}))
    with urllib.request.urlopen(r, timeout=30) as x:
        return json.load(x)["access_token"]


def call(body, tok, test=True, extra=None):
    h = T.headers(tok, test, {"origin": WEB, **(extra or {})})
    if not test:
        h.pop("x-earmind-test", None)
    r = urllib.request.Request(T.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST", headers=h)
    try:
        with urllib.request.urlopen(r, timeout=120) as x:
            return x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read() or b"{}"
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw[:200].decode(errors="replace")}


def text(n):
    w = lambda: "".join(RNG.choice("bdfghjklmnprstv") + RNG.choice("aeiouy") for _ in range(3))  # noqa: E731
    out = w().capitalize()
    while len(out) < n:
        out += " " + w()
    return out[: n - 1].rstrip() + "."


# A
rowsA = []
for i in range(3):
    tok = signup(True)
    t = text(1100)
    s, j = call({"action": "save", "start": True, "drill": {"kind": "text", "title": f"O95 {i} (QA)", "said": True, "client_id": str(uuid.uuid4())},
                 "items": [{"kind": "para", "text": t}]}, tok)
    _, q = call({"action": "quota"}, tok)
    rowsA.append({"status": s, "kod": (j.get("error") or {}).get("code"), "drogs": q.get("used"), "tecken": len(t)})
check("A: testtrafik från webben tar inte av nätets 3 000 (3 × 1 100 = 3 300, ingen web_daily_cap)",
      all(r["status"] == 200 and r["drogs"] == r["tecken"] for r in rowsA), rowsA)

# B
admitted, denied = 0, None
for n in range(8):
    tok = signup(True)
    s, j = call({"action": "quota"}, tok)
    if s == 429:
        denied = {"efter": n, "kod": (j.get("error") or {}).get("code"), "text": (j.get("error") or {}).get("message")}
        break
    admitted += 1
check("B: testkontona har en egen pott: totalt högst 5 testkonton per nät och dygn, sedan 429 too_many_accounts",
      denied is not None and denied["kod"] == "too_many_accounts" and 3 + admitted <= 5, {"A:s konton": 3, "släppta i B": admitted, "nekad": denied})

# C (no test header: quota only, no audio). qa_testaccount.install() adds the header to every urllib call, so this one
# goes through http.client; the server still treats GitHub's network as test for audio (K105), and quota makes none
import http.client  # noqa: E402


def raw_post(path, body, tok=None):
    h = T.headers(tok, False, {"origin": WEB})
    h.pop("x-earmind-test", None)
    c = http.client.HTTPSConnection(T.URL.replace("https://", ""), timeout=30)
    c.request("POST", path, body=json.dumps(body), headers=h)
    r = c.getresponse()
    data = r.read()
    try:
        return r.status, json.loads(data or b"{}")
    except ValueError:
        return r.status, {"raw": data[:200].decode(errors="replace")}


_, sj = raw_post("/auth/v1/signup", {})
tok = sj.get("access_token")
s, j = raw_post("/functions/v1/drill", {"action": "quota"}, tok)
check("C: en riktig besökares pott är orörd (nytt konto utan testhuvud från samma nät släpps in)",
      s == 200 and j.get("limit") == 1500, {"status": s, "svar": {k: j.get(k) for k in ("limit", "used", "remaining")} if s == 200 else j})

print(f"\n=== O95 {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
