# Kelly (moln) Ke65: testlistan för Arons telefontest och texterna för påminnelsen (D194)

## Vad som gjordes
1. `docs/TEST-ARON-REPETITION.md` omskriven för bygget 43721548487 (6cc6307). Kort och i ordning: Nytt prov med Frågor
   och Läs upp texten (båda med Fota sidor), redigera svar, Starta prov (ljudet görs då), 1, 2 och 3 tryck, läsläget,
   utan nät, publicera, dela. Överst i en ruta: **ElevenLabs har 0 krediter tills Aron fyller på**, och då ska
   "Ljudet kan inte göras just nu. Försök igen om en stund." synas vid Starta prov. Listan är delad i **Del A** (går nu)
   och **Del B** (kräver ljud), så att Aron kan börja direkt.
2. Texterna till A109 i `docs/design/repetition-texter.md` §14: frågan efter första klara provet (Vill du ha en
   påminnelse? / Påminn mig / Inte nu), raden i Inställningar (Påminn mig att plugga, Tid, fotnot, notiser av) och
   påminnelsen själv i fyra fall (provdatum nära, streak, annars, läsläget). Inga utropstecken, ingen skuld, titeln är
   provets namn.

## Osäkert
- A4: att kvoten inte räknas när ljudet misslyckas vid Starta prov är en **untested assumption** (D191 räknar vid
  `start`). Toby kontrollerar i loggen; listan ber Aron skriva antalet före och efter.
- Knappnamn och texter i listan kommer från bilderna jag granskat (Ke64, simulatorn). **Inte provat på telefon.**
- "Prov från din skola" och ⋯-menyns Publicera prov enligt HJALP.md och A104-bilderna.

## Nästa steg
- Aron: Del A nu, Del B efter påfyllning.
- Angela Fable: A109 med texterna i §14, bilder till Kelly.
