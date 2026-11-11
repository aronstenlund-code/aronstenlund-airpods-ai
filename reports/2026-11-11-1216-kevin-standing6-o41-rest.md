# Stående uppgift, omgång 6: resten av Oscars O41 (samtal och tal i verktygsvägen) (Kevin, 2026-11-11 12:16)

Fynd: Oscars O41 (`reports/qa/2026-11-11-1131-oscar-o41-k36-ringa-musik.md`), det som var kvar efter blockern (K40).

**Kostnad:** cirka 0,03 USD (cirka 40 Haiku-anrop live). ElevenLabs: 0.

## Gjort (`answer/phonetools.ts`, `answer/speech.ts`)
| Fynd | Före | Nu |
|---|---|---|
| "ring noll sju tre, fyra fem sex, sjuttioåtta nittio" (siffror i ord) | inget verktyg, tyst | `call_contact {number: "0734567890"}`. Nummerkontrollen (B6) läser talade siffror, och "en"/"ett" räknas som 1 bara bredvid ett annat tal ("ring en kompis" ger inga siffror) |
| Modellen skrev numret som "+46 70 …" | ströks (`tool_call_dropped`) | +46 räknas som den inledande nolla som sades |
| "vad har mamma för nummer" och "vad är numret till pappa" | samtal startades | inget samtal, både i koden och i beskrivningen: "Jag kan inte läsa dina kontakter, men jag kan ringa pappa åt dig." "ring pappa, vad är numret …" ringer |
| Engelskt resonemang ("The user asks to call a friend … I need a name …") | lästes upp | stryks när telefonverktyg erbjuds och språket är svenska (`EnglishGate`, med fler engelska ord) |
| "Det här är en musikförfrågan, så jag öppnar …", "Det är en fråga om vem …" | lästes upp | stryks (`LEAD_META`) |

## Live (driftsatt `e807f72` och tidigare)
- Standardläge (`auto`, "Lumen, …") med 16 fall: **16/16**, 0 talat före verktyget, efter alla ändringar.
- Talade nummer:
  - "Lumen, ring noll sju noll, ett två tre, fyrtiofem sextiosju" (auto) ger 0701234567.
  - "ring noll åtta, ett två tre fyra fem sex sju" ger 081234567.
- "kör lofi" ger `music_open` utan meta-mening.
- "vad är numret till pappa" ger inget samtal, och "ring pappa" ger ett samtal.
- "ring en kompis" (inget namn): Lumen frågar nu "Vem vill du att jag ska ringa?". När en begäran till telefonen slutar utan verktyg och utan något sagt, ger koden en kort fråga på svenska (`e807f72` och senare).

## Tester
`deno task test`: **455 gröna** (`answer/k41_test.ts` har nu 10 tester). `deno task check` är ren.
