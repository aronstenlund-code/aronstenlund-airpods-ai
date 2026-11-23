# A159 – telefonens egen modell svarar när serverns modell är nere (Angela Schrute, moln, 2026-11-23 19:15)

Uppdrag: Deangelo 19:16 (D258). Bara iOS-appen på main; webbetan är orörd.

Märkning: **[CI]** = verifierat i GitHub Actions · **[kod]** = läst i koden · **[antagande]** = otestat.
**Foundation Models finns inte i CI-simulatorn**, så allt om den riktiga modellen på telefonen är antaganden tills Aron
har provat på en iPhone med Apple Intelligence. Låtsasserver och låtsasmodell i alla tester, 0 ElevenLabs.

## 1. Vad som är gjort

- **A40:s reserv gäller nu också när servern svarar `provider_*`** (krediter slut, upptagen, nere – O97), inte bara
  utan nät. För frågor, en gång per fråga, och bara om inget av svaret redan har sagts (ett svar som har börjat och
  sedan bryts tas inte om från början).
- **Telefonens modell svarar på talspråket** (`language` i förfrågan, D257), svenska eller engelska, och börjar med en
  kort rad: **"Jag svarar med telefonens egen modell."** / **"Answering with the phone's own model."** Utan nät står
  A40:s rad kvar ("Jag svarar kort, nätet är borta."; på engelska "A short answer, the network is down.").
- **Finns ingen modell på telefonen, eller kan den inte språket** (`supportsLocale` frågas för just det språket): appen
  säger det den sa förut. För de upplästa svaren är det "Jag kan inte svara just nu …" – inte "Nätet är borta", som
  det hade blivit om telefonmodellens nej hade fått gälla.
- **Inga krediter och inget till servern för det svaret:** servern frågas en gång (och svarar 503), sedan frågas bara
  telefonen. Testerna räknar anropen.
- **Gemensam hjälpare för A159 och A160:** `Lumen/Core/Answer/OnDeviceModel.swift` – `OnDeviceModel` (finns modellen
  för språket; ett svar som text), `SystemOnDeviceModel` (Foundation Models) och `OnDeviceLanguage.locale(for:)`.
  Angela Fable har fått gränssnittet (meddelande och rad i hennes kö) och bygger rättningen på samma dörr.
- **Testkrok för Toby (T57):** i testbyggena (Debug och Beta) kan appen startas med `-OnDeviceMock sv,en` (en
  låtsasmodell som kan de språken och alltid säger samma mening) eller `-OnDeviceMock none` (en telefon utan Apple
  Intelligence). Aldrig i Release: Release-kontrollen i CI letar efter typen i arkivet.

## 2. Teknik (DECISIONS: A159)

- `AnswerEngine`: reserven frågas när felet är `.offline` eller `.backend` med `provider_*`-kod (`OnDeviceReason`).
  Misslyckas också telefonen rapporteras **serverns** fel, så skärmen säger rätt sak. `AnswerRequest.onDevice` bär
  skälet till telefonens leverantör; servern ser det aldrig (`CloudAnswerProvider` skriver sin kropp fält för fält).
- `OnDeviceAnswerProvider` tar en `OnDeviceModel` (riktig som standard), väljer språk, rad och instruktioner. Hela
  svaret hämtas innan raden sägs, så raden aldrig sägs ensam. Instruktionerna säger nu EarMind i stället för Lumen.
- Raderna som sägs högt och modellens instruktioner slås inte upp i textkatalogen: de följer talspråket, inte appens
  språkval (inlagda i `tools/l10n/skip.json` med skäl; `check.py` 0 fel).
- Live-lägena (Socialt, Rizz, Intervju) får ingen reserv, som förut.

## 3. Test

- **Test först:** tre tester mot koden som den var gick ensamma till grenen `angela/a159-test-rod`
  (iOS build 45235054600, väntat rött: REDRESULT).
- Med rättningen, 13 tester i `LumenTests/A159OnDeviceFallbackTests.swift`: telefonen svarar för fyra `provider_*`-koder;
  utan telefonmodell står det gamla felet kvar och det frågas en gång; andra nej (429) väcker inte telefonen; ett
  påbörjat svar tas inte om; telefonen får veta skälet och servern frågas inte två gånger; leverantören själv med
  låtsasmodell: svenska, engelska, nätets rad, språk som modellen inte kan, modell som faller eller tiger; Tobys krok.
  **iOS build GREENRUN: GREENRESULT** (hela sviten).
- **Inte testat:** den riktiga modellen på en iPhone – finns den, kan den svenska (kräver iOS 26.1), hur lång tid tar
  svaret, hur låter det. Det är Arons prov.

## 4. Arons prov (iPhone 15 Pro eller senare med Apple Intelligence påslaget)

1. Starta lyssningen och ställ en fråga på svenska ("Vad är roten ur hundra?"). Medan kontot saknar krediter ska
   svaret börja med "Jag svarar med telefonens egen modell." och sedan komma.
2. Samma på engelska ("What is the square root of a hundred?") med engelska som talspråk.
3. På en telefon utan Apple Intelligence: appen säger "Jag kan inte svara just nu …" som förut.

## 5. Kvar

- Angela Fables A160 (sparade prov) och Tobys T57.
- Grenarna `angela/a159-test-rod` och `angela/o97-test-rod` behövs inte mer; jag tar bort dem om du säger till.
