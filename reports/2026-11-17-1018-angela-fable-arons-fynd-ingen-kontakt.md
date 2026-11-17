# Arons fynd 08:55: "Ingen kontakt med EarMind just nu" med paus-knapp (Angela Fable, moln)

Klart 2026-11-17 11:23 (första delen 10:18). **Verifierat i CI, inte på enhet och inte på bild.** Orsaken var i appen
och är rättad, se uppföljningen. 0 ElevenLabs (D180).

## Vad Aron såg
Säg i AirPods med texten "HISTORIA – 1880–1918": spelaren visade "Spelar inte", "Mening 2 av 24", raden "Ingen
kontakt med EarMind just nu. Försök igen om en stund." och ändå en paus-knapp, som om något spelade.
Skärmbild: `reports/apptest/aron-2026-11-17-0855-sag-ingen-kontakt.png`.

## Vad som är rättat (appen)
- När spelaren väntar på ljud och **någon** felrad visas (inte bara D200-raden) stegas den för hand: ingen
  paus-knapp, ⏮ ⏭ och tryck på en mening fungerar, och tryckraden säger "Nästa mening · Förra meningen". Samma
  sak i frågespelaren: svaret står som text med "Förra frågan" / "Nästa fråga".
  (`RepetitionModel.soundIsNotComing`, `ReadingViews.swift`, `RepetitionPlayerView.swift`)
- Medan ljudet görs ("Gör ljudet …", ingen felrad) är paus-knappen kvar som förut.

## Vad som inte är rättat: varför raden var "Ingen kontakt"
Raden är appens ord för att anropet till servern (`/drill`: spara, starta eller hämta läget) **inte gav ett svar
som går att läsa**: inget svar inom tidsgränsen, en avbruten anslutning, eller ett svar som appen inte kan avkoda.
Aron hade 5G, så telefonens nät var inte orsaken. Ett svar med `audio_unavailable` hade gett D200-raden
("Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt."). Vilket av de tre det var står bara i
serverns loggar. **Kevin har fått frågan** (meddelande 09:39, K87) och har inte svarat än; jag har inte åtkomst
till loggarna. Tills det är utrett visar appen den sanna raden ("Ingen kontakt …") och inte D200-raden, eftersom
appen inte vet att det handlar om krediter.

## Uppföljning 11:23: orsaken är hittad och rättad (appen)
**Kevins utredning (K87, `reports/2026-11-17-0945-kevin-k87-ljud-0-av-30.md`):** servern svarade rätt på alla anrop
från Arons telefon, ElevenLabs fylldes på 07:27 och ljudet för texten var klart (24 av 24). D200 var alltså inte rätt
läge. Däremot sparades texten **två gånger**, 08:55:16 och 08:55:18: en kopia ostartad, en startad.

**Felet i appen (mitt, från A115):** när en ny text sparas startar appen en bakgrundsuppgift som laddar upp den, och
Spela i Säg i AirPods startade ljudet innan den uppgiften hade börjat. Båda såg ett prov utan server-id och båda
sparade det. Det svar som skrevs sist avgjorde vilken kopia telefonen följde; med den ostartade kom ljudet aldrig,
och spelaren stod och väntade. Samma sak kunde hända ett vanligt prov som startas i samma ögonblick som det sparas.

**Rättat** (`CloudDrillAudio.startAudio`, `DrillCloud.swift`): Starta/Spela håller provet tills det är sparat och
startat, så det sparas en gång. Ett anrop som avbryts skrivs inte längre som "Ingen kontakt" (Kevins punkt 2).
Kreditkapseln läses om när spelaren stängs (Tobys iakttagelse i T36).
**iOS build 44059376273 grön på min gren**, med testet `aNewTextThatIsStartedAtOnceIsSavedOnce` (uppladdningen och
starten körs samtidigt mot en server som svarar med fördröjning: en sparning, en start, ingen felrad).

**Inte belagt:** exakt var raden "Ingen kontakt" kom ifrån den gången. Det finns ingen logg från telefonen.
**Aron behöver prova igen** med nästa app: skriv en ny text i Säg i AirPods och tryck Spela. Det ska höras inom
några sekunder.
**Kvar hos andra:** den ostartade kopian ligger kvar på Arons konto (Kevin raderar inte Arons data; Deangelo
avgör). Kevins punkt 4 ("Ljud: 0 av 30" från en gammal vy) är Angela Schrutes del. Kevin föreslår ett `client_id`
i `save` som extra skydd (förslag till Deangelo).

## Tester
- **iOS build 44048525653 grön på min gren.** Ett nytt test: felrad ⇒ för hand; ingen felrad ⇒ paus finns kvar.
- **A122/A124/A123 på main: iOS build 44048245326 grön**, med kontrollen av byggnummer och commit i appen. Kelly
  har godkänt A122 och A124 på bild.

## Otestat (antaganden)
- Inte sett på bild eller enhet. Scenerna för D200-läget (A112) visar samma form.
- Att felet kommer tillbaka på Arons telefon med nästa app tills serverns del är utredd: troligt.

## Nästa session
- Kevins svar: är det en tidsgräns eller ett svar appen inte kan avkoda? Vid det senare rättas avkodningen i
  `DrillCloud.swift` (Angela Schrutes fil, eller jag på uppdrag).
