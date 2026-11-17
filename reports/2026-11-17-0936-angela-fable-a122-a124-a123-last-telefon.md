# A122 (D209), A124 (D210), A123: låst telefon, 10 min till 1 timme, byggnummer (Angela Fable, moln)

Klart 2026-11-17 09:36. **Verifierat i CI och på simulatorbild. Det som gäller låst skärm och AirPods är INTE
verifierat på enhet** (simulatorn räknas inte); provlistan till Aron står nedan. 0 ElevenLabs (D180).

## Vad som är gjort
### A122: "Telefonen behöver inte vara framme"
- Raden **"Du kan låsa telefonen och lägga undan den. Det hörs i AirPods ändå."** står alltid i Säg-fältet, direkt
  under texten (också när fältet är tomt). Kostnadsraden står under den när det finns text (Kellys ordning).
- **Låsskärmen** visar titeln "EarMind · Säg i AirPods" och under den textens första ord och varvet
  ("Fotosyntes … · varv 2"). (`RepetitionSession.sayingNowPlaying`)
- **Det som redan fanns och gör raden sann (läst i koden, inte ändrat):** appen har bakgrundsljud
  (`UIBackgroundModes: audio`), ljudsessionen är `.playback`, upprepningen ligger i sessionen och räknar tid med
  klockan (inte med skärmen), och play/paus, nästa och förra från låsskärmen och AirPods går via
  `RemoteCommandHub` (`MPRemoteCommandCenter`) till spelaren: 1 tryck paus/spela, 2 tryck nästa mening, 3 tryck
  förra meningen.

### A124: Hur länge, 10 min till 1 timme
- "En gång" och 5/10/20 är borta. Menyn (systemets Menu, Kellys val) har **10 min, 15 min … 55 min, 1 timme**,
  standard 10 min. Knappen visar "10 min" / "1 timme". Ett sparat gammalt val (En gång, 5 min) blir 10 min.
- Spela **spelar direkt** och texten går runt tills tiden är ute; varvet som läses när tiden tar slut läses klart.
  Spelaren visar "Varv 3 · 6:54 kvar av 10 min" ("… av 1 timme").
- **Ingen fördröjd start är byggd** (D210, Deangelos tolkning). Inget schemaläggs.

### A123: byggnummer
- Det installerbara bygget (`ios-build.yml`, .ipa) får körningens nummer som byggnummer och commitens korta SHA i
  Info.plist (`LumenGitSHA`). Bygget kontrollerar själv att båda hamnade i appen, och sammanfattningen på
  körningens sida säger numret.
- **Om appen** och en liten rad **sist i Inställningar** visar "Version 0.1.0 (körning 44043578182 · abc1234)".
  Simulator- och testbyggen visar "Version 0.1.0 (1)".

## Prova på telefonen (Aron, med AirPods i öronen)
Först: öppna Inställningar i appen och läs sista raden. Numret efter "körning" ska vara samma som på
GitHub-körningen du laddade ner appen från. Står det bara "(1)" är det en äldre app.
1. Skriv två meningar i Säg i AirPods, låt Hur länge stå på 10 min, tryck Spela. Det ska höras direkt.
2. **Lås skärmen** medan det spelar. Det ska fortsätta höras, och gå vidare till **varv 2** utan att du rör telefonen.
3. Tänd skärmen utan att låsa upp: låsskärmen ska visa "EarMind · Säg i AirPods" med paus och nästa/förra.
4. **Tryck 1 gång på AirPods-skaftet**: paus. 1 gång till: det fortsätter.
5. **2 tryck**: nästa mening. **3 tryck**: förra meningen.
6. Pausa, vänta 2 minuter med låst skärm, tryck sedan 1 gång på AirPods. Fortsätter det? (Osäkert, se nedan.)
7. Lägg telefonen i fickan och låt det gå tills 10 minuter har gått: det ska sluta av sig självt efter varvet.
8. Ta ur en AirPod mitt i: det ska pausa.
Säg vilket steg som inte gjorde som det står.

## Tester
- **iOS build 44043578182 grön på min gren** (manuell körning: enhetsbygge, varningar som fel, LumenTests och
  packning av .ipa med kontrollen att byggnummer och SHA finns i appen). Före den 44039369869 (A122) grön.
- **6 nya tester** i `LumenTests/A122LockedPhoneTests.swift`: radens text; låsskärmens ord; upprepningen går runt
  och pausas av ett tryck utan någon vy; Hur länge är 10–60 i steg om 5 och gamla val blir 10; en timme startar
  direkt och går hela timmen; byggraden. A115-testerna är uppdaterade ("1 timme").
- **Bilder** i `reports/2026-11-17-a122-a124-bilder/` (grenarna `fable/screens-a124-17pro-2` och
  `fable/screens-a124-se-xxxl-2`): Start med och utan prov, fältet med text, spelaren; SE med största text.

## Otestat (antaganden)
- **Allt i provlistan.** Särskilt steg 6: när appen har stått pausad länge i bakgrunden kan iOS ha stoppat den, och
  då fortsätter den kanske inte av ett tryck. Det går inte att se i simulatorn.
- Menyn Hur länge finns inte utfälld på bild. Raden i Om appen och Inställningar finns inte på bild.
- Tobys T36 är anpassad till den nya menyn men inte körd mot den här koden än.

## Farhågor
- Raden uppmanar till att lägga undan telefonen. Det är Arons beslut (D209) och sant om uppspelningen, men det gör
  det också lättare att lyssna utan att det syns, till exempel under ett prov. Skydden som finns kvar: det spelar
  bara när man själv har tryckt Spela, låsskärmen visar vad som spelas, appen döljer ingenting och ingen
  fördröjd eller tidsinställd start finns (D210). En timmes upprepning ökar räckvidden för samma farhåga som i
  A115-rapporten.

## Nästa session
- Arons svar på provlistan. Går steg 2 eller 6 fel behövs en rättning i spelaren (Angela Schrutes del, eller min på
  uppdrag).
- Kellys granskning av texten och menyn.
