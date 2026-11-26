"""K123 (Kevin moln 2026-11-26), live, no model call, 0 ElevenLabs: how fast an answer the server gives itself
arrives (a calculation, "vad är 23 gånger 19"), 8 times on one account: the client's time to the first byte and to
the end, and the server's own total_ms. Run before and after the deploy to compare.
Usage (kevin-live.yml): python -X utf8 scripts/k123-live.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, statistics, time, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
tok = T.signup()[0]
rows = []
for i in range(8):
    body = json.dumps({"fragment": f"vad är {23 + i} gånger 19", "mode": "push_to_talk", "language": "sv", "context": {}}).encode()
    r = urllib.request.Request(T.URL + "/functions/v1/answer", data=body, method="POST", headers=T.headers(tok, True))
    t0 = time.time()
    first, done, said = None, {}, ""
    with urllib.request.urlopen(r, timeout=60) as x:
        ev = None
        for line in x:
            if first is None:
                first = (time.time() - t0) * 1000
            line = line.decode().rstrip("\n")
            if line.startswith("event: "):
                ev = line[7:]
            elif line.startswith("data: "):
                d = json.loads(line[6:])
                if ev == "delta":
                    said += d.get("text", "")
                elif ev == "done":
                    done = d
    end = (time.time() - t0) * 1000
    rows.append({"first_byte_ms": round(first), "end_ms": round(end), "server_total_ms": (done.get("timing") or {}).get("total_ms"), "breakdown": {k: v for k, v in (done.get("breakdown") or {}).items() if k.endswith("_ms")}, "model": (done.get("usage") or {}).get("model"), "said": said[:60]})
    print(json.dumps(rows[-1], ensure_ascii=False), flush=True)
fb = [r["first_byte_ms"] for r in rows[1:]]
st = [r["server_total_ms"] for r in rows[1:] if isinstance(r["server_total_ms"], (int, float))]
print(f"=== K123 (warm, 7 calls): first byte p50 {statistics.median(fb):.0f} ms, server total_ms p50 {statistics.median(st) if st else 'n/a'}")
ok = all(r["model"] in ("calc", None) for r in rows)
print(("PASS" if ok else "FAIL") + " no model call (answered in code)")
_s.exit(0 if ok else 1)
