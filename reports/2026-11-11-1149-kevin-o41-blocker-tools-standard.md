# O41 BLOCKER rättad: telefonverktygen i Standardläge (Kevin, 2026-11-11 11:49)

Fynd: Oscars O41 (`reports/qa/2026-11-11-1131-oscar-o41-k36-ringa-musik.md`), prio 1. Appen skickar Standardläge som `mode: "auto"`, och servern erbjöd aldrig verktyg i `auto`. Därför fungerade inte timer, kalender, samtal eller musik i Standardläge, bara i Provläge och med tryck och prata. **Felet var mitt** (K35 och K36): mina live-tester körde `push_to_talk`.

**Kostnad:** cirka 0,35 USD.
- Regressionen för `03fcbcd`: 0,32 USD.
- 38 live-anrop med Haiku: 0,03 USD.
- ElevenLabs: 0.

## Rättning (`answer/handler.ts`, `answer/phonetools.ts` `isAddressedAction`)
- **I `auto` tas en riktad begäran samma väg som tryck och prata** (`direct`), med telefonverktygen och Spotify. Det gäller när:
  - appen skickar `tools_available` eller `connections`, och
  - yttrandet börjar med "Lumen", är en röstinstruktion från appen, eller **inleds** med begäran ("ring mamma", "sätt en timer på …").
- Något som Auto bara råkar höra ("läraren sa att vi ska sätta en timer", "mamma ringde nyss", "vi lyssnade på spellistan i går") får inga verktyg.
- Allt som skriver eller ändrar något har bekräftelse som förut, och samtal bekräftas av iOS.
- Verktygsrundan (`tool_round`) fungerar i `auto` (test).

**Oscars övriga O41-fynd:**
- **112** och hjälpnumren i B6-listan (1177, 116 111, 90101) ringas när eleven ber om det. Förut vägrade modellen.
- "mamma ringde nyss" ger inget samtal: beskrivningen säger "bara när användaren ber dig ringa nu".
- **Meta-meningar** ("The request is to play music …", "Det är en statement …", "Det är en fråga om vem …") sägs aldrig, och verktygsvägen svarar på svenska.
- "kör lite lofi", "lyssna på …" och "sätt på lite musik" räknas som begäran.
- **Ej rättat:** siffror i ord ("ring noll sju tre …"). Nummerkontrollen (B6) jämför bara siffror. Scribe skriver oftast siffror.

## Tester
- `deno task test`: **449 gröna** (ny `answer/k41_test.ts`, och `k36_test` uppdaterad: Spotify i `auto` vid riktad begäran).
- **Live, driftsatt (`7d0378b`):**
  - Standardläge (`auto`, "Lumen, …"): **16/16** (samtal, nummer, 112, musik, timer; "mamma ringde nyss" och vanliga frågor utan verktyg; 0 talat före verktyget).
  - Tryck och prata: **16/16**.
  - K35-verktygen i `auto`: **6/6** (kalender in och ut, påminnelse, larm, anteckning; "lägg in matteprovet på fredag" utan "Lumen").
  - Rådata: `reports/eval/2026-11-11-1145-k36-tools-live-auto.json` och senare körningar.
- **Ej verifierat:** i appen och på telefon. Antagandet att appen skickar `auto` och `tools_available` i Standardläge bygger på Oscars läsning av koden.

## Till Oscar
Kör om `scripts/qa/o41_k36_live.py` och de sex raderna.

## Till Aron
I kväll fungerar timer och kalender i Standardläge också, när appen har den här servern (den är driftsatt). Säg "Lumen, sätt en timer på fem minuter". Ingen ny app behövs för serverdelen.
