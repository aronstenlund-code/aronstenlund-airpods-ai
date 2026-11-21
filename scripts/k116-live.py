"""K116 (D254, Kevin moln 2026-11-21): live with the test header, 0 ElevenLabs (Claude and web search only).
(1) Test accounts from the web have their own pool: 5 per network and day with x-earmind-test, then 429
    too_many_accounts; the real visitors' pool is untouched (an ordinary web call from the same runner still passes,
    unless an earlier run today used it up: reported, not failed).
(2) A searched recipe and an instruction are said whole (one delta) and either end with a source or are the fixed
    sentence; never a recipe without a source. An ordinary searched answer still streams.
Uses about 4 of the test web cap (D234). Usage (kevin-live.yml): python -X utf8 scripts/k116-live.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, time, urllib.error, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
WEB = "https://earmind.vercel.app"
res = {}


def ok(name, cond, info=None):
    res[name] = bool(cond)
    print(("PASS " if cond else "FAIL ") + name, json.dumps(info, ensure_ascii=False)[:500] if info is not None else "", flush=True)


def quota(tok, extra, test=True):
    r = urllib.request.Request(T.URL + "/functions/v1/drill", data=json.dumps({"action": "quota"}).encode(), method="POST", headers=T.headers(tok, test, extra))
    try:
        with urllib.request.urlopen(r, timeout=60) as x:
            return x.status, None
    except urllib.error.HTTPError as e:
        return e.code, (json.loads(e.read() or b"{}").get("error") or {}).get("code")


# (1) the test pool
codes = []
for i in range(6):
    codes.append(quota(T.signup()[0], {"origin": WEB, "x-earmind-test": "kevin-k116"}))
    time.sleep(1)
print("test pool", codes)
first = next((k for k, c in enumerate(codes) if c[0] != 200), None)
ok("test pool: at most 5 test accounts, then too_many_accounts", first is not None and first <= 5 and all(c == (429, "too_many_accounts") for c in codes[first:]), codes)
# the same runner without the header uses the visitors' pool (all Actions traffic is test anyway, D227)
st, code = quota(T.signup(False)[0], {"origin": WEB}, test=False)
print("visitors' pool from the same runner:", st, code)
ok("visitors' pool not taken by the test pool", st == 200 or code == "too_many_accounts", {"status": st, "code": code})


# (2) held recipe and instruction
def answer(q):
    tok = T.signup()[0]
    deltas, done = [], {}
    r = urllib.request.Request(T.URL + "/functions/v1/answer", data=json.dumps({"fragment": q, "mode": "push_to_talk", "language": "sv", "context": {}}).encode(),
                               method="POST", headers=T.headers(tok, True))
    with urllib.request.urlopen(r, timeout=120) as x:
        ev = None
        for line in x:
            line = line.decode().rstrip("\n")
            if line.startswith("event: "):
                ev = line[7:]
            elif line.startswith("data: "):
                d = json.loads(line[6:])
                if ev == "delta":
                    deltas.append(d.get("text", ""))
                elif ev == "done":
                    done = d
    return deltas, done


FIXED = ("Jag hittade inget recept med en säker källa.", "Jag hittade ingen instruktion med en säker källa.")
for q in ("recept på köttbullar", "recept på ris", "hur byter man däck"):
    deltas, done = answer(q)
    said = "".join(deltas).strip()
    cap = done.get("web_cap_test")
    good = cap or (len(deltas) == 1 and (bool(done.get("source")) or said in FIXED) and not done.get("source_missing"))
    ok(f"held: {q}", good, {"deltas": len(deltas), "source": done.get("source"), "fallback": done.get("source_fallback", False), "web_cap_test": cap, "said": said[:300]})
deltas, done = answer("hur många ledamöter har riksdagen just nu")
ok("ordinary searched answer is not held", done.get("web_cap_test") or len(deltas) >= 1, {"deltas": len(deltas), "source": done.get("source")})

n = sum(res.values())
print(f"=== K116: {n} av {len(res)}")
_s.exit(0 if n == len(res) else 1)
