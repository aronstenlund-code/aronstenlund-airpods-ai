# Stående uppgift, omgång 12: Oscars O43, falskt "Rätt" när Scribe läser upp termlistan (Kevin, 2026-11-11 14:22)

Fynd: Oscars O43 (`reports/qa/2026-11-11-1415-oscar-o43-enordssvar-forhor.md`):
- tyst rum **40/40**, så målet är nått;
- i klassrumssorl ger keyterm-listan som Scribe läser upp falskt "Rätt" **2/20 när eleven är tyst** (BUGG prio 2).

**Kostnad:** cirka 0,02 USD. ElevenLabs: 0.

## Gjort
**1. Termlistan räknas som "inget hört"** (`answer/soundalike.ts` `isTermListEcho`, `answer/handler.ts`):
- Det gäller i svarsfönstret efter en kontrollfråga (Provläge), när yttrandet till största delen är de termer som skickades:
  - tre eller fler listposter som är svaret, alternativen eller ämnesorden (`prep_terms`), eller
  - svaret plus två alternativ.
- Då svarar koden "Jag hörde inte riktigt. Vad sa du?", utan modell och utan betyg. Nyckeln skickas med igen till nästa försök.
- **Undantag:** när kontrollfrågan ber om flera saker ("Nämn tre floder …") kan en lista vara ett riktigt svar, och då betygsätts den som vanligt.

**2. Alternativ som är en form av svaret tas bort ur nyckeln** (prio 3):
- "Kloroplast" till "Kloroplasten" och "Mitos och cytokines" till "Mitos" stryks.
- Riktiga felaktiga svar ("Meios") är kvar.

**3. Studieprofilens termer** (Oscars bifynd: de första 20 var svenska sjöar):
- Världens mest kända namn kommer först, om inte ämnet säger Sverige.
- Live: Nilen, Amazonas, Mississippi, Jangtse, Donau, Rhen, Volga, Seine, Loire … Viktoriasjön och Ladoga finns bland de 20 första.

## Live (driftsatt `d8a24d3`, `593ac57`)
- "Viktoriasjön, Tanganyikasjön, Malawisjön," ger "Jag hörde inte riktigt. Vad sa du?"
- "Vänern, Vättern, Mälaren," (ämnesorden) ger samma sak.
- "Viktoriasjön" ger "Rätt. Viktoriasjön är Afrikas största sjö …"

## Tester
`deno task test`: **476 gröna** (3 nya i `answer/k40_test.ts`). Ljudbanken är fortfarande 43/43.

## Till Oscar
Kör om O43d (sorl, eleven tyst) när det passar. 0/20 falskt "Rätt" förväntas.
