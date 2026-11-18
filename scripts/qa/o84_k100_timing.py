"""O84 (Oscar moln, 2026-11-18): K100 live, tiden för save + start för en ny kort Säg-text (D225: median < 3 s, p95 < 6 s).
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o84_k100_timing.py
Samma anrop som Kevins scripts/t50-timing.py (save med defer_audio + client_id + said, sedan start; eller save med start:true),
men 20 mätningar per sätt, omväxlande ordning, nytt testkonto var 12:e text (krediterna), första anropet redovisat för sig
(kall start). Tiden mäts i klienten (GitHub Actions, USA → Frankfurt), alltså med nätet. 0 ElevenLabs (teströsten).
Sist: list med en token efter att kontot raderats (väntat 401, i dag 500)."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import json, random, time, urllib.request, uuid  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
RNG = random.Random(time.time())
N = 20


def call(fn, body, tok):
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=json.dumps(body).encode(), method="POST", headers=T.headers(tok, True))
    t0 = time.time()
    try:
        with urllib.request.urlopen(r, timeout=60) as x:
            st, j = x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read() or b"{}"
        try:
            st, j = e.code, json.loads(raw)
        except ValueError:
            st, j = e.code, {}
    return st, j, round((time.time() - t0) * 1000)


def word():
    return "".join(RNG.choice("bdfghjklmnprstv") + RNG.choice("aeiouy") for _ in range(2))


def stats(xs):
    xs = sorted(xs)
    if not xs:
        return None
    n = len(xs)
    med = xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) // 2
    return {"n": n, "median": med, "p95": xs[min(n - 1, round(0.95 * (n - 1)))], "min": xs[0], "max": xs[-1]}


tok, used, rows = None, 0, []
plan = ["two", "one"] * N
RNG.shuffle(plan)
plan = ["two"] + plan  # första anropet = kall start, redovisas för sig
for i, way in enumerate(plan):
    if tok is None or used >= 12:
        tok, used = T.signup(True)[0], 0
    text = f"Ring {word()} klockan fem och köp mjölk på vägen hem, nummer {i}."
    drill = {"kind": "text", "title": f"O84 tid {i} (QA)", "client_id": str(uuid.uuid4()), "said": True}
    items = [{"kind": "para", "text": text}]
    if way == "two":
        st, s, ms_save = call("drill", {"action": "save", "defer_audio": True, "drill": drill, "items": items}, tok)
        did = (s.get("drill") or {}).get("id")
        st2, a, ms_start = call("drill", {"action": "start", "id": did}, tok) if st == 200 else (st, {}, 0)
    else:
        st, s, ms_save = call("drill", {"action": "save", "start": True, "drill": drill, "items": items}, tok)
        did = (s.get("drill") or {}).get("id")
        st2, a, ms_start = st, s, 0
    used += 1
    rows.append({"i": i, "way": way, "save": st, "start": st2, "save_ms": ms_save, "start_ms": ms_start, "sum_ms": ms_save + ms_start,
                 "started": (a.get("drill") or {}).get("audio_started"), "cost": (s.get("audio") or {}).get("cost", s.get("cost"))})
    print(json.dumps(rows[-1], ensure_ascii=False), flush=True)
    if did:
        call("drill", {"action": "delete", "id": did}, tok)
    time.sleep(1)

warm = rows[1:]
two = [r["sum_ms"] for r in warm if r["way"] == "two"]
one = [r["sum_ms"] for r in warm if r["way"] == "one"]
out = {"kall_start_ms": rows[0]["sum_ms"], "two_calls": stats(two), "two_save": stats([r["save_ms"] for r in warm if r["way"] == "two"]),
       "two_start": stats([r["start_ms"] for r in warm if r["way"] == "two"]), "one_call": stats(one),
       "all_200": all(r["save"] == 200 and r["start"] == 200 for r in rows), "all_started": all(r["started"] for r in rows)}
goal = lambda s: s and s["median"] < 3000 and s["p95"] < 6000  # noqa: E731
out["mål_två_anrop"], out["mål_ett_anrop"] = bool(goal(out["two_calls"])), bool(goal(out["one_call"]))
print("\n=== O84 K100", json.dumps(out, ensure_ascii=False, indent=1), flush=True)

# list efter radering
D = T.signup(True)[0]
call("drill", {"action": "save", "defer_audio": True, "drill": {"kind": "text", "title": "O84 radera (QA)"}, "items": [{"kind": "para", "text": "Hej hej."}]}, D)
sd, jd, _ = call("account/delete", {"confirm": True}, D)
sl, jl, _ = call("drill", {"action": "list"}, D)
sq, jq, _ = call("drill", {"action": "quota"}, D)
print("=== list efter radering", json.dumps({"radera": [sd, jd.get("deleted")], "list": [sl, jl.get("error")], "quota": [sq, jq.get("error")],
      "väntat": "401 (inte 500)"}, ensure_ascii=False), flush=True)
sys.exit(0 if out["all_200"] else 1)
