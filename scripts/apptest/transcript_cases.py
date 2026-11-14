#!/usr/bin/env python3
"""T17c (Toby 1, D180): AppTests/E2E/Transcript/cases.json, the listening tests without ElevenLabs.

    python3 -I transcript_cases.py <out.json> <wake-run-dir>...

Each wake-run dir is the artifact of an earlier T17 run with Scribe (wake-wake.json, wake-nowake.json): what Scribe
actually heard per case is replayed as recorded transcripts through today's app and server. The other sets are
written text: the web questions (empty_answer), fynd 8 (the name in the middle of babble), A97 (Earmind and
misrecognitions) and T16 (question pairs).
"""
import json
import os
import sys

out, runs = sys.argv[1], sys.argv[2:]
sets = {}
for n, run in enumerate(runs, 1):
    cases = []
    for part in ("wake", "nowake"):
        with open(os.path.join(run, f"wake-{part}.json"), encoding="utf-8") as f:
            for c in json.load(f)["cases"]:
                cases.append({"id": c["id"], "expect": c["expect"], "cond": c["cond"], "text": c["text"], "heard": c["heard"]})
    sets[f"t17-run{n}"] = cases

web = ["hur många bor i Norge", "vem är Finlands president", "hur hög är inflationen i Sverige", "hur många länder finns i EU",
       "hur många människor finns på jorden", "hur många bor i Malmö", "vad är styrräntan i Sverige", "vem är USA:s president",
       "vad heter Sveriges statsminister", "hur många bor i Göteborg"]
sets["web"] = ([{"id": f"s{i + 1:02d}", "expect": "wake", "cond": "web", "text": "Lumen, hur många bor i Sverige?",
                 "heard": ["Lumen, hur många bor i Sverige?"]} for i in range(10)]
               + [{"id": f"f{i + 1:02d}", "expect": "wake", "cond": "web", "text": f"Lumen, {q}?", "heard": [f"Lumen, {q}?"]}
                  for i, q in enumerate(web)])

# Fynd 8: what Scribe heard in babble with the name in the middle (T17 runs 2026-11-13/14), and sentences that only
# mention the name (Angela's list and more), which must stay silent.
mid = [
    ("m01", "Du pratade länge om Lumen, vem styr handlet?"),
    ("m02", "Du vet att det är Lumen och hur länge har han ju funnits?"),
    ("m03", "Underrättade om att Lumen. Vad gör insulin?"),
    ("m04", "Det finns fortfarande trafik. Lumen, vad är gravitation?"),
    ("m05", "Vi tar bussen dit. Lumen, varför är bin viktiga?"),
    ("m06", "Det är dyrt att äta ute nu Lumen, vad är ett verb?"),
    ("m07", "Hon berättade om bilen. Lumen, hur uppstår norrsken?"),
    ("m08", "Verkstaden kan inte ta emot den. Lumen, när började första världskriget?"),
    ("m09", "Du pratade om semestern, Lumen, vad orsakar en jordbävning?"),
    ("m10", "Det finns ingen parkering Lumen. Hur många sitter i riksdagen?"),
]
silent = [
    ("q01", "Jag frågade Lumen vad det betyder."), ("q02", "Har du hört om Lumen och appen?"),
    ("q03", "Jag tyckte Lumen var bra."), ("q04", "Vi använde Lumen när vi pluggade."),
    ("q05", "Har du testat Lumen pausa?"), ("q06", "Min syster sa att Lumen kostar pengar."),
    ("q07", "Det var Lumen som hjälpte mig i går."), ("q08", "Hon pratade om Lumen hela kvällen."),
    ("q09", "Vi pratade om Lumen men det kom inget mer."), ("q10", "Jag laddade ner Lumen förra veckan."),
]
sets["fynd8"] = ([{"id": i, "expect": "wake", "cond": "sorl", "text": t, "heard": [t]} for i, t in mid]
                 + [{"id": i, "expect": "nowake", "cond": "sorl", "text": t, "heard": [t]} for i, t in silent])

# A97 (D172): Earmind and the ways Scribe writes it, Lumen's misrecognitions, and sentences that must stay silent.
earmind = [
    "Earmind, vad är fotosyntes?", "Ear mind, hur många ben har en spindel?", "Ear-mind, vem skrev Hamlet?",
    "Ir mind, vad är en atom?", "Earmund, hur bildas en regnbåge?", "Ear mund, vad betyder demokrati?",
    "Hej Earmind, hur hög är Mount Everest?", "Okej Earmind, vad betyder empati?", "Earmine, varför behöver vi syre?",
    "EarMind, vad gör mitokondrien?", "Earmind. Hur långt är ett maraton?", "Earmind, förklara evolution enkelt.",
    "Lumen, vad är gravitation?", "Lumin, vad heter hund på franska?", "Lummen, när föll Berlinmuren?",
    "Lomen, vad är ekvatorn?", "Hej Lumen, hur varm är solen?", "Lumen. Vad är huvudstaden i Japan?",
    "Earmind, hur många planeter finns i solsystemet?", "Ear mind. Vad var reformationen?",
]
quiet = [
    "I mind the gap when I travel.", "Jag har ont i örat i dag.", "Mind ear protection at the concert.",
    "Hon köpte nya hörlurar i går.", "Earth is the third planet.", "Lusen kom tillbaka efter en vecka.",
    "Limen i drinken var för sur.", "Lumpen är inte obligatorisk längre.", "Luren låg på bordet.",
    "Vi gick till lunden efter skolan.",
]
sets["a97"] = ([{"id": f"e{i + 1:02d}", "expect": "wake", "cond": "a97", "text": t, "heard": [t]} for i, t in enumerate(earmind)]
               + [{"id": f"x{i + 1:02d}", "expect": "nowake", "cond": "a97", "text": t, "heard": [t]} for i, t in enumerate(quiet)])

pairs = [("Vad är huvudstaden i Australien?", "Hur många ben har en spindel?"), ("Hur lång är Nilen?", "När föddes August Strindberg?"),
         ("Hur bildas en vulkan?", "Vad gör insulin i kroppen?"), ("Hur hög är Mount Everest?", "Vad behövs för fotosyntes?"),
         ("Hur långt är ett maraton?", "Vad är huvudstaden i Norge?"), ("Hur långt bort är månen?", "Vad betyder demokrati?"),
         ("Hur många gånger slår hjärtat per minut?", "När sjönk regalskeppet Vasa?"), ("Vad betyder ordet empati?", "Hur många bor i Kina?"),
         ("Hur bildas en regnbåge?", "Vem skrev Hamlet?"), ("Varför behöver vi syre?", "Hur många planeter finns i solsystemet?")]
sets["t16"] = [{"id": f"p{i + 1}{side}", "expect": "pair", "cond": "t16", "text": t, "heard": [t]}
               for i, pair in enumerate(pairs) for side, t in zip("ab", pair)]

with open(out, "w", encoding="utf-8", newline="\n") as f:
    json.dump({"sets": sets}, f, ensure_ascii=False, indent=1)
print({k: len(v) for k, v in sets.items()})
