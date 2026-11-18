"""Kelly Ke81 (D233, A151): söktonen, den korta tonen i AirPods när ett sökt svar dröjer mer än 1,5 s.

Syntes i kod, ingen ElevenLabs. Bara Pythons standardbibliotek, så att filerna går att göra om var som helst:
  python3 -I docs/design/_src/soktonen.py
Skriver docs/design/ljud/soktonen-{a,b,c}.wav (44,1 kHz, 16 bit, mono).

Gemensamt för alla tre (kraven i D233):
- högst 0,4 s, mjuk attack (ingen klick), mjuk avklingning;
- låg nivå: topp −26 dBFS (spelas på full spelarvolym; användarens volym styr resten);
- ingen tonhöjd som stiger (låter som en notis) eller sjunker (låter som ett fel);
- grundtonen under det band där tal hörs tydligast (konsonanterna 2–4 kHz), så att den inte skymmer någon som pratar.
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / "ljud"
PEAK_DBFS = -26.0


def envelope(t, dur, attack, release):
    """Mjuk upp (halv cosinus) och mjuk ner, aldrig hårda kanter."""
    if t < attack:
        return 0.5 - 0.5 * math.cos(math.pi * t / attack)
    if t > dur - release:
        x = (dur - t) / release
        return 0.5 - 0.5 * math.cos(math.pi * max(0.0, x))
    return 1.0


def render(fn, dur):
    n = int(RATE * dur)
    s = [fn(i / RATE) for i in range(n)]
    peak = max(abs(v) for v in s) or 1.0
    gain = 10 ** (PEAK_DBFS / 20) / peak
    return [v * gain for v in s]


def tone_a(t):
    """A, "Andetag": en låg ton, G4 392 Hz, med lite andra överton för värme. 0,36 s."""
    dur = 0.36
    e = envelope(t, dur, 0.09, 0.20)
    return e * (math.sin(2 * math.pi * 392 * t) + 0.12 * math.sin(2 * math.pi * 784 * t))


def tone_b(t):
    """B, "Puls": två mjuka slag på samma ton, E4 330 Hz, 0,13 s + 0,06 s paus + 0,13 s = 0,32 s."""
    for start in (0.0, 0.19):
        if start <= t < start + 0.13:
            u = t - start
            return envelope(u, 0.13, 0.03, 0.08) * math.sin(2 * math.pi * 330 * u)
    return 0.0


def tone_c(t):
    """C, "Trä": ett kort, dovt slag (C5 523 Hz + svag oharmonisk delton), snabb avklingning. 0,30 s."""
    dur = 0.30
    e = envelope(t, dur, 0.006, 0.05) * math.exp(-t / 0.07)
    return e * (math.sin(2 * math.pi * 523 * t) + 0.25 * math.sin(2 * math.pi * 523 * 2.76 * t) * math.exp(-t / 0.02))


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    p = OUT / name
    with wave.open(str(p), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(round(v * 32767))) for v in samples))
    peak = max(abs(v) for v in samples)
    print(f"{p.name}: {len(samples) / RATE:.2f} s, topp {20 * math.log10(peak):.1f} dBFS, {p.stat().st_size} byte")


if __name__ == "__main__":
    write("soktonen-a.wav", render(tone_a, 0.36))
    write("soktonen-b.wav", render(tone_b, 0.32))
    write("soktonen-c.wav", render(tone_c, 0.30))
