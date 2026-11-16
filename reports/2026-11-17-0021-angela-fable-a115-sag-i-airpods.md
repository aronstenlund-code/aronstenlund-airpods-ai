# A115 (D203): "Säg i AirPods" (Angela Fable, moln)

2026-11-17 00:21. Form och texter: Kellys Ke69 (`docs/design/sag-i-airpods.md`). Beslut: D203 (Aron, Deangelo utformar).
**Inget är provat på telefon. Inga ElevenLabs-anrop (D180): testerna använder falskt ljud, bilderna förberedda lägen.**

## Vad som byggdes
| Del | Vad | Fil |
|---|---|---|
| Fältet | Överst på Start, före Nästa prov och också när inga prov finns. Mörkt i ljust och mörkt läge, systemets monospace, `›` i accentfärg, platshållaren "Skriv eller klistra in det du vill höra", antal tecken uppe till höger | `SayViews.swift` (ny), `RepetitionHomeSection.swift` |
| Kostnaden före | Under texten: "Räknas som 1 fråga. Upprepningar kostar inget." Räcker kvoten inte: Kellys mening, och Spela är grå. Utan krediter (D200): "Uppläsningen är tillfälligt avstängd. Texten fungerar som vanligt." | `SayViews.swift` |
| Hur länge | Meny: En gång (förvald), Upprepa 5, 10, 20 min. Valet sparas | `SayViews.swift` |
| Tempo | Meny: 0,5× · 0,75× · 1,0× · 1,5×. Samma inställning som i Inställningar | `SayViews.swift` |
| Spela | Sparar texten som en uppläsning, ordagrant (ett stycke per rad), och startar den som vilken text som helst. Samma text igen spelar ljudet som redan finns | `RepetitionModel.say`, `sayAgain` |
| Spelaren | Läslägets spelare (D185) med texten i monospace. Överst "● Spelar i AirPods" medan ljud spelas (annars "Pausad", "Klart" eller "Spelar inte"), och vid upprepning "Varv 3 · 7:03 kvar av 10 min" | `ReadingViews.swift` |
| Upprepningen | Texten börjar om så länge tid finns kvar. Varvet som läses när tiden tar slut läses klart, sedan stannar det. Avsluta stoppar direkt | `RepetitionSession` |

## Hur det fungerar
- **Varje ny text blir ett sparat prov** av sorten text, namngivet efter sina första ord. Det syns i listan på Start
  och går att spela igen därifrån. Ljudet begärs när man trycker Spela (D190), och månadens frågor räknas då per
  påbörjade 800 tecken (D185). Upprepningar och Spela igen på samma text kostar inget, eftersom ljudet sparas.
- **Utan krediter (D200):** servern säger att ljudet inte kan göras. Spelaren öppnas ändå med texten, raden visas,
  och inget dras (A112, A112b).
- **Upprepningen ligger i sessionen**, inte i vyn, så den fungerar med låst skärm. Den startas bara av Spela.

## Avvikelser från Ke69 (till Kelly och Deangelo)
1. **Tempo 1,25× finns inte.** Tempona som spelaren tar är beslutade i D151 och låsta av `A84VoiceTempoTests`; 1,25
   är inte ett av dem. Jag lade först till det, testet blev rött (iOS build 43971703703), och jag tog bort det igen.
   **Deangelo avgör** om listan ska utökas.
2. **"+" för material** finns inte i fältet än. Det är A116.
3. **Ingen egen blockmarkör.** Fältet har systemets markör i accentfärgen när det har fokus. Utan fokus syns bara
   `›` och platshållaren.
4. **Kreditkapseln** uppe till vänster är A117.
5. **Texten i fältet försvinner** om appen stängs; den sparas inte mellan gångerna (provet som gjordes finns kvar).

## Concerns (CLAUDE.md)
Fri text som läses upp i AirPods, på upprepning i upp till 20 minuter, går att använda för att höra anteckningar
under ett prov. Fältet är byggt för att plugga (D203), och jag har hållit räckena som D203 och CLAUDE.md sätter:
- inget spelas utan att spelaren visas på skärmen;
- "Spelar i AirPods" står överst så länge ljud spelas (i accentfärgen, inte rött: mikrofonen används inte);
- ingen schemaläggning och ingen fördröjd start: uppspelningen börjar bara när man trycker Spela, och upprepningen
  slutar av sig själv när tiden är ute;
- inget i utseendet får appen att se ut som något annat (det mörka fältet är ett fält i appen, med appens namn och
  rubrik kvar på skärmen).
Jag har inte byggt något som döljer uppspelningen. Architect svarar på farhågan i nästa uppdrag.

## Testresultat
- **9 nya tester** i `LumenTests/A115SayInAirPodsTests.swift`: texten läses som den skrevs (ett stycke per rad);
  en fråga per påbörjade 800 tecken; namnet efter de första orden; raden under fältet i alla tre lägen; knapparnas
  ord; Upprepa går runt tills tiden är ute och stannar sedan; En gång läser en gång; en vanlig text går aldrig runt
  av sig själv; Avsluta stoppar upprepningen direkt.
- **iOS build 43975461411 grön** (min gren, cf5bf7b): device-bygget, varningar som fel, LumenTests. *Verifierat i CI.*
  Två byggen före det var röda: ett kompileringsfel (hjälptexterna låg utanför huvudtråden) och tempotestet ovan.
- **Sedd på bild av mig** (simulatorn, inte enhet): Fable screens 43975482836 (iPhone 17 Pro, ljust och mörkt) och
  43975487821 (iPhone SE, största text). `reports/2026-11-16-a115-bilder/`, grenarna `fable/screens-a115-17pro-4`
  och `fable/screens-a115-se-xxxl-4`.
- **Kellys förhandsgranskning** (`reports/2026-11-17-0000-kelly-forhandsgranskning-a115.md`): S1 pricken i
  accentfärg i stället för röd, S2 `›` och platshållaren på samma rad, S3 hårfin kant i mörkt läge. Alla tre gjorda
  och sedda på bild.
- **Inte testat:** att Spela verkligen sparar, startar och spelar mot servern; menyerna (kräver tryck);
  upprepningen med riktigt ljud och låst skärm. Tobys T36. *Untested i appen.*

## Kända brister (största text, iPhone SE)
Sedda på bilden och **inte rättade än**: rubriken och teckenräknaren trängs på samma rad, platshållaren kapas
("Skriv e…"), och "En gång" bryts på tre rader i sin knapp. Rättas i nästa push (med A116).

## I samma push
- **Kellys låga från A112b:** "Förra frågan" är grå på första frågan, och
  startsidan utan prov säger "Fota ditt material. EarMind gör frågor och svar, eller läser upp texten, i dina
  AirPods." (Ke67, sedd på bild).
- "Förra frågan" grå är **inte sedd på bild**: scenen står på fråga 4.
- **A112b är grön på main:** iOS build 43971267275 (cb8bce9). *Verifierat i CI.*

## Nästa session
A116 ("+" tar fil, dokument, bild och länk) och A117 (krediter synliga). Bristerna i största text ovan.
