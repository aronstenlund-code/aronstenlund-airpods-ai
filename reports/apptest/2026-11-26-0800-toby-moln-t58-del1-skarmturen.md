# T58 del 1: skärmturen, nattens röda pro-light (Toby (moln), 2026-11-26 08:00)

Uppdrag: Deangelo 2026-11-26 08:49 (T58 i `prompts/queue/toby.md`). Nattens T3 (Apptest screens 45605345750, main ec6224f7) var röd: "[pro-light] Välkommen not shown on a new installation", "Säg i AirPods: no field on Start", "Start: no credit capsule".

## Orsaken: appen kom aldrig upp i första läget (testet och simulatorn, inte appen)

- **Verifierat i CI:** 6 av 7 lägen var gröna i samma körning, med 47 bilder och 0 saknade, liten-light (iPhone SE) också. Gårdagens rättning av Inställningar håller alltså.
- **Verifierat i CI:** bara pro-light föll. Det är det första läget, på en simulator som just skapats och startats för första gången på runnern. Turen tog 1 bild och sedan "Application com.rsolutions.lumen is not running" (`ScreenTourTests.swift:459`, "Failed to get matching snapshot"). De två andra raderna följer av det. Pro-dark på samma simulator efteråt var grön.
- **Untested assumption:** att den första starten på en kall simulator tog för lång tid och stängdes. Det finns ingen kraschlogg i körningen, och artefakterna går inte att hämta härifrån (proxyn ger 403).
- Natten 2026-11-23 (45160984259) föll pro-light av ett annat skäl ("could not go back from Studiekort"). Den här felbilden är ny och har inte setts förut.

## Rättat i testet (`AppTests/E2E/Screens/ScreenTourTests.swift`, inget i appen)

1. `welcome()`: om appen inte kör efter 25 s startas den en gång till och får 45 s. Turloggen skriver "the app was not running after its first launch …; launched again". Kommer appen inte upp efter två starter är turen fortfarande röd, nu med appens tillstånd i raden.
2. `waitFor` frågar inte en app som inte kör. Det är ett fel i sig i XCUITest, och det skulle göra turen röd även när den andra starten lyckas.
3. Kreditkapseln får vänta 20 s i stället för 10, eftersom den saknades också i liten-light 2026-11-23.

## Körning

- **Apptest screens 45775978710** (`toby/t58` 5df835a6, bara pro-light, Simulator iOS 26.5, Xcode 26.6): **grön**, 47 bilder, 0 saknade, 623 s. Appen kom upp på första starten den här gången, så den nya andra starten användes inte. **Untested assumption:** att den andra starten hjälper när felet kommer igen. Nattflödet visar det.
- Sammanslaget till main (65cf0de9, [skip ci]).
- `accessibilityIdentifier` på raderna i Inställningar kommer med A164 (Angela Schrute). När de ligger på main byter jag textsökningen mot dem.

## Del 2 (väntar)

T58 del 2, E2E för Spela in själv (D263), görs när A164 och A165 ligger på main. Planen:

- En process med `@testable import Lumen`, som T57. Testet skapar en samling via `OwnDeckModel` och gör en låtsasinspelning.
- Det övar med `RepetitionModel.start(own:)` och kontrollerar krediterna före och efter.
- En `URLProtocol` räknar varje nätanrop, som ska vara 0.
- Bladet visas när `/answer` eller `/drill` svarar 402 eller `provider_quota`.
- Turen fotar ingången, om det går med `-SeedOwnDeck 1`.

Jag har bett Angela Schrute om en låtsasinspelning för testbyggen, eftersom simulatorn inte har någon mikrofon i CI.

Bara Simulator, aldrig en verifiering på enhet. 0 ElevenLabs, inga anrop till /answer. T1 är fortfarande röd med flit (D180). **Aron:** testpubliceringen 3afc21d0 finns kvar och tas bort bara på ditt ja.
