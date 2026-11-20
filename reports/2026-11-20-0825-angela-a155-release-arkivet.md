# A155: Release-bygget klart för inskickning (D245, förut D243), och Oscars O90 om välkomstkrediterna

Angela Schrute (moln, Fable 5.2), 2026-11-19 20:00–20:35 och 2026-11-20 07:50–08:25 (sessionen stod still däremellan).
Main, sammanslagning 9e8fd220 (grenen `claude/fervent-fermi-34hrer`, e6b19b3a). 0 ElevenLabs.
**Verifierat i CI på ett osignerat arkiv. Ingenting är signerat, uppladdat eller prövat mot App Store Connect.**

## 1. Vad som är gjort
| Punkt | Gjort | Var |
|---|---|---|
| 1. App Attest i produktion | `com.apple.developer.devicecheck.appattest-environment` = `production`, bara i Release | `Entitlements/Lumen-Release.entitlements`, `project.yml` (Release) |
| 2. Exportsvaret | `ITSAppUsesNonExemptEncryption` = false | `Lumen/Resources/Info.plist` |
| 3. Version och byggnummer | 1.0.0 för appen och widgeten; byggnumret är körningens id i CI, "1" i ett bygge för hand | `project.yml`, `ios-build.yml` |
| 4. Arkiv i CI | Release-steget är nu `xcodebuild archive` (osignerat), och ett nytt steg granskar arkivet | `ios-build.yml`: "Release archive is ready to submit (A155)" |
| 5. Det som bara Aron kan göra | listan i §4 | – |

## 2. Vad arkivet visar (iOS build 44690826764, e6b19b3a)
- **Version:** `Lumen.app` 1.0.0, build 44690826764. `LumenControls.appex` samma. Arkivet säger vilken commit det är.
- **Exportsvaret:** false. Kontrollerat i koden: ingen egen kryptering. Appen använder HTTPS genom systemet,
  SHA-256 som kontrollsumma på två ställen (`DrillServices.swift:624`, `Purchases.swift:277`) och Apples App Attest.
- **Entitlements per konfiguration** (inget signeras här; de läggs på när arkivet signeras):
  | Konfiguration | Fil | Appgrupp | App Attest |
  |---|---|---|---|
  | Debug | `Entitlements/Lumen.entitlements` | `group.com.rsolutions.lumen` | inte satt (Apples sandlåda under utveckling) |
  | Beta | `Entitlements/Lumen.entitlements` | samma | inte satt |
  | **Release** | `Entitlements/Lumen-Release.entitlements` | samma | **production** |
  | Widgeten (Release) | `Entitlements/LumenControls.entitlements` | samma | – |
- **Ikonen:** källfilen är 1024 × 1024 utan genomskinlighet. Appen har en ikon i ett format (Xcodes enda-storlek):
  den kompilerade katalogen har 1024 × 1024 för telefon och platta, och systemet gör de mindre storlekarna ur den.
  I appen ligger också `AppIcon60x60@2x.png` och `AppIcon76x76@2x~ipad.png`, och `Info.plist` pekar ut `AppIcon`.
  Det är alltså inte en fil per storlek, och det behövs inte längre. **Att App Store Connect godtar ikonen är oprövat.**
- **Båda `PrivacyInfo.xcprivacy`** finns i arkivet (appen och widgeten).
- **Inga testkrokar:** nio märken söktes (testlägets adress och typer, `LUMEN_TEST_HEADER`, `LUMEN_TEST_PRESSES`,
  `LUMEN_TEST_MATERIAL`, `earmind.test.press`, `LumenScreenshot`). Alla finns i Debug-bygget (kontrollen) och
  **0** i Release-arkivet.
- **Inget som bara hör till Debug** (`UIFileSharingEnabled`) finns i Release.
- **Tester:** `A155ReleaseReadinessTests` (exportsvaret, versionen) gick igenom.

## 3. Val och avvikelser
- **Rättigheten ligger bara i Release.** A141 bestämde att App Attest-rättigheten inte läggs in utan Arons ja,
  eftersom en rättighet som Sideloadly inte kan signera för kan stoppa installationen. Bygget Sideloadly installerar är
  Debug, så det är orört. D245 säger Release, och det är det enda som ändrats. Bygget faller om Debug eller Beta får den.
- **Enligt Apples dokumentation** struntar en app som delas ut genom TestFlight eller App Store i värdet och använder
  alltid produktion. Raden gör det uttryckligt och skadar inte. *Läst i Apples dokumentation 2026-11-19.*
- **Byggnumret är körningens id** (som i Sideloadly-bygget och i Om appen), inte ett eget löpnummer: det är högre för
  varje körning och säger vilket bygge det är.
- **Spotify:** arkivet i CI byggs utan `SPOTIFY_CLIENT_ID`. Det riktiga inskickningsbygget ska ha det (står i §4).

## 4. Det som återstår och som bara Aron kan göra
1. **Apple Developer Program** (99 USD per år), om kontot inte redan är med.
2. **Team ID** (10 tecken, developer.apple.com › Membership):
   - i appen: `DEVELOPMENT_TEAM` i `project.yml` (står tomt i repot) eller som hemlighet i GitHub för bygget;
   - hos Kevin: `APPLE_TEAM_ID` i Supabase, annars svarar servern 503 på välkomstkrediterna.
3. **Två App ID:n** (Certificates, Identifiers & Profiles › Identifiers):
   - `com.rsolutions.lumen` med **App Groups** (`group.com.rsolutions.lumen`), **App Attest**, och **MusicKit** om
     Apple Music ska fungera;
   - `com.rsolutions.lumen.controls` med **App Groups** (samma grupp).
   - Appgruppen `group.com.rsolutions.lumen` ska finnas.
4. **Signering:** ett distributionscertifikat och profiler för båda, antingen i Xcode på en Mac eller i bygget med en
   **App Store Connect API-nyckel** (nyckel-id, utfärdar-id och .p8-filen som hemligheter i GitHub). Säg vilket, så
   bygger jag steget som signerar, exporterar och laddar upp. Det finns inte i dag.
5. **Appen i App Store Connect:** ny app med bundle-id `com.rsolutions.lumen`, namn, primärt språk svenska.
6. **Köpen** med exakt de här id:na (de står i appen, `StoreCatalog`): `com.rsolutions.lumen.credits.100`,
   `.credits.500`, `.credits.2000` (förbrukningsvaror) och `com.rsolutions.lumen.sub.week` (veckokortet,
   prenumeration). Priser enligt D224. De skickas in tillsammans med version 1.0.0.
7. **Formulären:** App Privacy (Kellys tabell, Ke84), integritetspolicyns adress (TILL-ARON #30), åldersgräns,
   granskningsanteckningarna (granskning.md §3) och skärmbilderna (Ke80, TILL-ARON #27).
8. **`SPOTIFY_CLIENT_ID`** som hemlighet, om Spotify ska vara med i 1.0.
9. **Beslut som väntar** (inte tekniska): frågeloggen i repetitionsläget utan samtycke (A152), och att första provet
   kostar mer än ett nytt konto har utan välkomstkrediterna (T55, O90).
10. **Ladda upp och skicka till granskning.** Inget av det görs av en session.

## 5. Oscars O90: välkomstkrediterna tog slut för gott
- **Felet:** servern svarade 503 `attest_unconfigured` på välkomstanropet (Team ID saknas hos Kevin), och appen
  räknade det som ett misslyckat försök. Efter tre starter frågade appen aldrig mer, inte heller när Team ID var satt.
  Det hade träffat granskaren, Aron och TestFlight-testarna.
- **Rättat:** bara ett riktigt nej från servern (4xx) räknas. Ett serverfel eller inget nät frågas om vid nästa start,
  hur många gånger som helst. Räknaren har fått nytt namn, så redan förbrukade försök är glömda.
- **Tester:** `aServerThatIsNotSetUpYetNeverUsesUpTheTries` och `aRealNoStillEndsAfterThreeTries`, gröna.
- **Inte provat på enhet:** App Attest finns inte i Simulatorn.
- Oscars andra rad (visa vad provet kostar före "Gör prov") har Kevin tagit på servern (K110: nej före provet görs).
  Appen visar serverns ord; en egen uppskattning i appen har jag inte byggt.

## 6. Kända begränsningar
- Arkivet är osignerat. Att rättigheterna godtas av en profil, att App Attest svarar i produktion och att
  App Store Connect tar emot bygget visar sig först när Aron har gjort §4 punkt 1–4.
- `xcodebuild archive` i Release tar ungefär lika lång tid som bygget det ersatte; inget steg har lagts till som
  bygger en gång till.

## 7. Nästa steg
- Aron: §4. Säg hur signeringen ska gå till (Mac eller API-nyckel i bygget).
- Jag: steget som signerar och laddar upp, när nyckeln eller Team ID finns.

## Tillägg 08:25
Beslutet heter D245 sedan Deangelo numrerade om det (förut D243). Kommentarerna i koden och i `ios-build.yml` säger
fortfarande D243; de rättas nästa gång filerna ändras.

## Tillägg 08:56: main är grönt
iOS build 44694689538 på main (9e8fd220) är grön: Release-arkivet, steget "Release archive is ready to submit (A155)",
båda A152-stegen och alla enhetstester. **Verifierat i CI.**

