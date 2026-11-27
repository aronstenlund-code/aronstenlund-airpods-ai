# T59: Försök igen, Pausa, engelska kommandon och reservrösten (Toby (moln), 2026-11-27 02:15)

Uppdrag: Deangelo 2026-11-27 01:17 (effort high). E2E för det nya på main:

- D269: Försök igen efter ett misslyckat svar, och Pausa.
- Ke91/D268: "next/continue/quiz me" på engelska.
- K124/D267: reservrösten när `/tts` svarar 503 `tts_quota`, mot en låtsasserver.

Sedan skärmturen T3 mot main i största textstorleken. 0 ElevenLabs.

## Så är testet byggt

`AppTests/E2E/Flow/FlowE2ETests.swift` (Swift Testing, `@testable import Lumen`), med `scripts/apptest/t59.sh` och `.github/workflows/apptest-t59.yml`. Det använder hela appens koppling (`AppContainer`). En `URLProtocol` i testprocessen spelar server:

- `/answer` misslyckas (504 `timeout`, eller ingen anslutning) eller svarar med en kort SSE-ström.
- `/tts` svarar 503 `{"error":{"code":"tts_quota","fallback":true}}`.
- `/stt-token` är stängd.

Inget når Claude eller ElevenLabs. Frågorna kommer genom textfältet (`submitText`) eller som Scribes text (`receiveFinalTranscript`).

## Resultat: grön, 5 tester och 6 fall (Apptest flow 45923411947, `toby/t59` f3ff23fe = main 8090ba6d + testet; Simulator iPhone 17 Pro, iOS 26.5)

| Fall | Utfall | Vad som syntes |
|---|---|---|
| try-again-timeout | ok | Fråga 1 besvaras. Fråga 2 får 504 → kortet "Jag kan inte svara just nu". Försök igen skickar **en** `/answer` med `"fragment":"vad är fotosyntes"`, alltså den fråga som föll och inte "vad är pi". Svaret kommer och kortet går bort. |
| try-again-offline | ok | Samma sak utan anslutning: kortet Ingen internetanslutning har nu Försök igen och frågar fotosyntesfrågan en gång till. |
| pause-in-more-window | ok, men bara delvis | Pausa på skärmen pausar ("Paused — by you"). **Mer?-fönstret öppnades inte** efter textfrågans korta svar, så pausen *i* fönstret (D269 punkt 2) är inte prövad här. Den finns i Angela Schrutes enhetstester. |
| en-lumen-continue | ok | Engelska: pausad → "Lumen, continue" → Listening. Inget gick till `/answer`. |
| en-quiz-me | ok | "Lumen, quiz me" gav ett `/answer` med `"fragment":"förhör mig"` och `"transcript":"Lumen, quiz me"`. Minitestet startade inte. |
| tts-quota-phone-voice | ok | En ElevenLabs-röst är vald. `/tts` får 503 `tts_quota` (stoppad i testet), Speaker faller tillbaka till telefonens röst (`fallbackCount` 1) och svaret sägs. På Lyssnar står "EarMind hör och pratar lite sämre just nu". |

Allt är **verifierat i CI (Simulator)**. Ljudet i AirPods och telefonens röst på riktigt är inte provade (enhet).

"next" i Provfrågor (`PracticeNav`) är prövat i Angela Schrutes enhetstest (`Ke91WordsTests`), inte här. Provfrågor behöver ett prov från servern, och modellen är utan krediter.

## Till Angela Schrute (rader i `prompts/queue/angela.md`, låga, inte fel som stoppar något)

1. **Raden när telefonens röst läser:** appen visar A45:s allmänna rad "EarMind hör och pratar lite sämre just nu", inte en rad om att telefonens röst läser. D267 och Kevin föreslår till exempel "Telefonens röst läser just nu.". Det är Kellys ord att bestämma.
2. **`/tts` frågas igen för varje svar medan kvoten är slut.** Servern säger nej direkt i 10 minuter (K124), så det kostar ingenting. Det är bara ett extra anrop per mening ("pause over → first sound" 140–248 ms i Simulatorn).
3. **Den andra frågan väntade 7,8 s** medan telefonens röst stängdes av: "Activation was held 7786 ms on the phone: stopping the voice 7784 ms (… player 7782 ms) (A72)". **Untested assumption:** att det bara gäller Simulatorn. Det kan vara värt att se på en telefon.
4. Engelska "quiz me" i Standard skickas som den svenska instruktionen "förhör mig" med `"lang":"sv"` (appens språk i testet) och `"language":"en"`. Det är inte minitestet, som det ska. Om svaret kommer på engelska är inte prövat här, eftersom servern är låtsad.

## Skärmturen i största textstorleken

Väntar på en ledig macOS-maskin (D217). Den körs på main med pro-light-storsta-text och pro-dark-storsta-text, och resultatet läggs till här.

T58 genom vyerna på main (45923414991) avbröts utifrån kl. 02:01 under vy-steget, efter att delen i processen hade gått igenom. Den körs om.

0 ElevenLabs, inga anrop till riktiga /answer. T1 är fortfarande röd med flit (D180). **Aron:** testpubliceringen 3afc21d0 finns kvar och tas bort bara på ditt ja.
