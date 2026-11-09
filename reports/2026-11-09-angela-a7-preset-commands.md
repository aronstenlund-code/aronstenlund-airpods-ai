# A7 – Förinställda kommandon med naturliga formuleringar (Angela, 2026-11-09)

Kort: alla kommandon på ägarens lista finns i en tabell, `CommandRegistry`, med 2–8 formuleringar var.
- **Nivå 1** körs i telefonen utan API-anrop.
- **Nivå 2** går till /answer som instruktion, för Kevins K9.
- `docs/COMMANDS.md` är den enda listan.
- Grönt i CI (körning 42654364887). **Inget verifierat på enhet.**

## Inventering först (inget dubbelt)
| Fanns | Var | Vad A7 gjorde |
|---|---|---|
| "Lumen, …" och lägesbyte | `VoiceChannel` (D74) | Läser nu tabellen, och "lyssna efter frågor" byter till Frågor. |
| pausa / avsluta / spela musik | D58/D74, A6 | I tabellen. |
| kom ihåg / glöm / regel | D49/D80 | "glöm inte (att) …" = kom ihåg. Det tolkades förut som "glöm". |
| klagomål ("det där var fel") | D80 | I tabellen. |
| utveckla / förklara enklare | backend (`continue_more`/`continue_simpler`) | Skickas med de orden. |
| Egna nyckelordskommandon | D37 `CommandStore` | Oförändrat, separat från tabellen. |

## Nivå 1, i telefonen
| Åtgärd | Exempel på fraser | Vad händer |
|---|---|---|
| Upprepa | upprepa, säg det igen, kan du upprepa, vad sa du | Ljudet från senaste svaret spelas igen ur minnet (`PlaybackService` sparar det medan det spelas, högst 120 s). Inget TTS-anrop. Igenkänningen är stängd under tiden (eko). Finns inget sparat läses texten upp igen. |
| Viska / högre | viska, tystare, sänk volymen / högre, höj volymen | Volymen på uppspelningsnoden ändras: × 0,6 per "viska", ÷ 0,6 per "högre", mellan 0,25 och 1. Den sparas och gäller i alla lägen (× Rizz-nivån). Inte telefonens volym. |
| Kortare / längre | svara kortare, kortare svar, snabbare / längre svar | `length` short/long resten av passet, över inställningen. Nollställs när lyssnandet slutar. |
| Spara det | spara det, spara svaret | Senaste svaret läggs i Anteckningar. |
| Nästa prov | vilket prov har jag härnäst, när är nästa prov | Läses ur provplanerna ("Biologiprovet, ons 19 nov, om 10 dagar."). Ingen LLM. |
| Byt läge, pausa, avsluta, musik | se `docs/COMMANDS.md` | Som förut, men från tabellen. |

**Bekräftelser** ("Kortare.", "Sparat.") sägs bara när Lumen inte redan pratar.

**Universella ord utan "Lumen":**
- Orden: "upprepa", "viska", "högre", "kortare", "snabbare", "utveckla".
- Bara som hela yttrandet och bara i Provläge och Frågor.
- Kan stängas av: Inställningar › Röstkommandon › "Korta ord utan "Lumen"".
- I Socialt läge, Rizzläge och Intervjuläge krävs alltid "Lumen".

## Nivå 2, i samma /answer-anrop
- Alla övriga på listan ligger i tabellen: förhör mig (på X), utveckla, förklara enklare, exempel, sammanfatta,
  A-nivå, svår fråga, snabbförhör, svagaste områden, var säker, vad missade jag, diskret, som jag brukar, intervjuns
  fem, socialt/rizz fjorton och tre alternativ.
- Appen skickar dem som instruktion i den **första standardformuleringen**. En egen fras som "testa mig på X" når
  alltså backend som "förhör mig på X", alltid med samma ord för K9:s tabell.
- Ingen extra rundresa.
- Utanför sina lägen blir frasen samma vanliga instruktion som förut.

## Tester (`LumenTests/A7Tests.swift`, gröna i 42654364887)
- Ingen standardfras tillhör två åtgärder.
- 3–5 varianter per nivå 1-åtgärd blir rätt kommando.
- 2–4 varianter per nivå 2-grupp skickas i en formulering.
- Lägesbyte med sex formuleringar till alla fem lägen.
- **Negativa fall, 0 falska träffar på 10 meningar:**
  - "jag vill byta till ett annat ämne", "kan du upprepa det för klassen", "hon sa viska";
  - "vi måste prata högre i salen", "läraren sa att vi ska spara det till nästa lektion" …
- Universella ord bara som hela yttrandet.
- "glöm inte" blir minne.
- Sessionens längd går före inställningen.
- Även A6-testerna och alla tidigare tester är gröna.
- **Ej verifierat på enhet:** upprepa ur minnet, volymen och allt AirPods-beteende.

## Inte byggt
- **Statistik per begrepp** för "testa mina svagaste områden" och "hur bra kan jag det här" (antal rätt och fel per
  begrepp i provprofilen). Kevins K9 ska ta emot statistiken, men formatet är inte bestämt. Jag bygger det när K9
  har ett kontrakt.
- **"Var säker" (Sonnet)** och **"vad missade jag"** är backendens jobb (K9). Appen skickar redan transkriptet för de
  senaste 60 s. Ska "vad missade jag" täcka längre tid behöver backend säga hur mycket.

## Till Toby
En rad per grupp i `docs/DEVICE-TEST-QUICK.md`:
1. "Lumen, upprepa": samma röst igen direkt, utan väntan.
2. "Viska" i Provläge utan "Lumen": tystare. "Lumen, högre": högre.
3. "Lumen, svara kortare": nästa svar är kort.
4. "Lumen, spara det": syns i Anteckningar.
5. "Lumen, vilket prov har jag härnäst?"
6. "Lumen, förhör mig på fotosyntes": en förhörsfråga kommer.
7. Byt läge från vart och ett av de fem lägena.

## Till Kevin (K9)
- Instruktionerna kommer i formuleringarna i `docs/COMMANDS.md`, nivå 2 (kolumnen "Skickas som").
- Fyll gärna i backend-delen längst ner i filen.

## Concerns
"Hjälp mig diskret" är bara en längdstil, ett kort svar på en mening. Det finns ingen funktion som döljer appen.
Lyssnarindikatorn och samtycket är oförändrade.

## Nästa
A10.
