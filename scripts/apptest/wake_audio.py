#!/usr/bin/env python3
"""T17 (Toby): put a clean `say` file into one of the three rooms of AppTests/E2E/Audio/wake.tsv.

    python3 -I wake_audio.py <cond> <clean.wav> <out.wav> [babble1.wav babble2.wav ...]

cond:
  tyst      the clean file, unchanged.
  en-meter  about 1 m from the mic: -14 dB, a short early reflection (12 ms, -9 dB) and a reverb tail (decaying
            echoes up to 0.3 s), plus a quiet room floor (-60 dBFS noise).
  sorl      the clean speech with 2-3 other voices talking over it at about 5 dB SNR (cafe babble), the babble
            starting 1 s before and ending 1 s after the speech.

All files are 16 kHz mono 16-bit (what `say --data-format=LEI16@16000` writes). Standard library only.
Synthetic rooms, not real recordings: the result is a proxy for the conditions, never a verification on a device.
"""
import array
import math
import random
import sys
import wave

RATE = 16000


def read(path):
    with wave.open(path, "rb") as w:
        if w.getnchannels() != 1 or w.getsampwidth() != 2 or w.getframerate() != RATE:
            raise SystemExit(f"{path}: need 16 kHz mono 16-bit")
        data = array.array("h", w.readframes(w.getnframes()))
    return [s / 32768.0 for s in data]


def write(path, samples):
    peak = max((abs(s) for s in samples), default=0.0)
    scale = 0.95 / peak if peak > 0.95 else 1.0
    out = array.array("h", (int(max(-1.0, min(1.0, s * scale)) * 32767) for s in samples))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(out.tobytes())


def rms(samples):
    voiced = [s for s in samples if abs(s) > 1e-4] or [0.0]
    return math.sqrt(sum(s * s for s in voiced) / len(voiced))


def db(x):
    return 10 ** (x / 20.0)


def one_meter(clean, rng):
    gain = db(-14)
    taps = [(0, 1.0), (int(0.012 * RATE), db(-9))]
    # Reverb tail: sparse echoes every ~23 ms, decaying 60 dB over 0.3 s.
    t = 0.035
    while t < 0.3:
        taps.append((int(t * RATE), db(-12 - 60 * t / 0.3) * rng.uniform(0.6, 1.0)))
        t += rng.uniform(0.018, 0.028)
    length = len(clean) + taps[-1][0] + 1
    out = [0.0] * length
    for delay, g in taps:
        for i, s in enumerate(clean):
            out[i + delay] += s * g
    floor = db(-60)
    return [s * gain + rng.gauss(0, floor) for s in out]


def babble(clean, others, rng):
    pad = RATE  # 1 s before and after
    length = len(clean) + 2 * pad
    mix = [0.0] * length
    for voice in others:
        start = rng.randint(0, max(0, length - len(voice))) if len(voice) < length else 0
        seg = voice[: length - start]
        for i, s in enumerate(seg):
            mix[start + i] += s
        # Loop the voice to cover the whole length.
        pos = start + len(seg)
        while pos < length:
            seg = voice[: length - pos]
            for i, s in enumerate(seg):
                mix[pos + i] += s
            pos += len(seg)
    speech_rms, babble_rms = rms(clean), rms(mix)
    if babble_rms > 0:
        target = speech_rms / db(5)  # 5 dB SNR
        mix = [s * target / babble_rms for s in mix]
    for i, s in enumerate(clean):
        mix[pad + i] += s
    return mix


def main(argv):
    if len(argv) < 4:
        raise SystemExit(__doc__)
    cond, src, dst, extra = argv[1], argv[2], argv[3], argv[4:]
    rng = random.Random(src)  # same file, same room: runs are comparable
    clean = read(src)
    if cond == "tyst":
        out = clean
    elif cond == "en-meter":
        out = one_meter(clean, rng)
    elif cond == "sorl":
        if len(extra) < 2:
            raise SystemExit("sorl needs at least two babble files")
        out = babble(clean, [read(p) for p in extra], rng)
    else:
        raise SystemExit(f"unknown cond {cond}")
    write(dst, out)


if __name__ == "__main__":
    main(sys.argv)
