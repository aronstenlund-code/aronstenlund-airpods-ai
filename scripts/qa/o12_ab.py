#!/usr/bin/env python3
"""Oscar QA, O12 point 4: three short A/B pairs (the same sentence) through the live /tts, written as WAV files for
Aron to listen to. Runs in GitHub Actions (.github/workflows/oscar-ab-audio.yml) and is uploaded as an artifact,
never committed (the repo is public). Standard library only. About 800 weighted ElevenLabs characters.
  python3 scripts/qa/o12_ab.py --out ab-audio"""
import sys as _d180s, pathlib as _d180p; _d180s.path.insert(0, str(_d180p.Path(__file__).resolve().parent)); import qa_testaccount; qa_testaccount.install()  # D180: bara testkonton, aldrig riktiga ElevenLabs
import argparse, json, os, time, urllib.request, wave

URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
ADAM, SAGA = "x0u3EW21dbrORJzOq1m9", "tPrL2xYfkQnwJhHMMdRM"
S1 = "Franska revolutionen började sjuttonhundraåttionio, och samma år stormade folket Bastiljen i Paris."
S2 = "Tänkare som Voltaire, Montesquieu och Rousseau kritiserade envälde och religiös intolerans."
S3 = "Derivatan av tre x i kvadrat plus två x minus fem är sex x plus två."
PAIRS = [  # (pair, label, text, model, voice)
    ("1", "A_v4-turbo_Adam", S1, "eleven_v4_turbo", ADAM), ("1", "B_flash-v2.5_Adam", S1, "eleven_flash_v2_5", ADAM),
    ("2", "A_v4-turbo_Adam", S2, "eleven_v4_turbo", ADAM), ("2", "B_multilingual-v2_Adam", S2, "eleven_multilingual_v2", ADAM),
    ("3", "A_v4-turbo_Adam", S3, "eleven_v4_turbo", ADAM), ("3", "B_v4-turbo_Saga", S3, "eleven_v4_turbo", SAGA),
]


def post(path, body, tok=None):
    h = {"apikey": KEY, "content-type": "application/json"}
    if tok:
        h["Authorization"] = "Bearer " + tok
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode(), headers=h, method="POST")
    with urllib.request.urlopen(req, timeout=90) as r:
        return r.read(), {k.lower(): v for k, v in r.headers.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="ab-audio")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    tok = json.loads(post("/auth/v1/signup", {})[0])["access_token"]
    lines = ["# O12 A/B-par (samma mening, lyssna A och B i följd)", ""]
    for pair, label, text, model, voice in PAIRS:
        pcm, h = post("/functions/v1/tts", {"text": text, "language": "sv", "output_format": "pcm_24000", "model": model, "voice_id": voice}, tok)
        name = f"par{pair}_{label}.wav"
        with wave.open(os.path.join(a.out, name), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(24000)
            w.writeframes(pcm[: len(pcm) // 2 * 2])
        lines.append(f"- {name}: modell {h.get('x-tts-model', model)}, text: \"{text}\"")
        print(name, len(pcm), h.get("x-tts-model"), flush=True)
        time.sleep(1)
    open(os.path.join(a.out, "LÄS-MIG.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
