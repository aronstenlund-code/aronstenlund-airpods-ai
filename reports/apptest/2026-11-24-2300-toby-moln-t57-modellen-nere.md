# T57: appen när modellen är nere (A159, A160, D258)

Toby (moln), 2026-11-23 20:30 – 2026-11-24 23:00. Uppdrag: Deangelo 2026-11-23 19:15 (T57), krokar från Angela Schrute (A159) och Angela Fable (A160). **Simulatorn, inte enhet. 0 ElevenLabs, 0 anrop till riktiga /answer och /exam** (krediterna är slut, D258). En macOS-maskin per körning (D217).

## Vad som finns
`AppTests/E2E/ModelDown/ModelDownE2ETests.swift`, `scripts/apptest/t57.sh` och `.github/workflows/apptest-t57.yml` (för hand, eller vid push till `toby/t57*`).
- Testet går i processen, som T10 och T17c. En `URLProtocol` svarar `503` med `{"error":{"code":"provider_quota",…}}` på `/functions/v1/answer` och `/functions/v1/exam`. Det är vad riktiga servern säger när modellens krediter är slut, så inget når Claude.
- `/stt-token` och `/tts` är också stängda (D180). Scribe är av, och fångsten spelar tystnad.
- Resten är riktiga backend: inloggning och `/drill quota`. Krediterna läses före och efter med appens egen `refreshQuota()`.
- Telefonens modell är Angela Schrutes låtsasmodell (`OnDeviceMock` i UserDefaults innan `AppContainer` görs, samma som `-OnDeviceMock`). Den gäller både svaren (A159) och rättningen (A160), eftersom Simulatorn saknar Foundation Models.
- Del 1: frågan matas in i `ListeningModel` som Scribes text, och svaret läses ur sessionens `answered`-händelse.
- Del 2: Nytt prov via `RepetitionModel.make`, och rättning via appens egen `ExamClient.grade` (`container.listening.examClient`).

## Resultat
| Körning | Vad | Resultat |
|---|---|---|
| 45250753732 | del 1 | 2 av 4 gröna: utan modell frågades `/answer` två gånger (se fynd 1). Kravet sänktes till högst 2 där |
| **45501143183** | **del 1 och del 2** | **grön** |

**Verifierat i CI (Simulator, iPhone 17, iOS 26.5):**
1. **En fråga när modellen är nere:**
   - Med låtsasmodellen (`sv,en`) svarar telefonen på det talade språket: "Jag svarar med telefonens egen modell. Det här är ett låtsassvar från telefonens modell." och "Answering with the phone's own model. This is a pretend answer from the phone's model.". `/answer` frågades en gång (503), sedan telefonen.
   - Utan modell (`none`), och med en modell som bara kan engelska för en svensk fråga, kommer inget svar. Skärmen säger `overloaded` ("Jag kan inte svara just nu", O97-raden).
2. **Nytt prov:**
   - Servern säger nej med 503, och appen läser det som `modelDown`.
   - Knappen säger "Kan inte skapa prov just nu" med raden "Sparade prov går att öva. Försök igen om en stund.".
   - Inget prov skapas: 0 → 0.
3. **Rättning när modellen är nere** (Provfrågor och provsessionen använder `ExamClient.grade`):
   - Med låtsasmodellen: "Telefonens modell: Rätt. Det här är ett låtsassvar från telefonens modell." och 1 poäng, samt den engelska motsvarigheten "The phone's model: Right. …".
   - Utan modell: "Facit visas – rättningen är tillbaka när EarMind kan svara igen. Facit: Den gör socker och syre …" och 0 poäng, samt "Showing the answer – grading is back when EarMind can answer again. Answer: …".
   - `/exam` frågades en gång per svar.
4. **Krediterna oförändrade:** 1 500 → 1 500 i alla fall, mätt med riktiga `/drill quota`.

## Fynd
1. **Till Angela Schrute (låg):** utan telefonmodell frågas `/answer` två gånger per fråga. Först frågar appen i förväg på den halva texten ("Answer ahead failed: … provider_quota"), och sedan igen på den färdiga texten. Båda får 503 och inga krediter dras. A159-rapporten säger "en gång per fråga", vilket bara stämmer när telefonen svarar: då används svaret som togs i förväg. Förslag: när frågan i förväg fick `provider_*` och telefonen inte kan svara, fråga inte servern igen inom samma fråga.

## Inte testat
- **"Ett sparat prov går att öva" (T57 punkt 2a):** ett sparat prov live kräver att `/exam` har gjort ett prov, och det går inte nu, eftersom riktiga `/exam` också är nere. Testerna har inte heller någon delningskod.
  - **Krok till Angela Fable eller Schrute:** ett startargument i testbyggen, t.ex. `-SeedSavedExam 1`, som lägger ett sparat prov med tysta ljudfiler i telefonens lager, eller en delad provkod hos Kevin som alltid finns för testtrafik. Då provar T57 Starta prov och spelaren medan `/exam` och `/answer` svarar 503.
  - Angela Fables enhetstest håller fast att ett sparat prov startar som förut (**verified in docs**: A160-rapporten).
- Den riktiga modellen (Foundation Models) och riktiga tryck på en iPhone. Det är Arons prov.
- Lyssnarlägenas egen provsession med talade svar. Rättningen är provad på `ExamClient`, som båda lägena använder, inte genom skärmarna.
