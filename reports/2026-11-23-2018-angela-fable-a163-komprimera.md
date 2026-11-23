# A163 (D259): Komprimera före tal i Säg i AirPods

Angela Fable (moln), 2026-11-23. Beställt av Deangelo 19:51 (Aron 19:36). iOS-appen på main.

## Vad som är gjort

1. **Knappen Komprimera / Compress** står under texten i Säg i AirPods när texten är värd att korta (minst 160
   tecken). Ett tryck gör texten kortare med samma innehåll och **lägger den kortare texten i fältet**, där den kan
   ändras. **Inget spelas förrän man trycker Spela.**
2. **Ångra** (samma knapp efter komprimeringen) ger tillbaka originalet, också om man har ändrat i den kortare
   texten. Töms fältet glöms originalet.
3. Under fältet står en rad: "Kortad från 240 till 90 tecken. Ändra om du vill." (eller "Kortad av telefonens
   modell från …"), och om det inte gick: "Det gick inte att komprimera just nu." / "Texten blev inte kortare."
4. **Vem kortar:** serverns modell först. Kan servern inte (modellen nere, 503 `provider_*`, D258; åtgärden finns
   inte på servern än; inget nät) kortar **telefonens egen modell** om den finns och kan språket. Inga krediter
   dras för telefonens arbete och inget skickas för det.

## Viktigt: serverdelen finns inte än

Servern har ingen komprimering (`/exam` känner inte `compress` och svarar 400). Jag har byggt appen mot ett
föreslaget kontrakt och bett Kevin om det i hans kö: `POST /exam {"action":"compress","text","lang"}` → `{"text"}`.
**Tills Kevin har byggt det, och så länge modellkrediterna är slut, fungerar Komprimera bara på telefoner med Apple
Intelligence** (iPhone 15 Pro eller senare, påslaget). På andra telefoner säger raden "Det gick inte att komprimera
just nu." och texten är orörd.

## Teknik

- `Lumen/Core/Repetition/SayCompress.swift` (ny): `TextShortening` och `TextShortenClient` (servern),
  `SayCompressor` (server först, sedan telefonens modell genom Angela Schrutes `OnDeviceModel`), `SayCompression`
  (fältets tillstånd: originalet för Ångra och raden), `SayCompressText`, `MockTextShortener` (mock-läget: första
  halvan av meningarna, så vägen går att se i Simulatorn).
- `SayViews.swift`: raden med knappen (`accessibilityIdentifier` `say.compress`); VoiceOver får raden uppläst och
  en ledtråd om vad knappen gör.
- Bara en text som verkligen blev kortare läggs i fältet. Ändras texten medan den kortas står användarens text kvar.
- Bildscener: `repSayCompress` (knappen) och `repSayCompressed` (efter: kortare text, Ångra, raden).

## Test

- **Skrivna först:** `LumenTests/A163CompressTests.swift` (11 tester) med låtsasserver och låtsasmodell: servern
  kortar; telefonens modell tar över när serverns modell är nere, när åtgärden saknas och utan nät; engelska när
  appen är på engelska; utan någon modell står texten kvar med en rad; en text som inte blev kortare används inte;
  fältet får den kortare texten och Ångra ger originalet (också efter ändringar); serverns svar läses rätt (200,
  503 `provider_quota`, 400, 429, 500, inget nät); orden på båda språken.
- KÖRNINGAR
- **Den riktiga modellen på telefonen är inte körd** (Foundation Models finns inte i CI-simulatorn), och serverns
  komprimering finns inte. 0 ElevenLabs (D180).

## Kända brister och risker

- **Otestat på telefon.** Hur bra telefonens modell kortar en svensk text vet vi inte förrän Aron provar.
- Telefonens modell tar bara den text den får plats med; mycket långa texter kan den neka, och då står texten kvar.
- Komprimeringen på servern kommer att kosta modellanrop (inte krediter i dag); Kevin avgör om den ska räknas.

## Farhågor

Inga.

## Kvar / nästa session

- Kevin: `compress` i `/exam` (rad i hans kö). När den finns: kör mot servern och se att raden och Ångra fungerar.
- Arons telefonprov med Apple Intelligence påslaget.
