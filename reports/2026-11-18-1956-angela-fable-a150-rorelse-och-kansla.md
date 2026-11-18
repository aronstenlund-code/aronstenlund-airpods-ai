# A150 (D231): rörelse och känsla i repetitionsflödets vyer (Angela Fable, moln)

Klart 2026-11-18 19:56. **Verifierat i CI: iOS build 44366384147 grön på min gren (enhetsbygge, varningar som fel,
LumenTests, ihopslaget med A148). Rörelsen är sedd som bildrutor ur en inspelning i Simulatorn (10 rutor i
sekunden), inte på enhet. En rättning som gjordes efter inspelningen är inte sedd än (se "Inte sett").**
0 ElevenLabs.

## Vad jag gick efter
Kellys fyra dokument (forsta-skarmen, sag-i-airpods, kop, stil-och-roster) säger nästan inget om rörelse: bara att
fältet tonar ut nedåt och att markören står still med minskad rörelse. Jag har därför gått efter reglerna i
apple-design (Apples "Designing Fluid Interfaces"), som D231 pekar på, och jämfört appen mot dem på de skärmar
dokumenten gäller: Start med Säg-kortet, bladet Röst, kreditbladet med köpdelen och spelaren.

## Vad som avvek, och är rättat
| Regel | Före | Nu |
|---|---|---|
| Ett tryck besvaras direkt, på vägen ner | Knappar utan systemets utseende gav ingen återkoppling alls: Pausa, Stoppa, texten på kortet, "Fyll på", ▶ provlyssna, röstraderna, Återställ köp, raderna under Andra prov | De tonas ner i samma ögonblick som fingret går ner (runda knappar krymper också lite) och går tillbaka mjukt |
| Det som ändras rör sig dit, det hoppar inte | Kortet bytte läge och höjd i ett hopp (stilraden, kostnaden, väntraden, skrivläge ↔ spelläge), och listan under hoppade med | Kortet tar sin nya höjd med en fjäder utan studs (0,3 s); rader kommer och går genom att tonas där de står |
| Ingen studs där inget kastats | (inga egna fjädrar fanns) | Alla nya rörelser är kritiskt dämpade; ingen studs någonstans |
| Tal byts utan att hoppa | Kostnaden, kapseln och siffran i kreditbladet byttes i ett hopp; prisknappen bytte bredd när snurran kom | Talen rullar på plats; priset ligger kvar under snurran så knappen behåller bredden |
| Det som kommer en väg går samma väg tillbaka | Spelaren för en Säg-text kom upp underifrån från kortet, men enda vägen ut var Avsluta, som stoppar ljudet | En pil nedåt uppe till höger fäller ner spelaren till kortet och texten spelas vidare |
| Fylld knapp byter plats utan hopp | Starta prov bytte mellan fylld och tonad i ett hopp när Spela tog över | Bytet tonas |
| Symboler byts på plats | ▶/⏸ och ▶/↻ byttes i ett hopp | Systemets symbolbyte |
| Minskad rörelse respekteras | (ingen rörelse fanns) | Med Minska rörelse: inget rör sig, inget krymper; bara en kort toning (0,15 s) och talen tonas i stället för att rulla |
| Känsel där den betyder något | Ingen haptik | Ett val i röstbladet, ett genomfört köp, och ett nej (servern nekar, Spela ger upp, köpet misslyckas) känns en gång |

**Det som redan stämde och inte är rört:** alla blad (Krediter, Röst, påminnelsefrågan, kameran) är systemets egna
och kommer underifrån och går samma väg, går att dra ner och avbryta mitt i; menyerna (＋, tid, tempo) växer ur sin
knapp; systemets knappstilar har egen tryckåterkoppling; tiden på kortet har fasta sifferbredder.

## Vad inspelningen visade
`reports/2026-11-18-a150-bilder/` (flödet 44313232863, iPhone 17 Pro; scenen `repMotion` går själv igenom kortets
lägen, `repMotionReduced` samma med minskad rörelse påtvingad):
- `rorelse-1-text-kostnad-tal.jpg`: kostnaden kommer (3,1–3,3 s: kortet växer över tre rutor, listan följer med) och
  talet rullar från 120 till 1,3k medan Starta prov tonas till fylld (4,6–4,9 s).
- `rorelse-2-vantar-kortet-spelar.jpg`: väntraden, bytet till spelkortet (8,8–9,1 s) och raden på kortet (10,3–10,6 s).
- `rorelse-3-spelar-ger-upp.jpg`: tillbaka till fältet med felraden (14,0–14,3 s).
- `minskad-rorelse-1.jpg`, `-2.jpg`: samma lägen byts på en till två rutor utan rörelse.
- `rorelse.mp4`, `minskad-rorelse.mp4`: inspelningarna för den som vill se dem i rörelse.
- `stillbilder.jpg`: väntraden på kortet, kortet som spelar, spelaren med pilen nedåt, bladet Röst.

**Ett fel som inspelningen avslöjade och som är rättat:** när kortet bytte mellan skrivläge och spelläge låg gammal
och ny text ovanpå varandra i två rutor (8,9 s och 14,1 s i bilderna), och den nya texten stack ut ovanför kortet.
Nu går det gamla läget ut innan det nya kommer in, kortet växer från sin överkant och inget syns utanför kortet.

## Inte sett
- **Rättningen av överlappet ovan.** Den är byggd och grön, men den nya inspelningen (44366387435) har stått i
  Mac-kön i över en timme. Bilderna i mappen visar alltså läget före rättningen på just de två ställena.
- Tryckåterkopplingen (går inte att fånga utan ett finger), haptiken (Simulatorn har ingen), symbolbytena och
  bocken i röstbladet.
- Hur listan på Start följer kortets höjd på en riktig telefon. I inspelningen följer den med utan hopp.
- Ingenting på enhet.

## Val jag gjort
- **Pilen nedåt i spelaren** är ny och har ingen ritning. VoiceOver säger "Tillbaka till Start", "Texten spelas
  vidare." Den visas bara för Säg-texter som spelar, inte när uppläsningen är avstängd. Kelly får granska.
- Rörelsens längd (0,3 s, 0,15 s med minskad rörelse) och tryckets nedtoning (55 %) är mina tal, samlade i
  `SayMotion.swift` så att de ändras på ett ställe.
- Kapseln i verktygsfältet dyker fortfarande upp i ett hopp första gången krediterna blir kända; systemets
  verktygsfält ger ingen övergång där.

## Teknik
- Ny fil `Lumen/Features/Repetition/SayMotion.swift`: `SayMotion` (rörelsen, övergångarna, talen) och
  `PressFeedbackStyle`.
- `SayViews`, `SayVoiceViews`, `ShopViews`, `CreditsViews`, `RepetitionHomeSection`, `ReadingViews`.
- `fable-screens.yml` har fått `record`: en scen spelas in och blir ett ark med bildrutor och en liten video.
- Scenerna `repMotion`, `repMotionReduced`, `repSayOnCardWaiting` och, till Kellys App Store-bild (Ke80),
  `repSayVoicesUser` (röstbladet utan röster under granskning).
- Ihopslaget med Angela Schrutes A148: hennes etiketter, tryckytor och grå färg är kvar.

## Test
`A136StyleVoicePaceTests`: rörelsen är en fjäder utan studs, minskad rörelse ger kort toning, talen rullar eller
tonas, tryckstilen. Resten av A150 är utseende och går inte att enhetstesta; det är inspelningen som visar det.

## Farhågor
Inga. Inget här döljer något; "Spelar i AirPods" står kvar hela tiden det spelar, också när spelaren fälls ner.

## Tillägg 20:40: Kellys Ke83 och den nya inspelningen
Kelly godkände A150 (`reports/2026-11-18-1955-kelly-ke83-a150-rorelse.md`) med två tillägg. Båda är byggda och
sedda i en ny inspelning (flödet 44375329952). **iOS build 44375326631 grön på min gren.**

1. **Spelaren går att dra ner.** Den följer fingret ett till ett nedåt, med Start synligt bakom. Släpper man
   halvvägs går den tillbaka (med den lilla studs en sak som flyttats har); är dragningen på väg ner fälls spelaren
   ner i fingrets fart och texten spelas vidare på kortet. Det som avgör är vart dragningen är på väg, inte var den
   är. Uppåt ger den efter lite och håller emot. Greppet är spelarens övre del (med samma handtag som systemets
   blad), eftersom texten under rullar. VoiceOver har "Tillbaka till Start" på pilen och svarar på gesten för att
   backa. Pilen har 44 punkters tryckyta.
   - `spelaren-dras-ner.jpg` (och `.mp4`): 1,4–2,1 s dras ner och släpps, 2,2–2,4 s tillbaka; 3,4–3,9 s dras och
     fälls ner, 3,9 s kortet på Start spelar.
2. **Ingen paus medan inget hörs.** Tills första ljudet börjar står en liten snurra där pausknappen ska vara.
   Stoppa finns hela tiden. (`stillbilder-2-snurra-handtag-rostblad.jpg`, första rutan.)

**Det rättade kortbytet, nu sett:**
- Till spelkortet (`kortbyte-efter-rattning-1-till-spelkortet.jpg`, 8,5–8,7 s): rent. Inget överlapp, inget utanför
  kortet.
- Tillbaka till fältet (`kortbyte-efter-rattning-2-till-faltet.jpg`, 14,5–14,7 s): **inte helt rent.** I en bildruta
  (0,1 s) syns det gamla läget svagt under det nya, och den nya textens första rad är kapad i kortets överkant.
  Förut var det två rutor med text ovanpå text och text utanför kortet. Resten beror på att listans rad ändrar höjd
  runt innehållet; det kommer jag inte åt utan att bygga om kortet utanför listan. Kelly får avgöra om det duger.

**Inte sett:** dragningen med ett riktigt finger (inspelningen drar spelaren i kod), haptiken, och allt på enhet.

**Main-bygget 44374756678 (A150 utan Ke83-tilläggen) föll på två test i Rizz-läget**
(`rig.model.rizz?.suggestions == ["Ett"]`, `rig.provider.requests.count == 2`), som väntar på tid och som jag inte
har rört. Samma kod klarade alla test i mitt bygge. Jag har sagt till Angela Schrute.

## Tillägg 23:30: godkänt av Kelly, grönt på main

- **Kelly har godkänt båda Ke83-tilläggen** (dra ner spelaren, snurra i stället för paus) och det rättade kortbytet.
  Bildrutan vid 14,6 s duger: den ligger mitt i en toning och ingen text hamnar utanför kortet. Kortet flyttas inte
  ur listan. Syns det på telefon tas det upp igen. → `reports/2026-11-18-1955-kelly-ke83-a150-rorelse.md`
- **Main-bygget 44382692902 (A150 med Ke83-tilläggen, b2db43b0) är grönt**, med alla test (verifierat i CI). De två
  Rizz-testen som föll i 44374756678 var en kapplöpning i live-lägena; Angela Schrute har rättat den (eaa7279f).
- Kvar: allt på enhet (dragningen med ett riktigt finger, haptiken). Tobys fynd 18:00 (ny text utan nät säger
  ingenting) är fortfarande inte förklarat; nattflödet 44411718185 med T36 står i kön och ger loggraderna.
