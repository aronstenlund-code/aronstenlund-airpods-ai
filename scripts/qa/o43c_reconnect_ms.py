#!/usr/bin/env python3
"""Oscar QA, O43c: what does A62's immediate Scribe reconnect cost? Times, like the app does it: GET /stt-token ->
websocket open -> session_started, with a keyterm set of 20 (the quiz answer + alternatives first). No audio is sent
(0 Scribe seconds billed for audio; the socket is closed right after session_started). 10.5 s between tries
(stt-token allows 6 per user per minute).
  O6_LIB=<scipy+websockets> python -I scripts/qa/o43c_reconnect_ms.py [--n 10] -> reports/qa/data/<stamp>-o43c-reconnect.json"""
import sys as _d180s, pathlib as _d180p; _d180s.path.insert(0, str(_d180p.Path(__file__).resolve().parent)); import qa_testaccount; qa_testaccount.install()  # D180: bara testkonton, aldrig riktiga ElevenLabs
import argparse, asyncio, datetime as dt, importlib.util, json, os, pathlib, statistics, sys, time, urllib.parse

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
if os.environ.get("O6_LIB"):
    sys.path.insert(0, os.environ["O6_LIB"])
import websockets

sys.argv, _argv = sys.argv[:1], sys.argv
sp = importlib.util.spec_from_file_location("o16", ROOT / "scripts/qa/o16_keyterms.py")
K = importlib.util.module_from_spec(sp)
sp.loader.exec_module(K)
sys.argv = _argv
E, O = K.E, K.O15
KT = ["Nilen", "Kongo", "Niger", "Zambezi", "Eufrat", "Geografi", "sjöarna", "floderna", "kuststäderna", "Vättern", "Vänern",
      "Mälaren", "Ladoga", "Onega", "Bajkalsjön", "Viktoriasjön", "Tanganyikasjön", "Michigansjön", "Göta älv", "Klarälven"]


async def once(tok):
    t0 = time.perf_counter()
    t = E.http("GET", "/functions/v1/stt-token", tok=tok)
    t1 = time.perf_counter()
    q = {"model_id": t["model_id"], "token": t["token"], "language_code": "swe", "audio_format": "pcm_16000", "commit_strategy": "vad", **E.VAD}
    parts = [f"{k}={urllib.parse.quote(str(v))}" for k, v in q.items()] + [f"keyterms={urllib.parse.quote(k)}" for k in KT]
    if t.get("extra_query"):
        parts.append(t["extra_query"])
    async with websockets.connect(t["ws_url"] + "?" + "&".join(parts), max_size=None, open_timeout=20) as ws:
        t2 = time.perf_counter()
        started = None
        async for msg in ws:
            if json.loads(msg).get("message_type") == "session_started":
                started = time.perf_counter()
                break
        await ws.close()
    return {"token_ms": round((t1 - t0) * 1000), "open_ms": round((t2 - t1) * 1000), "started_ms": round(((started or t2) - t2) * 1000),
            "total_ms": round(((started or t2) - t0) * 1000), "started": started is not None}


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--n", type=int, default=10); a = ap.parse_args()
    tok, rows = O.signup(), []
    for i in range(a.n):
        try:
            r = asyncio.run(once(tok))
        except Exception as e:
            r = {"error": repr(e)[:160]}
        rows.append(r)
        print(i + 1, r, flush=True)
        time.sleep(10.5)
    tot = [r["total_ms"] for r in rows if r.get("started")]
    s = {"n": len(rows), "ok": len(tot), "median_total_ms": statistics.median(tot) if tot else None, "max_total_ms": max(tot) if tot else None,
         "median_token_ms": statistics.median([r["token_ms"] for r in rows if "token_ms" in r]) if tot else None}
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o43c-reconnect.json")
    out.write_text(json.dumps({"summary": s, "rows": rows, "note": "cloud container (EU), not a phone on 4G/wifi"}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(s), "->", out)


if __name__ == "__main__":
    main()
