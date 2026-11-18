# A142: testläget bara i Debug och Beta, aldrig i Release, och rättade Usage-texter (D218 punkt 4, Kellys Ke76)

Angela Schrute (moln, Fable 5.2), 2026-11-18 09:05–10:55. Main, sammanslagning 9541df0a (grenen
`claude/fervent-fermi-34hrer`, 5366bce2, 74e93bb8 och 679d050e). Underlag: `docs/appstore/granskning.md` §2.

## 1. Testläget finns inte i App Store-bygget
- **Tre byggkonfigurationer** (`project.yml`, D227):
  | Konfiguration | Till vad | Testläget |
  |---|---|---|
  | Debug | det dagliga bygget, CI, Arons osignerade .ipa | finns |
  | Beta | TestFlight och våra testare (optimerat som Release) | finns |
  | Release | App Store | finns inte |
- **Flaggan `LUMEN_TESTMODE`** sätts i Debug och Beta, aldrig i Release. Utan den kompileras inte:
  - bitarna och deras lagring (`DebugPiece`, `DebugPieceStore`),
  - skrivaren som sparar mikrofonens ljud (`DebugAudioWriter`),
  - uppladdningen och serverns adress (`DebugAudioClient`, `debug-audio`),
  - delen som startar och stoppar inspelningen (`DebugAudioController`).
- **I Release** har modellen inget testläge: Inställningar visar ingen omkopplare, Start ingen bricka, och Om appen
  säger aldrig att testläget är på.
- **Release över ett testarbygge:** väntande ljudbitar raderas från telefonen och omkopplaren nollställs
  (`TestModeBuild.removeLeftovers`), så inget ljud blir kvar och inget slås på av sig självt i ett senare
  testarbygge.
- **Varför flagga och inte en kontroll när appen körs** (till exempel TestFlight-kvittot): Apples granskare kör
  appen i samma sandlåda som TestFlight, så en sådan kontroll skulle slå på testläget för dem. Koden skulle också
  finnas kvar i App Store-binären.

**Följd som Aron och Deangelo måste känna till:** bygget som skickas till App Store-granskning ska vara ett
Release-bygge. Ett Beta-bygge får aldrig skickas till granskning. TestFlight-byggen till testare görs med Beta.

## 2. Kontrollen i CI
- `ios-build.yml` har ett nytt steg, **"Release build has no test mode (A142)"**, som körs vid varje bygge:
  1. bygger Release för enhet (osignerat);
  2. söker i hela appen efter serverns adress `functions/v1/debug-audio` och de fem typnamnen;
  3. faller om något finns i Release.
- **Kontroll av kontrollen:** samma sökning måste hitta testläget i Debug-bygget från steget före. Annars faller
  steget, eftersom sökningen då inte bevisar något.
- Ett andra steg bygger **Beta** och kräver att testläget finns där. Det körs bara vid manuella körningar.
- Jobbets tidsgräns är höjd från 60 till 80 minuter, eftersom Release-bygget lägger till 8,5–15 minuter per bygge.

## 3. Usage-texterna (Info.plist och InfoPlist.xcstrings, engelska och svenska)
| Text | Före | Efter | Kontrollerat mot |
|---|---|---|---|
| **Kamera** | "Texten läses på telefonen, och bilden sparas inte." | "Fota sidan du pluggar på. Bilden skickas en gång till EarMinds server för att göra dina frågor eller texten som läses upp, och EarMind sparar den inte." | Koden: upp till 4 foton går i själva anropet, fler laddas upp till den privata hinken `drill_material`. Servern: fotona raderas direkt efter analysen, också när den misslyckas (`exam/drill.ts`, `exam/read.ts`), och `drill-purge` tar bort allt äldre än en timme var 15:e minut. |
| **Kontakter** | "Inget från kontakterna skickas någonstans." | "Numret stannar på telefonen. Om flera kontakter passar skickas deras namn till EarMinds server, så att EarMind kan fråga vem du menar." | `LivePhoneTools.callContact`: vid flera träffar går upp till fyra namn tillbaka som verktygets resultat, och det skickas till servern. Numret skickas aldrig. |
| **Kalender** | "…berättar vad som finns i den." | Tillägg: "För att kunna berätta skickas händelserna du frågar om till EarMinds server." | `LivePhoneTools`: upp till 20 händelser (titel, tid, plats) går tillbaka som verktygets resultat. |
| **Rörelse, Apple Music** | bara engelska | svenska tillagd | – |
| Mikrofon | oförändrad | – | Meningen är beslutad i D138. Se §5. |
| Taligenkänning | oförändrad | – | Stämmer: iPhonens egen igenkänning används som reserv eller när molnet är avstängt, alltid med `requiresOnDeviceRecognition`. |
| Påminnelser, larm | oförändrade | – | Stämmer: appen lägger bara till, läser inget, och frågar först. |
| Notiser | ingen text i Info.plist | – | iOS har ingen egen text för notiser. Appen frågar bara efter ett tryck ("Påminn mig kl. …"), och notiserna är lokala; appen registrerar sig inte för push. |

Kameratexten följer Kellys förslag, med tillägget "eller texten som läses upp" och "EarMinds server".

## 4. Testresultat
- **CI:** iOS build 44273843720 (manuell körning på grenen, med main ihopslagen) är grön i alla steg:
  Debug-bygget, alla LumenTests, **Release-bygget utan testläge** ("Control: the test mode is in the Debug build",
  "Release check: no test mode in the Release build"), Beta-bygget och arkivet. *Verifierat i CI.*
  - Det första Release-bygget någonsin (44264496532) föll på tre rader i `AppContainer`: `let mock = false`
    utanför Debug gjorde en gren i `mock ? … : …` oåtkomlig, och varningar är fel hos oss. Mock-läget är nu en
    egenskap. Det var det enda felet i Release.
  - Bygget efter rättningen (44270363504) var grönt, också Release-steget.
  - Main efter ihopslagningen: iOS build 44280856886 grön, också Release-steget och arkivet. *Verifierat i CI.*
- **Enhetstester:** `A76Tests.theTestModeIsInTheTestersBuild` och
  `A76Tests.theAppStoreBuildRemovesWhatATestersBuildLeft` (nya), och de befintliga testerna för testläget
  oförändrade.
- **Beta-bygget:** byggt i den manuella körningen 44273843720 (9 minuter): det kompilerar, och
  testläget finns i det ("Beta check: the test mode is in the Beta build"). *Verifierat i CI.* Inte signerat och
  inte uppladdat till TestFlight.
- Inget är provat på telefon. Ett Release-bygge har aldrig installerats på en telefon.
- 0 ElevenLabs.

## 5. Fynd och frågor till Deangelo och Kelly
1. **Integritetstabellen i `docs/appstore/granskning.md` §2 stämmer inte för kontakter och kalender.** Den säger
   "Nej … läses bara på telefonen i Fler lägen och skickas inte". Kalenderhändelser skickas till servern när man
   frågar vad som finns, och kontaktnamn skickas när flera passar. Det ska in i App Privacy (Kontakter och
   Kalender, syfte appens funktioner), eller så får verktygen inte finnas i App Store-versionen. Kelly har fått
   en rad i sin kö.
2. **Mikrofontexten** säger "Ljudet blir text och sparas inte av EarMind" (D138). Den säger inte att ljudet
   skickas till en taligenkänningstjänst (ElevenLabs). Jag har inte ändrat den, eftersom meningen är beslutad.
   Förslag om ni vill ha in det: "Ljudet skickas till en taligenkänningstjänst, blir text och sparas inte av
   EarMind."
3. **TestFlight-byggen med testläget** skickar fortfarande ljud till oss när testaren slår på det. Det täcks av
   testlägets eget blad, inte av mikrofontexten.
4. **Kostnaden i CI:** Release-steget tog 8,5 minuter i en körning och 15 i nästa. Ett vanligt bygge tar därmed
   cirka 30–40 minuter i stället för 22–25. Jobbets tidsgräns är höjd till 80 minuter. Om det blir för dyrt (D217)
   kan steget köras bara på main och vid manuella körningar; då upptäcks ett fel först efter ihopslagningen. Jag
   har låtit det köra på varje bygge.
5. **Beslutet heter D227.** D226 var upptaget när jag slog ihop med main.

## 6. Kända begränsningar
- Texter som nämner testläget ligger kvar som strängar i Release-binären (omkopplarens rubrik, bladet), men ingen
  kod visar dem. Kontrollen i CI söker efter det som spelar in och skickar, inte efter orden.
- Release-bygget i CI är osignerat. Arkivering, signering och uppladdning till App Store Connect är inte gjorda
  och kräver Arons ja (publicering).

## 7. Vad Aron ska prova på telefon
1. Installera det vanliga bygget (Debug). Inställningar har kvar "Testläge: skicka ljud för felsökning".
2. Första gången appen ber om kameran: texten säger att bilden skickas en gång och inte sparas.

Ett Release-bygge går inte att installera med Sideloadly-flödet i dag (CI packar bara Debug-bygget).

## 8. Nästa steg
- När TestFlight sätts upp: bygg med konfigurationen Beta. När appen skickas till granskning: Release.
