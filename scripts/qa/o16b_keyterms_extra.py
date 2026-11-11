#!/usr/bin/env python3
"""Oscar QA, O16 del 2b: extra Scribe keyterm probes after del 2. Does Scribe count Unicode code points or graphemes
(the app's ScribeKeyterms counts Swift graphemes)? NFD å/ä/ö, emoji with ZWJ, and a rerun of probes that closed 1006
after a transcript in del 2. Same socket/probe as o16_keyterms.py (imported), 1 s of locally synthesised speech
(espeak-ng, 0 ElevenLabs characters, D120).
  O6_LIB=<scipy+websockets> python -I scripts/qa/o16b_keyterms_extra.py --clip <file.npy>  -> reports/qa/data/<stamp>-o16b.json"""
import argparse, asyncio, datetime as dt, importlib.util, json, pathlib, sys, time, unicodedata

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o16", ROOT / "scripts/qa/o16_keyterms.py")
K = importlib.util.module_from_spec(spec)
sys.argv, argv = sys.argv[:1], sys.argv
spec.loader.exec_module(K)
sys.argv = argv
np, resample_poly = K.np, K.resample_poly

NFD = lambda s: unicodedata.normalize("NFD", s)
W18 = "kärnkraftsolyckorna"[:18]  # 18 precomposed chars, 2 with diacritics
PROBES = [
    ("NFC 20 graphemes (control)", ["kärnkraftsolyckornaö"]),
    ("NFD 20 graphemes = 23 code points", [NFD("kärnkraftsolyckornaö")]),
    ("NFD 17 graphemes = 20 code points", [NFD("kärnkraftsolyckorn")[:20]]),
    ("emoji ZWJ family 1 grapheme + 15 letters", ["abcdefghijklmno👨‍👩‍👧"]),
    ("emoji single 🧬 + 19 letters", ["abcdefghijklmnopqrs🧬"]),
    ("rerun len 20", ["abcdefghijklmnopqrst"]),
    ("rerun 2 words", ["kalla kriget"]),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clip", required=True)
    ap.add_argument("--secs", type=float, default=1.0)
    a = ap.parse_args()
    x = np.load(a.clip)
    audio = resample_poly(x, 2, 3).astype(np.float32)[: int(16000 * a.secs)]
    audio = np.concatenate([np.zeros(1600, dtype=np.float32), audio, np.zeros(4800, dtype=np.float32)])
    tok = K.O15.signup()
    rows, secs = [], 0.0
    for name, kt in PROBES:
        r = asyncio.run(K.probe(tok, audio, kt))
        rejected = any("invalid_request" in m for m in r["msgs"]) or (r["close"] and r["close"][0] == 1008)
        secs += len(audio) / 16000
        rows.append({"probe": name, "keyterms": kt, "code_points": [len(k) for k in kt], "rejected": rejected, **r})
        print(name, "REJECTED" if rejected else "accepted", r.get("close"), [m for m in r["msgs"] if "warning" not in m][:1], "|", (r["commits"] or [""])[0][:40], flush=True)
        time.sleep(10.5)
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    out = ROOT / "reports/qa/data" / f"{stamp}-o16b.json"
    out.write_text(json.dumps({"stamp": stamp, "scribe_audio_seconds": round(secs, 1), "clip": pathlib.Path(a.clip).name, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("->", out)


if __name__ == "__main__":
    main()
