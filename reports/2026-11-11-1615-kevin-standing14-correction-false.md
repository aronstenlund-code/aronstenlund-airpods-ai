# Stående uppgift, omgång 14: rättelsekontrollen utan falska träffar (Oscars O48) (Kevin, 2026-11-11 16:15)

Fynd: Oscars O48 (`reports/qa/2026-11-11-1610-oscar-o48-rattelser-haiku-live.md`). Haiku-kontrollen från omgång 13 gav rättelser 19/20 men **11/30 falska**:
- "boken är för svår" blev "enklare";
- "kan du ge exempel på ädelgaser" blev "fler exempel";
- "det var fel av Sverige …" blev "noggrannare".

Det skadar inte i dag, eftersom appen bara skickar fasta ord till `/memory`. Oscars krav innan appen skickar elevens egna ord är högst 1/30.

**Kostnad:** under 0,01 USD. ElevenLabs: 0.

## Ändring (`memory/handler.ts` `CORRECTION_CHECK_PROMPT`)
Kontrollen gäller nu bara återkoppling på **assistentens senaste svar**: längd, svårighet, exempel eller om det var rätt. Svaret är "none" när det gäller:
- något annat: en bok, ett prov, en lärare, en kompis, historia eller elevens egna problem;
- en fråga eller en begäran om innehåll, även om den innehåller "exempel", "fel" eller "förklara";
- ett kommando.

Exemplen i prompten är mina egna ("filmen var för lång", "ge exempel på däggdjur" …), inte Oscars. Hans fall förblir därmed en hållout. En första version hade hans exempel och byttes ut innan mätningen.

## Live mot `/memory` (driftsatt `b350a02`), Oscars O22b plus O48 (inte i mina tester eller i prompten)
| | Omgång 13 (O48) | **Nu** |
|---|---|---|
| Rättelser med egna ord | 19/20 | **18/20** (missar "jag orkar inte höra hela föreläsningen" och "förenkla") |
| Falska rättelser | 11/30 | **0/30** |

## Till Angela
Det är nu säkert att låta appen skicka elevens egna korta återkoppling direkt efter ett svar till `/memory` som `correction.text`, inte bara de fasta orden. Det är den del som enligt O48 saknas för att rättelser med egna ord ska fungera.

## Tester
`deno task test`: gröna (`memory/handler_test.ts`).
