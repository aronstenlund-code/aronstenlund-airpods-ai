# A161 (D259, D261): lanseringsrabatt 65 % i en vecka

Angela Fable (moln), 2026-11-23–24. Beställt av Deangelo 19:51 (Aron 19:36), tillägg 20:55 (veckokortet). iOS-appen
på main.

## Vad som är gjort

1. **Lanseringsprodukterna** `com.rsolutions.lumen.credits.100.launch`, `.500.launch` och `.2000.launch` finns i
   appen (`StoreCatalog.launchIDs`) och i StoreKit-testkonfigurationen (`StoreKit/Lumen.storekit`: 3,50, 13,65 och
   38,50 kr = 35 % av 10, 39 och 110 kr). De ger samma krediter som de ordinarie paketen (Kevins K119).
2. **Under veckan** visar butiken (Krediter → Fyll på) lanseringspaketen: överst en rad "Lanseringsrabatt -65 %"
   med nedräkning ("Slutar om 2 dagar 4 tim"), och på varje paket lanseringspriset på knappen med ordinarie pris
   överstruket under paketets namn. Utanför veckan är butiken som i dag.
   **Veckokortet (tillägget):** samma produkt med sitt introduktionspris i App Store (första veckan, 27,65 kr i
   testkonfigurationen): knappen visar första veckans pris, raden säger "Första veckan 27,65 kr, sedan 79,00 kr i
   veckan", och Apples fotnot (3.1.2) säger båda priserna. Har Apple-kontot redan haft veckokortet ger App Store
   inget introduktionspris, och kortet visas då som vanligt.
3. **Ett blad när appen öppnas** under veckan: "-65 %", "Lanseringsrabatt", en rad om vad det gäller, nedräkning,
   knappen "Se paketen" (öppnar butiken) och "Inte nu". Halvt blad, stängs med ett tryck eller en dragning.
   **Högst en gång per dag**, och aldrig ovanpå ett annat blad.
4. **Servern styr veckan** (K119: `GET /purchase` → `launch_offer` med start, slut och procent, utan inloggning).
   Appen frågar när den öppnas och kommer fram (högst var 15:e minut) och när butiken öppnas.
5. **Inget utlovas som inte finns:** rabatten och bladet visas bara när servern säger att veckan pågår OCH App
   Store har något till lanseringspris (ett lanseringspaket eller veckokortets introduktionspris). Bladets rad
   säger det som stämmer: "65 % rabatt på allt den här veckan.", "… på alla kreditpaket …" eller "… på första
   veckan med veckokortet." Tills Aron har lagt in produkterna i App Store Connect syns alltså
   ingenting, även om veckan är startad på servern. Saknas ett enskilt paket visas det till ordinarie pris.
6. **Veckan slutar medan butiken är öppen:** från slutsekunden står de ordinarie paketen där igen. (Ett köp i
   sista minuten tas emot av servern upp till ett dygn efteråt, K119.)

## Teknik

- `Lumen/Core/Repetition/Purchases.swift`: `LaunchOffer` (läser Kevins svar), `StoreCatalog.launchIDs/isBestValue`,
  `StoreItem.regularPrice`, `StoreFront.launchItems(suffix:)`, `PurchaseServing.launchOffer()`,
  `CreditShop.loadOffer/activeOffer/packs(now:)/shouldShowLaunchSheet/launchSheetShown/launchWeekHasEnded`.
- `Lumen/Core/Repetition/LaunchOfferText.swift`: orden (procent, nedräkning, bladet, VoiceOver: "Köp 500 krediter för
  13,65 kr, ordinarie pris 39,00 kr").
- `Lumen/Features/Repetition/LaunchOfferViews.swift`: bladet och butikens rad; `ShopViews.swift`: överstruket pris;
  `RepetitionHomeSection.swift`: bladet när appen öppnas.
- Bildscener: `repShopLaunch` (butiken under veckan) och `repShopLaunchOffer` (bladet).
- Engelska och svenska i katalogen ("Launch offer", "-65%", "Ends in 2 days 4 h", "See the packs").

## Test

- **Skrivna först:** `LumenTests/A161LaunchOfferTests.swift` (13 tester) med låtsas-App Store och låtsasserver:
  serverns svar läses (pågår, null, orimlig vecka); veckan frågas efter utan inloggning; under veckan är paketen
  lanseringspaketen med ordinarie pris överstruket och samma krediter; utanför veckan som i dag; veckan slutar
  medan butiken är öppen; utan lanseringspaket i App Store utlovas inget; ett lanseringspaket köps som sig självt;
  veckokortet visar första veckans pris med det ordinarie överstruket och köps som samma produkt; ett kort utan
  introduktionspris visas som det är; bladet en gång per dag och aldrig utanför veckan; orden och nedräkningen på
  svenska och engelska.
- **iOS build 45484689536 på min gren grön i sin helhet (enhetsbygge utan varningar, alla enhetstester, App Store-arkivet)** (verifierat i CI, Simulator). Bygget innehåller A160, A161 och A163 tillsammans.
- **Bilder på svenska och engelska** (Fable screens 45491181341 och 45493032045, iPhone 17 Pro, Simulator): `reports/2026-11-23-a161-a163-bilder/a161-butiken-och-bladet-sv-en.jpg`. Bilden visar butiken som den är nu: överstruket pris under paketets namn och veckokortet med "-65 %" bredvid namnet, "Första veckan 27,65 kr, sedan 79,00 kr i veckan" och båda priserna i fotnoten.
- **Tillägg 2026-11-24 23:25:** de nya bilderna visade att veckokortets rad saknade "-65 %" (tillägget 20:55 säger att kortet visas med -65 % under veckan), så procenten står nu bredvid kortets namn. iOS build 45493033141 på min gren grön i sin helhet med den ändringen (enhetsbygge utan varningar, alla enhetstester, App Store-arkivet); main-bygget 45491059776 med A160, A161 och A163 också grönt.
- Inget köp är gjort någonstans (inte heller i sandlådan). 0 ElevenLabs (D180).

## Kända brister och risker

- **Otestat på telefon och mot App Store.** Lanseringsprodukterna finns inte i App Store Connect än (TILL-ARON 33).
- Veckokortets introduktionspris sätter Aron i App Store Connect (TILL-ARON 33). Appen visar det pris App Store
  ger; den som redan haft kortet får inget introduktionspris (Apples regel), och ser då kortet till ordinarie pris
  även under veckan.
- Introduktionspriset i App Store Connect gäller tills det tas bort där: efter veckan slutar appen visa det som
  erbjudande, men App Store ger det fortfarande till nya prenumeranter tills Aron tar bort det.
- Procenten på bladet är serverns tal; priserna är App Stores. Sätter Aron andra priser än 35 % stämmer inte "-65 %"
  med det överstrukna priset.
- Nedräkningen går efter telefonens klocka; servern avgör om ett köp ligger inom veckan.

## Farhågor

Inga. Nedräkningen och "-65 %" är sanna uppgifter från servern, bladet kommer högst en gång per dag och stängs med
ett tryck.

## Kvar / nästa session

- Arons del: produkterna och priserna i App Store Connect (TILL-ARON 33); Kevin startar veckan (K119).
- Prov i sandlådan när produkterna finns: köp av ett lanseringspaket ger rätt krediter.
