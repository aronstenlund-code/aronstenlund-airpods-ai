# A167: Tillgänglighet och små skärmar i repetitionen före App Store

Angela Fable (moln), 2026-11-26/27. Beställt av Deangelo 22:39 och 00:10. iOS-appen på main. Mina vyer: Spela in
själv, Säg i AirPods (Komprimera), butiken och lanseringsbladet.

## Hur jag letade

- **Bilder före** med största textstorleken (AX5, `accessibility-extra-extra-extra-large`) på minsta iPhone
  (iPhone SE 3:e gen.), svenska och engelska, ljust och mörkt: Start med och utan prov och med egna samlingar,
  samlingen (ny, ifylld, medan det spelas in), bladet om Spela in själv, lanseringsbladet, butiken under
  lanseringsveckan, Komprimera före och efter, Säg i AirPods med kostnad, röstbladet (Fable screens 45898322000).
- Genomläsning av koden för VoiceOver-etiketter, uppläsning av lägen, kontrast och animationer.
- **Bilder efter** med samma inställningar (Fable screens 45909183379).

## Vad jag hittade och rättade

| Ställe | Före | Efter |
|---|---|---|
| Spela in själv, inspelningsraden | Vid AX5 bröts knappen mitt i ordet ("R / ecord") och "Not record-ed" bredvid | Knappen och raden bredvid står under varandra vid de största storlekarna |
| Spela in själv, namnet | "Biologi kapit…" kapat | Namnet bryts på upp till tre rader; Retur avslutar namnet i stället för att göra en ny rad |
| Bladet "Slut på krediter?" | Rubrik, text och knapp kapade med "…" i ett halvblad | Vid de största storlekarna tar bladet hela höjden, och det som inte ryms rullar; "Inte nu" har en hel 44-punktsrad |
| Lanseringsbladet | Samma kapning ("Lanserings…", "Slutar om 2 d…") | Samma rättning |
| Butikens lanseringsrad | "Lanse-rings-rabatt" i tre bitar bredvid "-65 %" | Namnet och procenten står under varandra vid de största storlekarna |
| VoiceOver, samlingen | Alla fält hette "Fråga"/"Svar", oavsett kort | "Fråga 2", "Svar 2" (det synliga ordet är oförändrat) |
| VoiceOver, inspelning | "Spelar in"/"Inspelat" utan vad | "Spelar in frågan" / "Klar, frågan är inspelad" (och svaret), på sv och en |
| VoiceOver, Stoppa | Hela etiketten "Stoppa inspelningen, 4 sekunder" lästes om varje sekund | Etiketten är "Stoppa inspelningen", tiden är värdet ("4 sekunder") |
| VoiceOver, Spela in | Raden "Inte inspelad · läses av telefonen" lästes som en lös rad efteråt | Den läses som knappens värde: "Spela in svaret, Inte inspelad · läses av telefonen" |
| VoiceOver, butiken | Resultatet av ett köp syntes bara under listan | Det läses upp när det kommer |

Bilder före/efter i `reports/2026-11-27-a167-bilder/`: `a167-samlingen-se-storst-text.jpg`,
`a167-bladen-se-storst-text.jpg`, `a167-butiken-och-ny-samling-se-storst-text.jpg`.

**Kontrast:** text i mina nya vyer använder `LumenColor.secondaryText` (kontrollerad mot AA i A148) eller systemets
färger; grå knappar är bara grå när de inte går att trycka på. Inget att rätta. **Reduce Motion:** nivåmätaren och
Säg-kortets övergångar följer redan inställningen (`SayMotion`); de nya vyerna har inga egna animationer. Inget att
rätta.

## Teknik

- `OwnDeckViews.swift`: `OwnTakeRow` med `AnyLayout` (HStack/VStack efter textstorlek), `accessibilityValue` för tiden
  och för "Inte inspelad …"; numrerade fältetiketter; namnfältet `axis: .vertical`; uppläsningarna vid start och slut
  av en inspelning; `OwnDeckOfferSheet` med `ViewThatFits` (innehållet, annars samma i en `ScrollView`) och
  `.large` vid tillgänglighetsstorlekar.
- `LaunchOfferViews.swift`: samma för lanseringsbladet; `LaunchOfferRow` staplar namn och procent.
- `ShopViews.swift`: köpets rad läses upp (`AccessibilityNotification.Announcement`).
- `OwnDecks.swift`: `field(_:number:)`, `stopRecording`, `seconds(_:)`, `nowRecording(_:)`, `doneRecording(_:)`.
- `tools/l10n/l10n.py`: `whole` räknas som heltal (`%lld`) när nycklarna gissas.

## Test

- **5 nya enhetstester** (`LumenTests/A167AccessibilityTests.swift`): numrerade fältetiketter, uppläsningarna vid
  start och slut, Stoppa med tiden som värde, "Inte inspelad" som Spela ins värde, och att orden finns på sv och en.
- **iOS build 45909183899 på min gren grön i sin helhet (enhetsbygge utan varningar, alla enhetstester, App Store-arkivet)** (verifierat i CI, Simulator).
- **Bilder före och efter** (Simulator, iPhone SE 3:e gen., AX5, sv och en, ljust och mörkt): Fable screens
  45898322000 (före) och 45909183379 (efter). **Verifierat på bild, inte med VoiceOver på telefon.**
- 0 ElevenLabs, inga modellanrop.

## Kända brister och risker

- **VoiceOver är inte provat med en människa på en telefon** (Simulatorn tar inte VoiceOvers fokus på bild).
  Ordningen följer layoutens ordning, som är uppifrån och ned; **otestat antagande** att den känns logisk.
- Vid AX5 avstavar systemet fortfarande långa ord på smala skärmar ("Lanseringsra-batt"), och platshållaren i
  namnfältet ("e.g. Vocabul…") kapas. Båda går att läsa och nå; jag har inte tvingat fram mindre text.
- Bladen rullar vid AX5 på en SE: knappen ligger under kanten och nås genom att rulla (VoiceOver når den alltid).
- Angela Schrutes skärmar (första starten, lyssnandet, Inställningar) ingår inte; de är hennes.

## Farhågor

Inga.

## Kvar / nästa session

- Kellys ordlista (Ke91) för mina vyer – nästa punkt.
- Spela in själv och Säg i AirPods enklare första gången (Deangelo 22:39).
