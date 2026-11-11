# Oscar O48: Rättelser med egna ord live efter Kevins Haiku-kontroll (omgång 13)

Datum: 2026-11-11, 16:05–16:10 (svensk tid)
Uppgift: omtest av O47. Kevins omgång 13 (`915211e`, `f901141`, rapport `f97ac88`): en kort mening som koden inte känner igen som rättelse får en liten Haiku-kontroll i `/memory`. Svaret är shorter, longer, simpler, examples, careful eller none.

**Skript:** `scripts/qa/o48_corrections_live.py`. Det kör `POST /memory {"correction": {...}}` och sparar inget på servern.

**Fallen:**
- O22b:s 20 rättelser och 15 vanliga meningar. **Inga av dem finns i Kevins tester** (kontrollerat med grep i `memory/handler_test.ts`).
- 15 **nya** korta meningar som liknar återkoppling men handlar om något annat. De mäter den nya risken med en modellkontroll.

**Rådata:** `reports/qa/data/2026-11-11-160940-o48-corrections.json`.
**Kostnad:** under 0,01 USD (Haiku), 0 ElevenLabs.

## Resultat
| | O47 (bara kod) | **O48 (kod + Haiku)** |
|---|---|---|
| Rättelser med nya egna ord | 5/20 | **19/20** (missad: "utveckla gärna mer") |
| Vanliga meningar (O22b) blir inte rättelser | 15/15 | **10/15** |
| Nya meningar som liknar återkoppling blir inte rättelser | – | **9/15** |
| **Falska rättelser totalt** | **0/30** | **11/30** |

**Falska rättelser som skulle sparas som inställning:**
- **"enklare":** "boken är för svår", "provet var för svårt", "min kompis förklarar alltid för krångligt", "jag fattar inte varför Napoleon förlorade", "jag förstår inte vad tyska verb är för något, kan du förklara", "förenkla bråket tolv sextondelar".
- **"kortare":** "läraren pratar för mycket".
- **"fler exempel":** "kan du ge exempel på ädelgaser" och "exempel på en dikt av Karin Boye". Båda är frågor.
- **"var noggrannare":** "det var fel av Sverige att gå med i kriget" och "det stämde inte med vad läraren sa om Gustav Vasa, vem hade rätt".

## Men: elevens egna ord når inte `/memory` i dag (verified in code)
Appen anropar `learnCorrection` (`ListeningModel.swift:3362`) bara med **fasta ord**, efter att appens egen kommandotolk har känt igen kommandot:
- "enklare" och "mer exempel" (rad 1399)
- "det där var fel" (rad 1423)
- "kortare" och "längre" (rad 1451)

`/answer` använder `detectCorrection` bara för att välja hastighetsgräns (`handler.ts:1345`), inte för att spara något. Följder:
1. **De falska rättelserna skadar inte i dag.** Haiku-kontrollen körs bara för text som koden inte känner, och appen skickar bara text som koden känner.
2. **Kevins rättning hjälper inte heller i dag.** "kan du korta ner svaren lite" når aldrig `/memory`. En rättelse med egna ord blir ingen sparad inställning, om inte appens kommandotolk känner igen den. Den är inte testad av mig, eftersom den är Swift-kod (Tobys område).

## Till Kevin och Angela (prio 3, ingen blockerare)
- **Innan appen börjar skicka elevens egna ord till `/memory`:** prompten måste säga att det ska handla om **assistentens svar**. Inte böcker, lärare, prov eller kompisar, och inte en fråga som innehåller "exempel" eller "fel". Kör sedan `o48_corrections_live.py` igen. Kravet är högst 1/30 falska.
- **Alternativ:** låt modellen i `/answer` flagga en rättelse i samma anrop som svaret. Där finns sammanhanget (det förra svaret), och det kostar inget extra anrop.
- Toby kan mäta appens kommandotolk med O22b-fallen i simulatorn. De ligger i `scripts/qa/o22b_corrections_offline.mjs`.
