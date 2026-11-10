#!/usr/bin/env python3
"""Oscar QA, O16: which keyterms make Scribe v2 Realtime close the socket (1008 invalid_request)?
Each probe opens a socket like the app (stt-token, Provläge VAD values) with ONE variable keyterm set, sends ~1.5 s
of speech (a cached /tts clip from O12, scratch only; D120: 1.0 s by default, --secs) and records: session started, error messages, close code.
  O6_LIB=<scipy+websockets> python -I scripts/qa/o16_keyterms.py --clip <file.npy> [--probe]   -> reports/qa/data/<stamp>-o16.json
--probe runs only the baseline (no keyterms) to see if Scribe works at all. Uses Scribe seconds only, no /answer."""
import argparse, asyncio, base64, datetime as dt, importlib.util, json, os, pathlib, sys, time, urllib.parse

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
if os.environ.get("O6_LIB"):
    sys.path.insert(0, os.environ["O6_LIB"])
import numpy as np
import websockets
from scipy.signal import resample_poly

spec = importlib.util.spec_from_file_location("ae", ROOT / "scripts/audio-eval.py")
E = importlib.util.module_from_spec(spec)
spec.loader.exec_module(E)
spec = importlib.util.spec_from_file_location("o15", ROOT / "scripts/qa/o15.py")
O15 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(O15)

L20 = "abcdefghijklmnopqrst"  # 20 characters
PROBES = [  # (name, keyterms)
    ("none", []),
    ("one short", ["fotosyntes"]),
    ("len 20", [L20]),
    ("len 21", [L20 + "u"]),
    ("len 20 with å/ä/ö", ["kärnkraftsolyckornaö"]),
    ("len 21 with å/ä/ö (bytes > chars)", ["kärnkraftsolyckornaöö"]),
    ("2 words", ["kalla kriget"]),
    ("3 words", ["x i kvadrat"]),
    ("4 words 20 chars", ["Gustav II Adolf dog."[:19] + "x"]),
    ("4 words short", ["a b c d"]),
    ("5 words short", ["a b c d e"]),
    ("6 words short", ["a b c d e f"]),
    ("digits", ["1789"]),
    ("digit + word", ["Ma 3c"]),
    ("hyphen", ["syra-bas"]),
    ("slash", ["km/h"]),
    ("ampersand", ["Q&A"]),
    ("parentheses", ["DNA (arvsmassa)"]),
    ("colon", ["kap: 3"]),
    ("apostrophe", ["Newton's lag"]),
    ("comma", ["mitos, meios"]),
    ("period", ["t.ex."]),
    ("percent", ["20 %"]),
    ("plus/equals", ["E=mc2"]),
    ("question mark", ["vad?"]),
    ("emoji", ["cell 🧬"]),
    ("leading space", [" mitos"]),
    ("empty string", [""]),
    ("duplicate", ["mitos", "mitos"]),
    ("uppercase", ["FRANSKA REVOLUTIONEN"]),
    ("20 terms", [f"term{i}" for i in range(20)]),
    ("50 terms", [f"term{i}" for i in range(50)]),
    ("100 terms", [f"term{i}" for i in range(100)]),
    ("101 terms", [f"term{i}" for i in range(101)]),
    ("Deangelo history-like", ["Westfaliska freden", "trettioåriga kriget", "Gustav II Adolf", "Versaillesfreden", "Kalla kriget"]),
    ("Deangelo samhälle-like", ["riksdagen", "regeringen", "grundlagarna", "tryckfrihetsförordningen", "BNP"]),
]


async def probe(tok, audio, keyterms):
    t = E.http("GET", "/functions/v1/stt-token", tok=tok)
    q = {"model_id": t["model_id"], "token": t["token"], "language_code": "swe", "audio_format": "pcm_16000", "commit_strategy": "vad", **E.VAD}
    parts = [f"{k}={urllib.parse.quote(str(v))}" for k, v in q.items()] + [f"keyterms={urllib.parse.quote(k)}" for k in keyterms]
    if t.get("extra_query"):
        parts.append(t["extra_query"])
    url = t["ws_url"] + "?" + "&".join(parts)
    res = {"started": False, "msgs": [], "close": None, "commits": [], "url_len": len(url)}
    try:
        async with websockets.connect(url, max_size=None, open_timeout=20) as ws:
            async def reader():
                try:
                    async for msg in ws:
                        m = json.loads(msg)
                        k = m.get("message_type") or m.get("type") or ""
                        if k == "session_started":
                            res["started"] = True
                        elif k.startswith("committed_transcript"):
                            res["commits"].append(m.get("text"))
                        elif k != "partial_transcript":
                            res["msgs"].append(str(m)[:240])
                except websockets.ConnectionClosed as ce:
                    res["close"] = [ce.code, (ce.reason or "")[:200]]
            rd = asyncio.create_task(reader())
            chunk = E.SR // 10
            try:
                for i in range(0, len(audio), chunk):
                    await ws.send(json.dumps({"message_type": "input_audio_chunk", "audio_base_64": base64.b64encode(E.to_pcm16(audio[i:i + chunk])).decode(),
                                              "commit": i + chunk >= len(audio), "sample_rate": E.SR}))
                    await asyncio.sleep(0.1)
            except websockets.ConnectionClosed as ce:
                res["close"] = res["close"] or [ce.code, (ce.reason or "")[:200]]
            await asyncio.sleep(1.5)
            try:
                await ws.close()
            except Exception:
                pass
            await rd
    except Exception as e:
        res["exc"] = repr(e)[:240]
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clip", required=True)
    ap.add_argument("--probe", action="store_true")
    ap.add_argument("--secs", type=float, default=1.0)
    a = ap.parse_args()
    x = np.load(a.clip)
    audio = resample_poly(x, 2, 3).astype(np.float32)[: int(16000 * a.secs)]  # 24 -> 16 kHz, first --secs s
    audio = np.concatenate([np.zeros(1600, dtype=np.float32), audio, np.zeros(4800, dtype=np.float32)])
    tok = O15.signup()
    rows, secs = [], 0.0
    for name, kt in (PROBES[:1] if a.probe else PROBES):
        r = asyncio.run(probe(tok, audio, kt))
        ok = r["started"] and not (r["close"] and r["close"][0] not in (1000, 1005)) and not any("error" in m for m in r["msgs"])
        secs += len(audio) / 16000
        rows.append({"probe": name, "keyterms": kt, "ok": ok, **r})
        print(name, "OK" if ok else "FAIL", r.get("close"), r["msgs"][:2], r.get("exc", ""), "|", (r["commits"] or [""])[0][:60], flush=True)
        time.sleep(10.5)  # stt-token allows 6 per user per minute
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    out = ROOT / "reports/qa/data" / f"{stamp}-o16{'-probe' if a.probe else ''}.json"
    out.write_text(json.dumps({"stamp": stamp, "scribe_audio_seconds": round(secs, 1), "clip": pathlib.Path(a.clip).name, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("->", out)


if __name__ == "__main__":
    main()
