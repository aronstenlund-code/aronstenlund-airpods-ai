# A116 (D204) och A117 (D205): "+" tar material, krediterna syns (Angela Fable, moln)

Klart 2026-11-17 01:27. **Verifierat i CI och på simulatorbild, inget på enhet.** 0 ElevenLabs (D180).

## Vad som är gjort
### A116: "+" tar fil, dokument, bild och länk
- **I Säg-fältet** (`SayViews.swift`) öppnar "+" en systemmeny: Fota sidor, Välj bilder, Lägg till fil, Klistra in
  länk. Det som läses ur materialet läggs i fältet, så man ser vad som kommer att läsas upp innan man trycker Spela.
  Medan materialet läses står "Läser materialet …" i fältet; går det inte står serverns egen rad där.
- **I Nytt prov** (`NewDrillView.swift`) finns raden "Klistra in länk" under Material, bredvid Fota sidor, Välj
  bilder, Skriv text och Lägg till dokument som fanns sedan tidigare. Sedan samma val som förut: Frågor eller Läs
  upp texten.
- **Länkar hämtas av Kevins `fetch-url` (K81)**: `DrillClient.fetchPage` skickar adressen, får titel och text
  tillbaka, och texten går sedan samma väg som en Word-fils text. En adress utan `https://` får det påsatt.
  Serverns svenska felrader (t.ex. för en PDF-länk eller en sida som kräver inloggning) visas som de är.
- **Foton och bilder läses med `/exam read`** (samma väg som läsläget), filer med appens `DocumentText`.

### A117: krediterna syns
- **Kapsel uppe till vänster på Prov** ("312 frågor kvar"), när kvoten är känd och inte i testläge.
- **Bladet "Frågor kvar"** (`CreditsViews.swift`): stort tal, "Vad det kostar" med raderna ur serverns tabell
  (K82, `prices` i kvotsvaret; inget hårdkodat), och sist "Fylls på den 1 december. Prov som andra har delat eller
  publicerat kostar inget."
- **Varning före**: fanns redan från A110/A115 och är oförändrad. Före Starta prov står "Räknas som n av dina m
  frågor kvar."; räcker det inte är knappen grå och raden säger hur många som fattas och när det fylls på. Samma
  sak i Säg-fältet före Spela.
- En äldre server utan `prices` ger fortfarande talet; bladet visar då bara talet och påfyllningen.

### Största text (från A115-rapportens brister)
Rubrik och teckenräknare står i en stapel, knapparna i fältet växer högst till accessibility1, fältet högst till
accessibility3, kreditbladet öppnas i full höjd, och platshållaren är kortare ("Skriv eller klistra in").

## Avvikelser och frågor
1. **Priserna visar 1 / 1 / 1**, inte Kellys 1 / 1,5 / 2. Bladet läser `questions` ur serverns tabell, och i dag
   räknar servern varje fråga som 1 oavsett längd. Kellys tal motsvarar `tokens` (40/60/80), som D176 börjar ta
   betalt för när betalningen byggs. **Deangelo/Kelly:** ska bladet visa tre rader med samma tal, eller en rad
   ("En fråga: 1") tills priserna skiljer sig?
2. **Tempo 1,25× (rättelse till A115-rapporten):** det väntar inte på Deangelo. Kelly har bekräftat att menyn
   0,5 / 0,75 / 1,0 / 1,5 är rätt (D151) och rättat `docs/design/sag-i-airpods.md`.

## Tester
- **iOS build 43983386543 grön på min gren** (enhetsbygge, varningar som fel, LumenTests), efter 43979150005 (också
  grön, före största-text-rättningen). Bygget på main efter den här pushen: se tavlan.
- **7 nya tester** i `LumenTests/A116A117Tests.swift`: en inklistrad länk blir en adress servern tar; Kevins
  fetch-url-svar avkodas; serverns ord sägs när den vägrar en sida; kvoten med priser avkodas ur Kevins JSON; en
  äldre server utan priser ger ändå talet; raderna säger det tabellen säger; bladet säger när det fylls på.
- **A115 på main: iOS build 43978560504 grön.**
- **Bilder** (`reports/2026-11-17-a116-a117-bilder/`, grenarna `fable/screens-a116-17pro-1` och
  `fable/screens-a116-se-xxxl-2`): iPhone 17 Pro ljust och mörkt (Start med kapsel, bladet, fältet med text,
  Nytt prov med Klistra in länk, Start utan prov) och iPhone SE med största text.

## Otestat (antaganden)
- Menyn bakom "+", kameran, bildväljaren, filväljaren och länkrutan är **inte sedda på bild** och inte körda.
- Inget riktigt anrop till `fetch-url` eller `/drill quota` är gjort från appen; avkodningen är testad mot
  Kevins exempel.
- Inget på enhet. Ljud i AirPods är inte prövat.

## Kända brister
- **iPhone SE, största text, Start utan prov:** platshållaren i Säg-fältet kapas fortfarande till en rad
  ("Skriv elle…"). På Start med prov får den två rader och ryms. Orsaken är inte funnen.
- **Samma storlek, Start med prov:** "En gång" kapas ("En gå…") i sin knapp när kapseln är smal.
- Bladet på iPhone 17 Pro öppnas i halv höjd; sista prisraden och påfyllningsraden syns först när man drar upp.

## Farhågor
Samma som i A115-rapporten (fritext på upprepning kan användas under ett prov). Länkar och filer ändrar inte det:
spelaren är synlig, "Spelar i AirPods" visas, inget schemaläggs och inget döljs.

## Nästa session
- Kelly granskar A115–A117 samlat; rätta det hon hittar, och de två bristerna i största text.
- Toby: T36 (Säg i AirPods), nu också "+", länk och kreditkapseln.
- Svar på fråga 1 (prisraderna).
