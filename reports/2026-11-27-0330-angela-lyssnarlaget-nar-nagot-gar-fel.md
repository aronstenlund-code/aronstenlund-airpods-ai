# Lyssnarläget när något går fel

Angela Schrute (moln, Opus 5.5), 2026-11-27. Uppdrag: Deangelo 02:59: "inga AirPods, AirPods kopplas bort mitt i, mikrofonen nekad, ingen nätverksanslutning, låg batteri/lågenergiläge – varje fall ska ge en kort, tydlig rad och en väg vidare (inget tyst stopp), på en och sv. Test först med låtsaskällor, hela sviten grön, bilder."

## Kort

| Fall | Förut | Nu |
|---|---|---|
| **Inga AirPods** när man lyssnar | Ingenting sades; svaren kom i högtalaren | En rad under brickan: "Inga AirPods anslutna. Svaren hörs i telefonens högtalare – sätt i AirPods när du vill." Den försvinner när AirPods kommer. |
| **AirPods bort mitt i**, inställningen "pausa när AirPods försvinner" på | Kortet sa "Svaren hörs nu i telefonens högtalare." med knappen **Pausa**, fast EarMind redan hade pausat | Kortet: "EarMind pausade. Sätt i AirPods så lyssnar den igen, eller lyssna vidare med telefonens högtalare." Knappen **Lyssna vidare** lyssnar vidare i högtalaren, och då kommer raden om att AirPods saknas. AirPods tillbaka: lyssnar igen och kortet försvinner, som förut. |
| AirPods bort, inställningen av (förvalet) | Lyssnar vidare, kortet "Svaren hörs nu i telefonens högtalare." med Pausa | Oförändrat, nu testat. |
| **Mikrofonen nekad** | Kortet "EarMind hör dig inte" med **Öppna Inställningar**, och skärmen som rättar mikrofonen | Oförändrat, nu testat. |
| **Inget nät** | Märktes först när ett svar misslyckades | En rad så fort nätet försvinner. Med telefonens egen modell: "Inget nät. Telefonens egen modell svarar så länge." Utan: "Inget nät. EarMind lyssnar vidare och svarar när du är uppkopplad igen." Raden försvinner när nätet är tillbaka. Misslyckas ett svar har kortet "Ingen internetanslutning" fortfarande **Försök igen** (D269). |
| **Låg batterinivå** (≤ 10 %, laddar inte) | Ingenting | "Batteriet är på 8 %. Sätt telefonen på laddning så att EarMind kan lyssna vidare." Försvinner när telefonen laddar. |
| **Lågenergiläge** | Ingenting | "Lågenergiläge är på. EarMind lyssnar som vanligt, men svaren kan dröja lite." |

Ingenting stoppar tyst: lyssnandet går vidare i alla fall utom två. Mikrofonen nekad går inte att lyssna med, och har knappen till Inställningar. AirPods bort med pausinställningen på har knappen "Lyssna vidare". Bara en rad visas åt gången, den viktigaste först: nätet, AirPods, batteriet, lågenergiläget.

Texterna finns på svenska och engelska; engelskan står i `tools/l10n/en.json`. Inte provat på telefon.

## Teknik

- `Lumen/Core/Session/ListeningConditions.swift`:
  - `ListeningCondition` med rader, symboler, ordningen `current(...)` och procent på telefonens sätt ("8 %" / "8%");
  - `DeviceConditions` (protokoll);
  - `SystemDeviceConditions`, som läser nätet (`NetworkStatus`), batteriet (`UIDevice`, bara medan EarMind lyssnar) och lågenergiläget (`ProcessInfo`).
- `ListeningModel`:
  - `deviceConditions` och `listeningCondition`. AirPods läses från ljudsessionens utgångar.
  - Bevakningen startar när lyssnandet börjar och slutar när det slutar.
  - `airPodsLostPaused` sätts vid `.paused(.outputDeviceLost)`, och `act(on: .airPodsLostPaused)` återupptar lyssnandet.
- `OnDeviceAnswerProvider.isAvailable(for:)`: om telefonens modell finns för språket.
- `LumenProblem.airPodsLostPaused` (`ErrorCard.swift`): neutralt kort, ingen röd ram och ingen talad rad, eftersom högtalaren hörs av alla.
- Raden visas under brickan på Lyssnar (`listening.condition`).
- Bildscener: `listeningNoAirPods`, `listeningOffline`, `listeningOfflineNoModel`, `listeningLowBattery`, `listeningLowPower`, `airPodsLostPaused`. Kortet finns också i scenen `errors`.

## Testresultat

- **iOS build 45926266076 grön** på `angela/lyssnarfel` (e110ddd0): enhetsbygge med varningar som fel, hela sviten (1 239 gröna testrader, 0 röda), Release-arkivet och Release-kontrollen. `ListeningTroubleTests` (13) gröna. *Verified in CI.*
- **Röd körning först: 45926269219** på `angela/lyssnarfel-test-rod` föll som väntat: efter pausad AirPods-förlust var kortet "Svaren hörs nu i telefonens högtalare." med knappen "Pausa".
- På main slogs grenen ihop med det som kommit sedan dess; `en.json` slogs ihop nyckel för nyckel, och `sync.py`/`check.py` är rena. Main-bygget skrivs in i STATUS.

- `LumenTests/ListeningTroubleTests.swift`, 13 tester med låtsaskällor (ljudväg, nät, batteri och lågenergiläge):
  - utan AirPods kommer raden, och den försvinner när AirPods kommer;
  - med AirPods sägs ingenting;
  - AirPods bort med pausinställningen: kort, Lyssna vidare och raden om högtalaren;
  - AirPods tillbaka: lyssnar igen;
  - AirPods bort med inställningen av: lyssnar vidare med högtalarkortet;
  - nekad mikrofon: kortet med Öppna Inställningar;
  - inget nät, med och utan telefonens modell, och tillbaka;
  - nätet som försvinner mitt i sägs direkt;
  - låg batterinivå, och att den försvinner vid laddning;
  - lågenergiläge;
  - bevakningen följer passet;
  - ordningen, och att varje rad är kort och varje kort har en knapp.
- **Röd först:** `angela/lyssnarfel-test-rod`, `LumenTests/TroubleRedTests.swift` (befintligt API): kortet efter pausad AirPods-förlust får inte vara högtalarkortet med Pausa.

### Bilder (Fable screens 45926305838, iPhone 17 Pro-simulatorn, ljust och mörkt, engelska och svenska)

- Grenen `fable/screens-ke93-lyssnarfel`: `listeningNoAirPods`, `listeningOffline`, `listeningOfflineNoModel`, `listeningLowBattery`, `listeningLowPower`, `airPodsLostPaused`, `errors`.
- Sett på bild:
  - raden under "● Listening" / "● Lyssnar" med ikon, till exempel "No AirPods connected …", "Inget nät. Telefonens egen modell svarar så länge." och "Battery at 8%. Plug in your phone …";
  - kortet "AirPods were disconnected · EarMind paused …" med **Keep listening**, under brickan "Paused".
- **För Kelly:** på AirPods-kortet gör knappen "Keep listening" / "Lyssna vidare" samma sak som fotens "Listen again" / "Lyssna igen". Det är två vägar till samma sak med olika ord. Säg om kortets knapp ska bort, eller heta som foten.

## Kända begränsningar

- **AirPods läses från ljudsessionens utgång.** Andra Bluetooth-hörlurar och sladdhörlurar räknas också som AirPods, eftersom de är externa ljudutgångar.
- **Batteriet:** på simulatorn säger telefonen ingen nivå, och då visas ingen rad. Gränsen 10 % är mitt val.
- **Lågenergiläget gör inte EarMind långsammare i appens egen kod.** Raden säger att svaren *kan* dröja, eftersom iOS sänker takten i lågenergiläget. Hur mycket är inte mätt på telefon.

## Nästa steg

Aron på telefon:
1. Starta lyssnandet utan AirPods.
2. Ta ut AirPods mitt i.
3. Slå på flygläget.
4. Slå på lågenergiläget.

Varje gång ska en rad eller ett kort med en väg vidare synas.
