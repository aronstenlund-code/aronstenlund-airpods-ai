# Deangelo live eval — 20 conversations / 26 turns (2026-11-05 22:45)

Script: `scripts/live-eval.py` (runs against the deployed backend, text mode, anonymous user). TTFT 0.6–1.8 s except two outliers (fotosyntes 4.0 s, web-search VM question 3.6 s).

## Wrong facts
- Tokyo time when 12:00 in Sweden: answered +9 h (winter) / +8 h (summer). Correct: +8 h / +7 h. → compute time zones in code.
- "fotosyntes" → "i natten då": claimed "många växter" store CO2 at night (only CAM plants). → avoid overgeneralising subgroups.
- Web search answer cited an obscure site (masterskapssidan.se). Content not verified here. → prefer authoritative sources.

## Speech problems
- Symbols read literally: "tio^tjugotre", "kilometer/s", "e=mc2", "C12H22O11", "NaCl".
- Ordinal broken: "hundrasex:e minuten". "f.Kr." not expanded.
- Grammar slips: "kan du smält", "snurra panna", "Ett mol kol".
- Lowercase first letter on computed answers.

## Filler
- "jag har tappat nycklarna": opens with "Det här är något jag inte kan hjälpa till med direkt" before helping.

## Good
Percent + follow-up, "kortare", Pythagoras + "exempel", slang, translation, riksdag, virus/bakterie, Gustav Vasa, social reply.
