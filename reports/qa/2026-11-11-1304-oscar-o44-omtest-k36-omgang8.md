# Oscar O44: Omtest av O42-resterna efter Kevins omgång 8 (ringa och musik)

Datum: 2026-11-11, 13:00–13:04 (svensk tid)
Uppgift: kör om de tre K36-fel som var kvar i O42 (`reports/qa/2026-11-11-1227-oscar-o42-omtest-k40-k17-o34-o39.md`), efter Kevins rättningar `608e62c`, `806d2cb`, `79a1d8e` och `83792af` med rapporten `202bdf7`.

**Skript:** `scripts/qa/o41c_k36_repeat.py` (varje fall 3 gånger) och `scripts/qa/o41_k36_live.py` (hela regressionen).
**Rådata:** `reports/qa/data/2026-11-11-1301-o41c-k36-repeat.json` och `…-1304-o41-k36.json`.
**Kostnad:** cirka 0,02 USD (Haiku), 0 ElevenLabs.

## Resultat: allt rättat. **K36 godkänd**
| Fall (3 gånger var) | O42 | **Nu** |
|---|---|---|
| "ring Bris" (tryck-och-prata) | tyst 3/3 | **`call_contact {number: "116111"}` 3/3** |
| "spela musik" (tryck-och-prata) | `music_open` 2/3 | **3/3** |
| "Lumen, spela musik" (Auto) | 0/3, och "Jag öppnar musik…" utan verktyg | **`music_open` 3/3**, inget osant tal |
| "spela musik" utan "Lumen" (Auto) | 1/3 | Inget verktyg och tyst, 3/3. Rätt, Auto kräver nu "Lumen" |
| "ring mamma" utan "Lumen" (Auto) | samtal 3/3 | **Inget samtal, 3/3**. Det Lumen råkar höra startar inget |

**Hela O41-regressionen (29 fall):**
- **29/29.**
- 0 tal före verktyget.
- `connections` 4/4 stängt.
- B6: 0 påhittade nummer.
- 112, siffror sagda i ord och "mamma ringde nyss" är fortfarande rätt.

**Märkning:** verified live mot servern. Appens del (Kontakter, `tel:` och Spotify-sökning, A58) är inte provad på telefon.
