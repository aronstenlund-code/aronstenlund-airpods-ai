# T60–T63: Lyssnar när något går fel, Historik, A168, korta Inställningar, starttid (Toby (moln), 2026-11-27 05:45)

Uppdrag: Deangelo 2026-11-27 04:07 och 05:19 (effort high):

- E2E för D273 och D271 med låtsaskällor.
- E2E för A168 och de nya Inställningarna: allt viktigt hittas överst, och Avancerat fälls ut.
- Hela nattsviten mot main, och rätta röda tester.
- Mät starttiden i Simulatorn före och efter den snabba starten.

0 ElevenLabs. **Det här är en rapport som fylls på medan körningarna går (högst 2 macOS, D217).**

## T60: D273 och D271, grön (Apptest trouble and history 45944078112, `toby/t60` d7193975 = main + testerna; Simulator iPhone 17 Pro, iOS 26.5)

`AppTests/E2E/Trouble/TroubleE2ETests.swift`, med `scripts/apptest/t60.sh` och `.github/workflows/apptest-t60.yml`. Testet går genom appens koppling (`AppContainer`).

- **Låtsaskällor:** nätet, batteriet och lågenergiläget (`DeviceConditions`), och ljudsessionens eget route-meddelande när AirPods försvinner.
- **Ljudvägen är riktig:** Simulatorn har inga AirPods.
- **Låtsasserver:** `/answer`, `/tts` (`tts_quota` eller ingen anslutning) och `/stt-token` är stängda.
- **Två pass:** först med mikrofonen tillåten, sedan med den nekad (`simctl privacy revoke`).

| Fall | Utfall |
|---|---|
| Raden under brickan, sv-SE och en-US, med och utan telefonens modell (4 fall) | ok: "Inga AirPods anslutna. Svaren hörs i telefonens högtalare – sätt i AirPods när du vill." medan EarMind lyssnar. Nätet av ger "Inget nät. Telefonens egen modell svarar så länge." med modell och "Inget nät. EarMind lyssnar vidare och svarar när du är uppkopplad igen." utan. När nätet kommer tillbaka står AirPods-raden igen. Bevakningen startar med passet och slutar vid Avsluta, och då står ingen rad. |
| AirPods bort, "pausa när AirPods försvinner" på | ok: pausat (`outputDeviceLost`), kortet "EarMind pausade. Sätt i AirPods så lyssnar den igen, eller lyssna vidare med telefonens högtalare." med **Lyssna vidare**. Lyssna vidare lyssnar igen, och raden om högtalaren kommer. |
| AirPods bort, inställningen av | ok: lyssnar vidare, kortet "Svaren hörs nu i telefonens högtalare." med Pausa. |
| Mikrofonen nekad | ok: kortet "Mikrofonen är avstängd. Slå på den i Inställningar för att fortsätta." med **Öppna Inställningar**, och lyssnar inte. |
| Historik (D271) | ok: svaret står i Historik, sökningen "fotosyntes" hittar det och raden står under "I dag". ▶ läser det med talade svar av och Apples röst. Med en ElevenLabs-röst och `tts_quota` läser telefonens röst (en fallback). Utan anslutning läser telefonens röst utan att `/tts` frågas igen, eftersom ElevenLabs väntar i 10 minuter efter kvoten. Det visar att Angela Schrutes rättning av mitt T59-fynd 2 fungerar. Den engelska raden läses på engelska. |

Allt ovan är **verifierat i CI (Simulator)**.

**Inte prövat här:**

- Batteriets och lågenergilägets rader i flödet. De står efter AirPods-raden i ordningen, och Simulatorn har aldrig AirPods, så bara deras ord loggas här ("Batteriet är på 8 %. …", "Lågenergiläge är på. …"). Ordningen testas i Angela Schrutes `ListeningTroubleTests`.
- AirPods på riktigt.

Inget fynd i appen. Med engelska som talat språk och svenska som appens språk är raden svensk, eftersom appens språk bestämmer orden.

## T61: A168 (komma tillbaka), väntar på omkörning

`AppTests/E2E/Comeback/ComebackE2ETests.swift` körs i repetitionens låtsasläge (`RepetitionMock`): två prov görs och det äldre spelas. Första körningen kom inte igång, eftersom ljudet görs med telefonens röst efter sparandet och Starta prov inte startar förrän första frågan har ljud. Testet väntar nu på `canStart`. 0 anrop.

## Rättat i testerna (A166–A168, Ke93, korta Inställningar)

- **Skärmturen:**
  - Ke93: "Prov från din skola" och "Öppna länk" (på main, 4aed5848).
  - Turen startar appen med Avancerat öppet (`-settings.showsAdvanced YES`) och trycker aldrig på raden. I 45931536109 (pro-dark i största text) fällde ett andra tryck ihop ett öppet Avancerat, så Diagnostik och Rå transkription saknades.
  - Raderna som alltid syns öppnas först och raderna under Avancerat efter. Det fungerar med både de gamla och de korta Inställningarna.
- **T36 (Säg i AirPods):** ett tryck på en text under Senaste spelar den nu (A168), och "Lägg i fältet" ligger i det långa trycket. Utan nät spelar trycket direkt.
- **T63:** korta Inställningar och **T62:** starttid. Skrivna, och körs mot main nu när den snabba starten och de korta Inställningarna ligger där.

## Skärmturen i största text på main (45931536109): röd i testet

Båda fallen är rättade enligt ovan:

| Läge | Bilder | Saknade | Orsak |
|---|---|---|---|
| pro-light-storsta-text | 47 | 1 | Ke93:s nya radnamn |
| pro-dark-storsta-text | 47 | 3 | Ke93 + Avancerat som fälldes ihop |

0 ElevenLabs, inga anrop till riktiga /answer. T1 är fortfarande röd med flit (D180). **Aron:** testpubliceringen 3afc21d0 finns kvar och tas bort bara på ditt ja.
