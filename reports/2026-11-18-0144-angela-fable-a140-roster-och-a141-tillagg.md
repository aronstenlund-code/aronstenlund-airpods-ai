# A140 (D223): Blanda röster och AI:s röstval, och tillägg till A141 (Angela Fable, moln)

Klart 2026-11-18 01:44. **Verifierat i CI (iOS build 44207593080 grön på min gren: enhetsbygge, varningar som fel,
LumenTests) och på bild i Simulatorn med låtsasdata. Inget på enhet, och inget riktigt svar från servern med de nya
fälten har gått genom appen.** 0 ElevenLabs (D180).

## A140
- **Blanda röster:** en omkopplare överst i bladet Röst, av som standard, med raden "Varje stycke får en egen röst,
  samma varje gång." Valet skickas som `drill.mix_voices` vid första sparningen (Kevins K99) och sparas till nästa
  text. Röstkapseln visar då "Blandat". Väljer man en röst i bladet stängs blandningen av.
- **AI väljer röst:** när "Hur ska det låta?" har text och ingen röst är vald svarar servern redan i
  kostnadsfrågan med en röst och en kort motivering. Kapseln visar då den rösten ("Gustav ▾") och under stilraden
  står "Gustav · Mörk och tydlig, passar en lärare." Kapseln öppnar bladet, så rösten går att byta före Spela.
  **Den röst som visades är den som sparas** (appen skickar den med Spela), så det man såg är det man hör.
  Samma text och stil igen är samma prov och kostar 0; servern väljer inte om.
- **Rösten som talar:** medan det spelar står "Spelar i AirPods · Astrid" på kortet. Med blandade röster är det
  styckets egen röst (`items[].voice_id`), annars textens röst, annars serverns standardröst.
- **Att provlyssna:** röster med `review: true` står under egen rubrik sist i bladet. Servern skickar dem bara till
  Arons konto.
- Sökningen i bladet går nu över alla språk (`lang=any`).
- Utan vald röst visar kapseln **standardröstens namn** (`default_voice`), som Kelly bad om; "Röst" bara om servern
  inte sagt något.

## Tillägg till A141 (Kevins nya fält)
- **"+2 000 krediter för en inbjudan."** står överst i kreditbladet en gång för varje ny belöning (`rewards`).
  Kontona är anonyma, så det finns inget namn.
- **"Du har bjudit in 10 i månaden. Fler ger krediter nästa månad."** när månadens tak är nått.
- **"välkomstkrediter"** under siffran när allt som är kvar är välkomstkrediter (`gift`). Min regel: gåvan kommer
  från välkomsten och inget annat finns kvar; med månadens krediter står det "krediter kvar" igen.
- **Köp:** avslutas hos Apple vid serverns 200 och vid 409 (köpet hör till ett annat konto, som har fått
  krediterna). Vid 422, serverfel eller utan nät avslutas det inte, utan skickas igen vid nästa start (Kevins regel).
- Kellys kortare rad: "Köpet är gjort. Krediterna kommer när EarMind har kontakt igen."

## Tester
- `LumenTests/A136StyleVoicePaceTests.swift`: blandningen skickas bara första gången och är ett eget ljud; styckets
  röst, `mix_voices`, serverns röstval och motivering läses; den röst servern valde sparas och samma text är samma
  prov nästa gång; en egen vald röst skrivs inte över; rösten som talar namnges (standard, vald, blandad per stycke);
  röster under granskning och standardrösten läses.
- `LumenTests/A134ShopTests.swift`: avslut vid 409 men inte vid 422 eller 500; en belönad inbjudan sägs en gång;
  månadens tak; välkomstkrediter bara när inget annat är kvar.

## Bilder
`reports/2026-11-18-a140-bilder/`:
- `roster-ai-val-blanda.jpg`: AI:s val under stilraden · bladet Röst med Blanda röster och Att provlyssna · kortet
  "Spelar i AirPods · Astrid".
- `valkomst-inbjudan.jpg`: "5 000 välkomstkrediter" · "+2 000 krediter för en inbjudan." · Senaste.
- SE med största text är beställd (körning 44207596749) men inte klar när detta skrevs.

## Otestat (antaganden)
- Katalogen fylls först när Deangelo kört Kevins 20261117230001–2, så i dag syns varken röstkapsel, blandning eller
  AI-val i Arons app.
- Att Haiku väljer samma röst i `cost` som appen sedan sparar spelar ingen roll, eftersom appen skickar den visade
  rösten. Att servern godtar en vald röst tillsammans med stil är Kevins kontrakt, inte provat mot servern.
- Orden "Blanda röster", "Varje stycke får en egen röst, samma varje gång.", "Blandat", "Att provlyssna" och
  "{Namn} är vald efter stilen." (när motivering saknas) är mina; Kelly granskar.
- Senaste-kapselns tillägg (stil eller röst) syns inte på bilden, eftersom scenens texter saknar stil och röst.
- Inget på enhet.

## Farhågor
Röster med brytning ("Kines", "Hindi") är Arons beslut (D223) och ligger under granskning på servern; appen visar dem
bara för hans konto. Inget i appen väljer eller framhäver dem.

## Kvar
Kön är tom efter detta. Kelly granskar orden och bilderna; Toby har T48 och T50.

## Tillägg 02:31
- **A140 på main: iOS build 44210564163 grön**, med Kellys ordändring: raden för AI:s val säger "Vald efter stilen ·
  {motivering}" (namnet står redan i kapseln). Kelly har godkänt A140 och A141-tilläggen.
- `se-storsta-text.jpg` finns nu i bildmappen (tagen före ordändringen, så raden säger "Gustav · …" där).
- **Säg-textens märke på servern** (Angela Schrutes fynd i T28, Kevins `drill.said`): appen skickar `said: true` för
  en Säg-text och läser det tillbaka, så en text som hämtas till en ny telefon inte gissas på titeln. Appen litar
  bara på serverns ja, eftersom servern svarar nej för allt tills Deangelo kört `20261118010001_drills_said.sql`.
  **iOS build 44213365132 grön på min gren**; test i `A136StyleVoicePaceTests`. Inte provat mot servern.

