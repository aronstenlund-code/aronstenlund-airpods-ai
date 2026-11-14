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

## Tillägg 2026-11-14 02:33: största text, A92 och bygget
**Fortfarande inget provat på telefon.** Allt är Simulatorbilder från CI och kodläsning.

### Största text (Kellys `reports/2026-11-14-0100-kelly-granskning-storsta-text.md`)
| Fynd | Åtgärd | Läge |
|---|---|---|
| Egna (06dd6c7): knapptext bröts mitt i ordet, bottenraden tog halva skärmen, uppspelningen kapade texten, Nytt prov i tomläget under nedre raden, rubriker kapades | 76e293f, 84889b9 | Kelly: rubriker, avstavning, formulär och fasta huvudknappar håller (43528102988, 43528108671) |
| S1 (hög): ord bryts utan bindestreck bredvid BETA i Välj läge | Angela Schrutes fil; hon har tagit bort märkena från raderna | inte sett på bild av mig |
| S2 (hög): uppspelningen på iPhone SE kapade frågan och dolde "Tryck på AirPods för svaret" | bfed93d: egen layout utan rullning vid tillgänglighetsstorlekar. Första raden "Fråga 1 av 5 · 6 s" (eller "· Pausad"), frågan som krymper till platsen, en rad om vad man gör, Avsluta. Tryckprickarna och svarstexten visas inte där | **bekräftat av mig på bild** (43531494112, iPhone SE) |
| S3 (medel): Hems nedre rad flöt över texten | `.toolbarBackground` hjälpte inte i iOS 26 (43531494112). 8684b6d: en fast rad med material och skiljelinje (`safeAreaInset`), Öppna länk i en ⋯-meny vid tillgänglighetsstorlekar | **inte bekräftat på bild** (43541166865 går) |
| S4, S5 (låg): innehåll skymdes av den fasta knappraden utan att det syntes | bfed93d: material och skiljelinje på raden | bekräftat av mig på bild (43531494112) |
| P3 (låg): Fler lägen halvt under nedre raden på SE | 3e8597e, ersatt av S3-lösningen i 8684b6d | inte bekräftat på bild |

### A92: Fråga om Earmind (D166, Kellys Ke57)
Ny fil `Lumen/Features/Repetition/HelpChatView.swift`: bladet med Klar, en rad om vad det är, tre förslag som rader,
"Prova på en kort text", bubblor som i Meddelanden (frågan till höger i accentfärg, svaret till vänster, helt på en
gång), inmatningsfält nederst. `HelpTryView`: en textruta, raden om kvoten, de tre frågorna med korta svar, **Gör
frågor** och sedan **Spara som prov** fast nederst, Gör om som textknapp. ?-knappen (`questionmark.circle`) finns i
Nytt prov ("Vad kan jag fota?") och på kontrollskärmen ("Hur fungerar trycken?"; kontrollen börjar om när hjälpen
stängs). Logiken (`HelpAnswering`, `HelpClient`, `MockHelp`), raden i Inställningar och scenerna är Angela Schrutes.
- **Kompilerar** i Simulatorbygget (43531494112, bfed93d) och i enhetsbygget (43531800983).
- **Inte sett på bild** (scenerna `repHelp`, `repHelpAnswer`, `repHelpTry` kom efter bfed93d).
- Länken i ett svar ("Öppna Styr med dina AirPods") visas bara när anroparen skickar `onOpen`. Från ?-knapparna gör
  jag inte det än: navigeringen dit är Angela Schrutes.
- **Otestat antagande:** att returtangenten skickar frågan från ett flerradigt fält, och hur fältet beter sig med
  tangentbordet uppe.

### Bygget
| Körning | Commit | Resultat |
|---|---|---|
| 43524914328 | 3c0757e | Enhetsbygget gick igenom. Enhetstesterna föll i lyssnande kod (`ScribeRetryTests`, `CalibrationFlowTests`), rättat av Angela Schrute i 868a77d |
| 43528101357 | 84889b9 | Samma två testsviter |
| 43531800983 | 5623c65 | Enhetsbygget gick igenom. **Ett test rött:** `A92HelpTests.outsideTheAppIsSaidWithTheHint`. `MockHelp` letar efter "väder", testet frågar "Hur blir vädret?". Angela Schrutes fil; står i hennes kö (punkt 6) |
| 43541165315 | 8684b6d | Går. Faller på samma test |
| (nästa) | fdc5dea | Angela Schrute har rättat `MockHelp` ("väd"). Bygget på fdc5dea eller senare avgör |

**Det finns alltså inget grönt iOS build med A87 än.** Testet är rättat av Angela Schrute i fdc5dea; nästa bygge
visar om allt är grönt.

### Kvar, uppdaterat
1. Grönt iOS build (fdc5dea eller senare).
2. Bekräfta S3 och A92 på bild (43541166865 SE största text, 43541171376 SE, 43541178241 17 Pro, alla 8684b6d), och Kellys granskning av dem.
3. Kellys P1 (fält från K49) och P2 (röstnamn från Aron).
4. Tobys förstagångstest.
5. Kellys Ke55 (första starten) är inte tilldelad.

## Tillägg 2026-11-14 03:12: grönt bygge, Kellys slutgranskning
**Fortfarande inget provat på telefon eller med AirPods.**

- **iOS build 43541273166 (fdc5dea) är grönt**, med `Lumen-unsigned` (ipa) uppladdad. Det innehåller A87, A90,
  Apple-stilen på A83/A84, A92:s vy och rättningarna för största text till och med 8684b6d. Verifierat i CI.
- Efter fdc5dea har jag pushat ab5f6de (hjälpfältet i största text) och 7e9b749 (Kellys R1). De kompilerar i
  Simulatorbygget (43543419772, 43543423666). iOS build för dem (43543518435, 662d863) går när det här skrivs:
  **inte grönt än**.
- **Kelly (`reports/2026-11-14-0255-kelly-granskning-8684b6d.md` och b0e186b):** A92 godkänd på bild. Stängda på
  bild: S2, S3 (fast nedre rad på Hem), S4/S5, S1, P3, K4, pausraden, R1 (förloppslinjen under texten) och H2
  (hjälpfältets platshållare). Kvar hos henne att bekräfta: H1 (scenen `repHelpTry`) och S1b (Välj läge), båda
  rättade av Angela Schrute och inte på bild än.
- S3 och A92 har jag själv sett på bild (43541166865 iPhone SE största text, 43541171376 iPhone SE, 43541178241
  iPhone 17 Pro). Kontaktblad: `reports/2026-11-14-a87-bilder/`.

### Kvar efter A87
1. Tobys förstagångstest: en ny användare ska hitta nästa steg på varje skärm (klart-kravet i A87 som är Tobys).
2. Kellys P1 (förhandsvisning av ett publicerat prov, fält från K49) och P2 (namn på rösterna, Aron).
3. Resten av appen i samma stil (Angela Schrutes kö, punkt 1 i min lista där).
4. Länkarna i hjälp-AI:ns svar från ?-knapparna (navigeringen är Angela Schrutes).
5. Enhetstest: haptiken på kontrollskärmen, delningsbladet, bottenraden med tangentbordet uppe, uppspelningen i
   största text, och att uppspelningen öppnas direkt efter kontrollskärmen från Hem.
6. Kellys Ke55 (första starten) är inte tilldelad.
