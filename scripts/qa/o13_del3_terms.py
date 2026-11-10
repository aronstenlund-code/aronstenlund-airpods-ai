#!/usr/bin/env python3
"""Oscar QA, O13 del 3: are subject terms pronounced right by the deployed /tts (K18)? Independent of Kevin's
scripts/k18-pronunciation.py: 20 NEW terms (none of his 30), each in the same SHORT carrier sentence to save ElevenLabs
characters (D120). /tts once per sentence, cached in scripts/qa/audio-cache/o13d3/ (git-ignored) and reused on reruns;
Scribe batch via provlage-eval "transcribe" (scribe_v2), one short clip per term. A term is right when the transcript
contains it (letters only, case/space ignored) or an accepted spelling.
--realtime: Scribe v2 Realtime like the app (stt-token + websocket via o16_keyterms.probe, no keyterms, 16 kHz), because
provlage-eval "transcribe" rejects every body over 64 KB (~1.4 s of 24 kHz audio, O13 del 3 finding 19:41).
  python -I scripts/qa/o13_del3_terms.py [--no-scribe]                 -> reports/qa/data/<stamp>-o13d3.json
  O6_LIB=<scipy+websockets> python -I scripts/qa/o13_del3_terms.py --realtime"""
import argparse, asyncio, base64, datetime as dt, importlib.util, io, json, os, pathlib, re, sys, time, unicodedata, wave

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o15", ROOT / "scripts/qa/o15.py")
O = importlib.util.module_from_spec(spec)
spec.loader.exec_module(O)
D = O.D
CACHE = ROOT / "scripts/qa/audio-cache/o13d3"

CARRIER = "Nu tar vi {}."
CASES = [  # [id, term, accepted spellings (letters only)]
    ["bio-ribosomer", "ribosomerna", []],
    ["bio-homeostas", "homeostas", ["homöostas"]],
    ["bio-glykolys", "glykolysen", []],
    ["bio-kromosomer", "kromosomerna", []],
    ["bio-evolution", "Darwins evolutionsteori", []],
    ["kem-avogadro", "Avogadros konstant", []],
    ["kem-katalysator", "katalysatorer", []],
    ["kem-elektroneg", "elektronegativitet", []],
    ["kem-isotoper", "isotoper", []],
    ["kem-chatelier", "Le Chateliers princip", ["lechatelierprincip", "lechateliersprincip", "leshatteliersprincip"]],
    ["fys-kirchhoff", "Kirchhoffs lagar", ["kirchoffslagar"]],
    ["fys-arkimedes", "Arkimedes princip", []],
    ["mat-logaritm", "logaritmer", []],
    ["mat-cosinus", "cosinussatsen", ["kosinussatsen"]],
    ["mat-fibonacci", "Fibonaccis talföljd", ["fibonaccitalföljd"]],
    ["his-mesopotamien", "Mesopotamien", []],
    ["his-hammurabi", "Hammurabis lagar", ["hammurabislagar", "hamurabislagar"]],
    ["his-machiavelli", "Machiavelli", ["makiavelli"]],
    ["sv-lagerlof", "Selma Lagerlöf", []],
    ["sv-konjunktiv", "konjunktiv", []],
]


def letters(t):
    return re.sub(r"[^a-zåäöéü]", "", unicodedata.normalize("NFC", t.lower()))


def wav_of(pcm, rate=24000):
    b = io.BytesIO()
    with wave.open(b, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm)
    return b.getvalue()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-scribe", action="store_true")
    ap.add_argument("--realtime", action="store_true")
    a = ap.parse_args()
    if a.realtime:
        import numpy as np
        from scipy.signal import resample_poly
        sys.argv = [sys.argv[0]]
        sp = importlib.util.spec_from_file_location("o16", ROOT / "scripts/qa/o16_keyterms.py")
        K = importlib.util.module_from_spec(sp)
        sp.loader.exec_module(K)
    CACHE.mkdir(parents=True, exist_ok=True)
    tok = O.signup()
    rows, chars, secs = [], 0, 0.0
    for cid, term, alt in CASES:
        text = CARRIER.format(term)
        f = CACHE / f"{cid}.pcm"
        model = "cache"
        if not f.exists():
            o = D.call("POST", "/functions/v1/tts", {"text": text, "language": "sv", "output_format": "pcm_24000"}, tok)
            if o["status"] != 200:
                rows.append({"id": cid, "term": term, "text": text, "error": f"tts {o['status']} {o['body'][:120]!r}"})
                print("TTS", o["status"], cid, flush=True)
                continue
            f.write_bytes(o["body"])
            model = o["headers"].get("x-tts-model")
            chars += len(text)
        pcm = f.read_bytes()
        dur = len(pcm) / 2 / 24000
        row = {"id": cid, "term": term, "text": text, "tts_model": model, "audio_s": round(dur, 2)}
        if a.realtime:
            x = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768
            au = np.concatenate([np.zeros(1600, dtype=np.float32), resample_poly(x, 2, 3).astype(np.float32), np.zeros(16000, dtype=np.float32)])
            r = asyncio.run(K.probe(tok, au, []))
            heard = " ".join(c or "" for c in r["commits"]).strip()
            secs += len(au) / 16000
            if not r["started"] or r.get("exc"):
                row["error"] = f"realtime {r.get('close')} {r['msgs'][:1]} {r.get('exc', '')}"
            else:
                want = [letters(term)] + alt
                row.update(heard=heard, ok=any(w in letters(heard) for w in want), via="realtime")
            time.sleep(10.5)  # stt-token: 6 per user per minute
        elif not a.no_scribe:
            o = D.call("POST", "/functions/v1/provlage-eval", {"action": "transcribe", "audio_base64": base64.b64encode(wav_of(pcm)).decode()}, tok)
            if o["status"] != 200:
                row["error"] = f"scribe {o['status']} {o['body'][:160]!r}"
            else:
                heard = json.loads(o["body"]).get("text", "")
                secs += dur
                want = [letters(term)] + alt
                row.update(heard=heard, ok=any(w in letters(heard) for w in want))
            time.sleep(0.4)
        rows.append(row)
        print("ok " if row.get("ok") else "BAD", cid, "|", row.get("heard", row.get("error", "")), flush=True)
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    s = {"terms": len(CASES), "right": sum(bool(r.get("ok")) for r in rows), "wrong": [r["term"] for r in rows if "ok" in r and not r["ok"]],
         "errors": [r["id"] for r in rows if r.get("error")], "elevenlabs_chars_new": chars, "scribe_seconds": round(secs, 1)}
    out = ROOT / "reports/qa/data" / f"{stamp}-o13d3{'-rt' if a.realtime else ''}.json"
    out.write_text(json.dumps({"stamp": stamp, "summary": s, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(s, ensure_ascii=False), "->", out)


if __name__ == "__main__":
    main()
