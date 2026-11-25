# T3: skärmturen hittar varje rad i Inställningar igen (Toby (moln), 2026-11-25 03:05)

Uppdrag: Deangelo 2026-11-24 21:49 (effort medium). Skärmturen T3 var röd på main i natt (Apptest screens 45396745804): `ScreenTourTests.swift:484 "[liten-light] settings row Integritet och samtycke not found"`. Hitta orsaken, rätta testet så att det hittar raden oavsett språk och plats, ändra inte appkoden.

## Resultat

- **Orsaken låg i testet, inte i appen** (verifierat i CI, Simulator). A157 lade språkvalet och A162 aktiveringsordet överst i Inställningar, så listan blev längre. På iPhone SE fortsatte varje svep av sig självt mer än en skärmhöjd, och raden "Integritet och samtycke" hamnade mellan två titter varje gång. I de andra sex lägena var skärmen tillräckligt hög.
- **Rättat i testet** (`AppTests/E2E/Screens/ScreenTourTests.swift`, inget i appen):
  1. Listan dras och hålls stilla innan den släpps (`press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`), cirka 65 % av skärmen per steg, så varje rad syns minst en gång.
  2. Varje rad söks på svenska och engelska (texterna ur String Catalog, A157), t.ex. "Integritet och samtycke" / "Privacy and consent", och sidorna gås igenom i den ordning de står på skärmen.
  3. Före sidorna dras listan till toppen tills `settings.appLanguage` syns. Det är den enda raden i Inställningar som har ett id.
  4. Inget steg uppåt när toppraden redan syns. Ett drag nedåt från toppen stänger bladet på SE, och det var det som fällde liten-light i 45506656525.
  5. Stängs bladet ändå öppnas Inställningar igen. För raderna under Avancerat fälls Avancerat ut igen, och sökningen görs om en gång.

## Körningar (Apptest screens, Simulator iOS 26.5, Xcode 26.6)

| Körning | Gren | Lägen | Resultat |
|---|---|---|---|
| 45396745804 | main (natt) | 7 | röd: liten-light, Integritet och samtycke not found |
| 45484875536 | toby/t3-scroll | liten-light | röd: långsamma drag (37 min), Rå transkription och svar not found (Avancerat infällt igen) |
| 45502522741 | toby/t3-scroll | liten-light | grön, 47 bilder, 0 saknade, 13 min |
| 45506656525 | toby/t3-scroll | 7 | 6 gröna. liten-light röd: bladet stängdes av ett drag nedåt från toppen, och det nyöppnade bladet hade Avancerat infällt, så "Rå transkription och svar" fanns inte. |
| 45534255559 (försök 1) | toby/t3-scroll | liten-light | föll före testet: runnern kunde inte hämta paketet NemoTextProcessing ("Could not connect to the server"), alltså nätet, inte testet |
| 45534255559 (försök 2) | toby/t3-scroll f95f9f0c | liten-light | **grön**, 47 bilder, 0 saknade, 755 s; bladet stängdes aldrig (tidigare 4–5 gånger per tur) |

De sex gröna lägena i 45506656525 hade 47 bilder och 0 saknade:

| Läge | Tid |
|---|---|
| pro-light | 645 s |
| pro-dark | 755 s |
| pro-light-storsta-text | 1 912 s |
| pro-dark-storsta-text | 1 868 s |
| liten-dark | 795 s |
| pro-light-mikrofon-nekad | 1 857 s |

Den sista ändringen (punkt 4 och 5) rör bara sökningen när bladet stängs eller när toppen syns. **Untested assumption:** att de sex andra lägena förblir gröna med den; de kör på main i nattflödet.

Sammanslaget till main (`Merge toby/t3-scroll …`, [skip ci], inget iOS-bygge körde).

## Kvar och risker

- "Fler lägen" finns inte på Start sedan A115. Turen skriver en notering och fotar inte lyssnarlägena, som förut (inget fel).
- **Krok till Angela Schrute (önskemål, låg):** fasta `accessibilityIdentifier` på raderna i Inställningar (t.ex. `settings.privacy`, `settings.notes`, `settings.advanced`, `settings.rawTranscript`, `settings.diagnostics`, `settings.deleteAccount`). Då hittar testet raderna utan att leta efter text på två språk. Står i `prompts/queue/angela.md`.
- Bara Simulator, aldrig en verifiering på enhet. 0 ElevenLabs, inga anrop till /answer.
- T1 (Apptest audio chain) är fortfarande röd med flit (D180).
- T57 del 2 är klar (45501143183, rapport `reports/apptest/2026-11-24-2300-toby-moln-t57-modellen-nere.md`).
- **Aron:** testpubliceringen 3afc21d0 finns kvar och tas bort bara på ditt ja.

## Nästa session

Läs nattens Apptest screens på main (alla sju lägena) och se att liten-light håller. Lägger Angela Schrute in id:n på raderna, byt textsökningen mot id:n.
