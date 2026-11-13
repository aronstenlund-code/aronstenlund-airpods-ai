# Angela Fable: A87 Apple-stil i repetitionsläget, A90 kontrolltexten, Apple-stil på A83 och A84

Datum: 2026-11-14 00:35. Roll: Angela Fable (andra appbyggaren, Fable 5.2). Uppdrag: A87 (D160, Kellys Ke53), vyn i
A90 (Aron 23:13), och Arons tillägg 23:37: samma stil på Publicera prov, Prov från din skola, röstvalet och tempo.

**Inget är provat på telefon eller med AirPods.** Allt nedan är Simulatorbilder från CI och kodläsning.

## Först: K48 och K45 kördes inte
Sessionens första rad bad om flödet "Voice blind test (K48)" och sedan K45. Båda var redan klara: flödet kördes
2026-11-13 20:26 (commit 801b84a), A/B/C och FACIT ligger i `docs/rost-blindtest/`, och K48 och K45 är avbockade i
`prompts/queue/kevin.md`. En omkörning hade dragit cirka 1 500 ElevenLabs-tecken till (D146: högst 3 000) och blandat
om A/B/C mot facit. Jag körde därför inte om det. **Verifierat i repot.**

## Vad som är byggt
Alla skärmar i repetitionsflödet använder nu bara systemets delar: SF Pro med textstilar, systemfärger,
`List`/`Form`, `.borderedProminent` för den enda huvudknappen och `.bordered` eller textknappar för resten.
Inga `LumenFont`, `LumenColor`, `LumenButtonStyle`, `lumenScreen`, `lumenForm` eller `.scrollContentBackground(.hidden)`
finns kvar i de här filerna (utom `BetaBadge` och `BetaModesHeader`, som används av de lyssnande lägena).

| Kellys punkt | Vad | Fil |
|---|---|---|
| 1 | Huvudknappen fast nederst (`MainActionBar` i `.safeAreaInset(edge: .bottom)`): Starta prov, Skapa frågor, Ser rätt ut, kontrollskärmens Starta prov, Publicera prov, Lägg till i mina prov. En rad under knappen säger varför den är grå. | `DrillView`, `NewDrillView`, `ControlCheckView`, `PublishViews` |
| 2 | Hem: `ContentUnavailableView` utan prov, en `List` med prov, navigationsrad "Prov" med inställningar, Nytt prov och Öppna länk i nedre raden. Tipsrutan, Starta Earmind och Earmind kan allt ligger bakom raden Fler lägen. Sviten visas som texten "3 dagar i rad". | `HomeView` (repetitionsdelen), `RepetitionHomeSection` |
| 3–5 | SF Pro med textstilar, systemknappar, systemfärger och systemets listbakgrund, **bara i repetitionsflödet**. Resten av appen står i Angela Schrutes kö. | de fem vyerna |
| 6 | Nytt prov som `Form`: materialet som fyra rader med symbol, `Stepper`, årskursen (A88) och raden under den grå knappen (N3). "Långa svar" är borta (A89). | `NewDrillView` |
| 7 | Frågelistan: Dela och en ⋯-meny uppe till höger (Börja om, Publicera prov, Ändra ordning, Ta bort provet med `.confirmationDialog`), Sammanfattning som egen sektion. | `DrillView` |
| 8 | Ingen dialog "Fortsätt där du var?". Knappen säger Fortsätt och raden "Du var på fråga 3 av 5". `ResumeSheet` är borttagen. | `RepetitionHomeSection`, `DrillView` |
| 9 | Kontrollskärmen som en introduktion: bild med prickarna, rubrik, en rad, tre steg, Starta prov nederst, Hoppa över under, haptik när ett tryck kommer fram. | `ControlCheckView` |
| 10 | Uppspelningen: "Fråga 2 av 5" och provets namn på en rad, förloppslinje, ringen i textfärg, N1-raden första varvet, Avsluta `.bordered`. | `RepetitionPlayerView` |
| 12 | Redigera en fråga som `Form` med det korta svaret i fotnoten. | `DrillView` (`DrillItemEditor`) |
| 11 | **Inte gjord:** BETA-märkena i Välj läge ligger i `ListeningScreen` (Angela Schrutes fil, i hennes kö). | – |

**A90:** kontrollskärmen har Arons mening ordagrant, en mening per rad under "Medan frågan spelas:" ("tryck 1 gång
för frågans A-svar." med litet t, Kellys K1).

**A83 och A84 (Arons tillägg):** Publicera prov och ett publicerat prov har huvudknappen fast nederst, förklaringen
är sektionens fotnot, Prov från din skola har systemets tomläge, röstvalet har samma ▶ som Hem, och Tempo och Längd på
långa svar står i systemets textstil. Resten av Inställningar har kvar det gamla utseendet (`lumenForm`, Angela
Schrutes kö).

## Tekniska beslut (D168 i `docs/DECISIONS.md`)
- **Dela:** länken görs först när man trycker på Dela (K47 skapar en delning på servern), så verktygsradens knapp gör
  länken och öppnar sedan systemets delningsblad (`UIActivityViewController`). En `ShareLink` kräver länken i förväg.
- **Starta prov på Hem** öppnar kontrollskärmen direkt första gången, i stället för att gå via provets skärm (ett tryck
  mindre för en ny användare).
- **Bottenraden slutar växa vid första tillgänglighetsstorleken** (`.dynamicTypeSize(...accessibility1)`), som
  systemets egna rader. Med största text tog den annars halva skärmen på iPhone SE.
- **Stora rubriker kapas inte** (Kelly, SYSTEM §10 regel 4): med tillgänglighetsstorlekarna är navigationsrubriken
  inline och rubriken första raden i listan.
- **I en knapps etikett är `.primary` accentfärgen.** Rader som ska ha textfärg använder `Color.primary`.

## Test
| Vad | Resultat | Status |
|---|---|---|
| Kompilering, enhet (iOS build 43519409691, 3382ae2) | Steget "Build app for iOS device" gick igenom; körningen avbröts i enhetstesterna av en senare push | verifierat i CI, **inget helt grönt bygge** |
| Kompilering, Simulator (Simulator screenshots, 3382ae2, 06dd6c7, 9d3ce32) | Gick igenom i fem körningar | verifierat i CI |
| iPhone 17 Pro, ljust och mörkt, alla scener (43519509067, 3382ae2) | Granskad av mig och av Kelly: A87 godkänd med K1–K5 | Simulatorn |
| iPhone SE, ljust och mörkt (43519515040, 3382ae2) | Granskad av mig och av Kelly | Simulatorn |
| iPhone 17 Pro, rep* efter rättningar (43524695222, 9d3ce32) | K2, K3, K5 stängda på bild; A83 och A84 godkända av Kelly med P1 (medel) och P2 (låg) | Simulatorn |
| Största text, 17 Pro och SE (43521636730, 43521643151, 06dd6c7) | Fem fel hittade och rättade i 76e293f och 84889b9 | Simulatorn, **rättningarna inte bekräftade på bild** |
| Enhetstester (LumenTests) | Har inte hunnit gå klart på någon commit med A87 | **inte kört** |
| iPhone och AirPods | – | **inte provat** |

Kontaktblad: `reports/2026-11-14-a87-bilder/`.

## Kellys fynd
- K1 (litet t), K2 (Nytt prov med text), K3 (rader i textfärg), K5 (felet syns i Nytt prov): rättade, K2/K3/K5 stängda på bild.
- K4 (repShare med ljud som görs): rättad av Angela Schrute i scenens data, **inte bekräftad på bild**.
- Pausraden: "Fortsätter från början av meningen" (D164), pushad i 3c0757e.
- **P1 (medel), öppen:** ett publicerat prov ska visa de fyra första frågorna före Lägg till i mina prov. Servern
  skickar bara antalet frågor, så det behövs fält från K49 (Kevin) och i modellen (Angela Schrute). Står i hennes kö.
- **P2 (låg), öppen:** Röst A/B/C behöver en beskrivning när Aron har namngett dem.

## Kända begränsningar och risker
- **Ingen enhetsverifiering.** Haptiken på kontrollskärmen, delningsbladet, rullningen i uppspelningen och hur
  bottenraden beter sig med tangentbordet uppe är otestade antaganden.
- Uppspelningen ligger nu i en `ScrollView`. Trycket "var som helst fortsätter" under paus ligger kvar på hela
  skärmen, men är **inte provat** tillsammans med rullningen.
- Starta prov direkt efter att kontrollskärmens blad stängs (från Hem) följer samma mönster som provets skärm hade
  förut, utan fördröjning. Otestat antagande att uppspelningen alltid öppnas.
- Avstängda huvudknappar är mycket ljusa i iOS 26 (systemets utseende). Raden under säger varför.
- Tobys E2E: raden heter fortfarande "Fler lägen" och kugghjulet "Inställningar", men Start har inte längre
  "Starta Earmind" (den ligger bakom Fler lägen sedan B2). Inte kört efter A87.

## Kvar
1. Ett helt grönt iOS build (84889b9 eller senare) och bilder i största text efter rättningarna (43528102988, 43528108671).
2. Kellys granskning av SE och största text.
3. Tobys förstagångstest (klart-kravet i A87).
4. P1 när fälten finns. A92 (hjälp-AI:ns vy, Kellys Ke57) står på Angela Fable i kön.
5. Kellys Ke55 (första starten) är inte tilldelad: den ligger i `Features/Onboarding`.

## Nästa session
Läs den här rapporten och Kellys `reports/2026-11-14-0010-kelly-granskning-a87.md` och
`reports/2026-11-14-0033-kelly-granskning-a83-a84.md`. Kontrollera bygget och bilderna ovan, rätta det Kelly hittar i
största text, och ta sedan A92.
