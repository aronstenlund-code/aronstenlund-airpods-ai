# Kelly Ke53: Apple-stil och "var trycker jag?" (D160), lista till Angela (A87)

Datum: 2026-11-13 23:00. Roll: Kelly Kapoor (design). Uppdrag: `prompts/queue/kelly.md` Ke53. Skills: apple-design
(Apples principer: förtrogenhet, enkelhet, vägvisning, en tydlig hierarki) och emil-design-eng (små detaljer,
feedback vid tryck och bara animationer med ett syfte).

## Underlag
- **Före:** appens skärmbilder från CI "Simulator screenshots" 43508671912 (kod 4623bc7, efter iOS-bygget 43505582385,
  som saknar bilder) och kodläsning av main (0eaad6f). En ny körning (43514517449, fded759 med B1/B2 och A85/A86)
  pågick när rapporten skrevs. Jag bekräftar den i en egen rad i STATUS när den är klar.
- **Jämfört med:** Apples Anteckningar, Påminnelser, Podcaster, Inställningar och AirPods-parkopplingen, samt Human
  Interface Guidelines (navigation, listor, blad, knappar, tomma lägen, typsnitt och färger). Jämförelsen bygger på
  vad jag vet om apparna och HIG, och är **ej kontrollerad mot iOS 26 på en telefon i dag**.
- **Efter:** 7 skisser i ljust och mörkt, `docs/design/bilder/apple/` (källa `docs/design/_src/apple.html`).
  Typsnittet i skisserna är Windows systemtypsnitt. I appen är det SF Pro.
- **Reglerna:** `docs/design/SYSTEM.md` avsnitt 0 (nytt, gäller före resten).

## Det som får appen att se generisk ut i dag
1. **Egna typsnitt och storlekar** (Familjen Grotesk med fasta punkter) i stället för SF Pro och textstilar.
2. **Egna knappar** (`LumenButtonStyle`): samma form för alla slag, och grå knappar som ser tryckbara ut.
3. **Tonade rutor och kort i kort:** "Här startar du Earmind", "Earmind kan allt" i en brunn, NÄSTA PROV-kortet med
   egen bakgrund och kontrollskärmens blå ruta.
4. **Listor utan systemets bakgrund** (`.scrollContentBackground(.hidden)` i `DrillView`, `MyAnswersView` och
   `Theme.lumenForm`). Därför ser listorna inte ut som iOS.
5. **Emblem utan förklaring:** flamman "3" och BETA-märken på varje rad.
6. **Dialoger appen inte behöver:** "Fortsätt där du var?".
7. **Huvudknappar som rullar bort:** Starta prov överst i frågelistan och Skapa frågor under formuläret.

## Skärm för skärm
| Skärm (scen) | Nästa steg i dag | Det som är generiskt | Så ska det se ut (skiss) |
|---|---|---|---|
| **Hem utan prov** (`repHomeEmpty`) | Nytt prov, men under det står sju andra saker | Tonat kort runt tomläget, tipsruta, en stor ramad "Starta Earmind", "Earmind kan allt" i en brunn och flamman | `ContentUnavailableView`: symbol, "Kom förberedd till provet", en mening, **Nytt prov** (fylld) och textknappen "Hitta prov från din skola". Fler lägen ligger som en rad nederst. Rubriken heter **Prov**, och inställningarna är en symbol uppe till höger. (`apple/hem-tom.png`) |
| **Hem med prov** (`repHome`) | Starta prov (bra), men "Nytt prov" är en lika stor knapp under | NÄSTA PROV-kort med egen bakgrund, flamman och "Har du fått ett prov? Klistra in länken" som löptext | En `List`: första sektionen är nästa prov (titel, "Nästa prov · om 5 dagar" i `.footnote`) med **Starta prov** (fylld, full bredd). ANDRA PROV som rader med `play.circle.fill`. "Prov från din skola" som rad. **Nytt prov** nere till vänster i verktygsraden, med text, som Påminnelser. Klistra in en länk ligger i `+`-menyn. Flamman visas först efter första passet, med texten "3 dagar i rad". (`apple/hem.png`) |
| **Nytt prov** (`repMaterial`) | Skapa frågor, grå utan förklaring och längst ner i rullningen | Rutnät av fyra kort, egen stepper, egen segmentväljare och namnfält i en egen ruta | `Form` i ett blad med Avbryt. Sektioner: namn (`TextField`), MATERIAL (fyra rader med symbol: Fota sidor, Välj bilder, Skriv text, Lägg till dokument), de tillagda som miniatyrer i en rad, FRÅGOR (`Stepper` "Antal frågor", segmenterad `Picker` "Långa svar"). **Skapa frågor** fast nederst, med raden "Lägg till minst en sida, bild eller text." när den är grå. (`apple/nytt.png`) |
| **Läser materialet** | Ingen (väntan) | – | `ProgressView` med de fyra stegen som en lista med bockar. Avbryt uppe till vänster. Inget eget mer. |
| **Stämmer det här?** | Ser rätt ut, längst ner | Egna rubriker | `Form`: `LabeledContent` Ämne och Årskurs, "Provet handlar om" som text, `TextField` "Något fel? Skriv det". **Ser rätt ut** fast nederst. |
| **Frågelistan** (`repList`) | Starta prov, men den rullar bort när provet har 20 frågor | Egen bakgrund på listan, "Sammanfattning" som löptext och Ändra ensam uppe till höger | `List` med stor rubrik och raden "5 frågor · åk 9 · ljud klart". Frågor som rader (nummer, fråga i `.body.weight(.semibold)`, kort svar i `.subheadline`), sist "Lägg till fråga". Uppe till höger `ShareLink` och en `⋯`-meny (Publicera prov, Ändra ordning, Ta bort provet). **Starta prov** fast nederst med raden "Spelas i dina AirPods. Mikrofonen används inte." (`apple/fragor.png`) |
| **Redigera en fråga** (`repEdit`) | Spara (rätt) | Egna fältrutor och en tonad bricka för det korta svaret | `Form`: Section "Fråga" (`TextField`), Section "Svar" (`TextField(axis: .vertical)`), där sektionens fotnot visar det korta svaret: "Kort svar (2 tryck): Klorofyll fångar …". "Nytt förslag" som textknapp. Avbryt och Spara som i dag. |
| **Styr med dina AirPods** (`repControls`) | Starta prov (grå tills klart), Hoppa över uppe till höger | Blå ruta runt instruktionen och tre rader i grått utan struktur | Som AirPods-parkopplingen och Face ID: en rund bild med prickarna, rubriken "Tryck två gånger", en rad under (N2), och en lista med tre steg (bock, snurra, tom ring). **Starta prov** nederst och **Hoppa över** som textknapp under, inte uppe i hörnet. `.sensoryFeedback(.success)` när ett tryck kom fram. (`apple/kontroller.png`) |
| **Uppspelning** (`repPlayThink`, `repPlayAnswer`) | Inget att trycka på telefonen (rätt) | Brickan "Biologiprovet" ovanför frågan och en stapel med ett streck per fråga | Som Spelas nu i Podcaster: överst "Fråga 2 av 5" och provets namn på samma rad, en tunn förloppslinje, frågan i `.largeTitle.bold()`, ringen i `.primary` (inte blå) och första varvet "Tryck på AirPods för svaret" (N1). Avsluta som `.bordered` `.large`, full bredd. (`apple/spelar.png`) |
| **Pausad** (`repPaused`) | Tryck på AirPods | – | Behåll. Byt den grå cirkeln mot SF Symbol `pause.circle.fill` i `.secondary`. |
| **Fortsätt där du var?** (`repResume`) | En dialog med tre val | En dialog som frågar något appen kan avgöra själv | **Ta bort dialogen.** Nästa prov på Hem säger "Du var på fråga 3 av 5", med en tunn förloppslinje, och knappen heter **Fortsätt**. "Börja om" finns i `⋯`-menyn på provet. (`apple/fortsatt.png`) |
| **Dela** (`repShare`, `repShareReady`) | Dela-raden | – | `ShareLink` uppe till höger i frågelistan. Medan ljudet görs är den avstängd, och fotnoten i listan säger "Delas när ljudet är klart (36 av 40)". |
| **Välj läge / Fler lägen** (`moreModes`) | Klar | BETA-märke på varje rad och lång fotnot | `List` med rubriken "Lyssnande lägen" och en fotnot för hela sektionen: "Beta. Lägena använder mikrofonen. Starta prov gör det aldrig." Inga märken per rad. Provläge får raden "Förhör med rösten" (N4). |
| **Publicera prov** (A83, inte byggd) | Publicera prov | – | `docs/design/publicera-prov.md` följer redan reglerna. Bygg den med `Form`, `NavigationLink` till en `.searchable`-lista för skola, `Picker` ämne, `DatePicker` och `Toggle`. |

## Prioriterad lista till Angela (A87)
Ordningen är vad en ny användare märker först. Varje punkt kan byggas och skärmbildas för sig.

| # | Vad | Var | Klart när |
|---|---|---|---|
| **1** | **Nästa steg alltid synligt:** Starta prov, Skapa frågor, Ser rätt ut och kontrollskärmens Starta prov ligger fast nederst (`.safeAreaInset(edge: .bottom)`). | `DrillView`, `NewDrillView`, `ControlCheckView` | Knappen syns på iPhone SE med 20 frågor och med största text |
| **2** | **Hem som systemets lista och tomläge**: `ContentUnavailableView` utan prov, en `List` med prov. Bort med tipsrutan, "Starta Earmind" och "Earmind kan allt" (de ligger bakom Fler lägen). Nytt prov flyttas till verktygsraden nederst. Flamman visas först efter första passet. | `HomeView`, `RepetitionHomeSection` | `repHomeEmpty` har exakt en fylld knapp och inga rutor |
| **3** | **Typsnitt:** SF Pro med textstilar (SYSTEM §0.2). Byt `LumenFont.text` till systemets textstilar på ett ställe. | `Shared/LumenStyle.swift` och sedan där storlekar anges | Inga `Familjen Grotesk` i appen. Största text bryter inga ord (SYSTEM §10) |
| **4** | **Systemknappar:** huvudknappen `.borderedProminent` + `.controlSize(.large)`, övriga `.bordered` eller textknappar. `LumenButtonStyle` tas bort. | Hela repetitionsflödet först, sedan resten | Exakt en fylld knapp per skärm |
| **5** | **Systemfärger och listor:** semantiska färger (SYSTEM §0.3) och AccentColor = blå. Ta bort `.scrollContentBackground(.hidden)` så att listorna får iOS-bakgrunden. | `Theme.swift`, `DrillView`, `MyAnswersView` | Listorna ser ut som Inställningar i ljust och mörkt |
| **6** | **Nytt prov som `Form`** med materialet som rader, `Stepper` och segmenterad `Picker`. Raden under den grå knappen (N3). | `NewDrillView` | `apple/nytt.png` |
| **7** | **Frågelistan:** `ShareLink` och en `⋯`-meny uppe till höger. Sammanfattningen blir en egen sektion. | `DrillView` | `apple/fragor.png` |
| **8** | **Fortsätt utan dialog:** knappen på Hem säger "Fortsätt" och "Du var på fråga 3 av 5". Börja om ligger i menyn. | `RepetitionOverlay`, `RepetitionHomeSection` | Ingen dialog när appen öppnas |
| **9** | **Kontrollskärmen som en introduktion:** bild, rubrik, en rad, lista med tre steg, Starta prov nederst, Hoppa över under och haptik när ett tryck kommer fram. | `ControlCheckView` | `apple/kontroller.png` |
| **10** | **Uppspelningen:** brickan bort, förloppslinje, ringen i `.primary`, N1-raden första varvet och Avsluta `.bordered`. | `RepetitionPlayerView` | `apple/spelar.png` |
| **11** | **Fler lägen:** en fotnot i stället för BETA på varje rad, och Provläge → "Förhör med rösten" (N4). | `ListeningScreen` (Välj läge) | `moreModes` |
| **12** | **Redigera som `Form`**, med det korta svaret i fotnoten. | `DrillView` (redigeringen) | `repEdit` |

Skärmbilder till mig: ljust, mörkt, iPhone SE och största text för `repHomeEmpty`, `repHome`, `repMaterial`,
`repList`, `repControls` och `repPlayThink` (A87 i kön).

## Demosidan
Efter appen (D160). När A87 punkt 2–5 är byggda gör jag sajten i samma stil: systemtypsnitt (`-apple-system`), samma
färger och en knapp per avsnitt. Utkastet i `drafts/site-repetition/` görs om då.

## Test
Bara skisser och kodläsning. Inget är byggt och inget är provat på telefon. Apples appar och HIG är jämförda utifrån
vad jag vet, **ej kontrollerat mot iOS 26 på telefon**.
