# Ke81: söktonen (Kelly (moln), 2026-11-18, D233, A151)

## Vad som gjordes
- `docs/design/_src/soktonen.py` gör tre toner i kod (Pythons standardbibliotek, **0 ElevenLabs**) till
  `docs/design/ljud/soktonen-{a,b,c}.wav`. Vald: **A "Andetag"**, kopierad till **`docs/design/ljud/soktonen.wav`**
  (sökvägen står under A151 i `prompts/queue/angela.md`).
- Varianterna och motiveringen: `docs/design/sag-i-airpods.md` › Söktonen.

## Tonen (A)
G4 392 Hz + svag överton 784 Hz, 0,36 s, tonar in 90 ms och ut 200 ms, topp −26 dBFS (medel −32 dB), 44,1 kHz mono,
32 kB. Ingen stigande eller sjunkande tonhöjd (inte notis, inte fel). All energi under 1 kHz, under konsonanterna i tal.

## Test
- Längd, toppnivå och medelnivå mätta med ffmpeg `volumedetect`; första och sista sampel är 0 (inga klick).
  **Verifierat i filen.**
- Spektrum kontrollerat (ffmpeg `showspectrumpic`): bara 392 och 784 Hz. **Verifierat i filen.**
- **Inte hört i AirPods, inte provat mot ett samtal: untested assumption** att nivån är rätt. Aron lyssnar på telefon
  när A151 är byggd; ändra `PEAK_DBFS` i skriptet om den är för stark eller för svag.

## Nästa
Angela Schrute tar in filen i A151 (efter K104 `searching`).
