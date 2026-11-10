# A41 + A39, A42 och A35: samtycket stämmer, provet bara på Start, färre spärrar (Angela, 2026-11-10)

Underlag:
- `reports/2026-11-10-1300-deangelo-granskning-appen.md`, fynden G1, G2 och G4;
- besluten D112, D113 och D116;
- `docs/RESTRIKTIONER.md`, raderna A4, A5 och B5.

**Allt är kod och enhetstester. Inget är provat på telefon.**

## A41 + A39: samtyckestexten (G1, D116)
Samtyckessidan (`ConsentView`) är nu skriven på svenska, i introts ton och med systemets typsnitt och färger. Den
används vid samtycke, under "Läs mer" och under Integritet och samtycke.

| Punkt | Text i korthet | Förut |
|---|---|---|
| Inledning | "Lumen är en pluggkompis som lyssnar genom dina AirPods …" | "lyssnarkompis för föreläsningar, möten" |
| Lyssnar bara när du startat | En **blå** lyssnarbricka och iOS mikrofonsymbol | "en röd indikator" |
| Talet skrivs ut av ElevenLabs | Ljudet till ElevenLabs, och svaren läses upp med en röst därifrån. Lumen sparar aldrig ljud. | Rösten nämndes inte |
| Svaren kommer från Claude | Via Lumens server till Claude från Anthropic | Samma |
| **Frågor och svar skickas till oss** | A39:s text: "Dina frågor och Lumens svar skickas till oss så att vi kan göra Lumen bättre. Ljud sparas aldrig, och texten raderas när vi har läst den." | "Att dela historik är avstängt" |
| **Andras ord kan också komma med** | I Standardläge skrivs lärarens fråga ut och skickas på samma sätt. Berätta det för dem runt dig, och använd inte Lumen på prov. | "Andra personers tal skickas aldrig" |
| Historik på telefonen | Högst två år, och kan raderas i Inställningar | Samma |
| Du kan sluta när du vill | Ta tillbaka samtycket | Samma |

- **Samtyckets version är nu 5.** Den som har samtyckt till den gamla texten får se den nya innan nästa pass, eftersom
  innehållet har ändrats på riktigt (ARCHITECTURE §12).
- **Introt** (som är samtyckessteget i första starten) har fått en fjärde punkt: "Frågor och svar skickas till oss".
  Då står D116 där man trycker Testa nu. "Läs mer" står på en egen rad under punkterna och heter fortfarande "Läs mer",
  eftersom Tobys skärmtur letar efter just det ordet.
- **Om appen** säger samma sak som D116 och nämner Historiken på telefonen. Raden från A27 om "Dela historik" är borta,
  eftersom D116 ersätter D57 för det här syftet.
- **Kevin (K30) bekräftar det tekniska.** Hans K30 säger "senast efter 14 dagar". Texten säger "när vi har läst den",
  vilket är A39:s ord. Kevin och Aron kan lägga till "eller efter 14 dagar".

## A42: provet bara på Start (G2, G4)
- **Inställningarna:** provdatum, årskurs, kurs och ämne är borttagna ur Inställningar. Avsnittet heter nu "Förhör och
  förklaringar" och säger var provet ändras.
- **Provkortet på Start:** knappen **"Ändra"** öppnar provet i formuläret (`AddExamView` med `editing`). Datumet visas
  därför i samma format överallt.
- **Andra prov:** de har "Ändra provet" i menyn som öppnas med en lång tryckning.
- **Översättningen:** "Using the iPhone's speech recognition: …" heter nu "Använder iPhonens taligenkänning: …".

## A35: färre spärrar (D112, D113)
- **18+-spärren är borta (A4).** `ModeSettings.isAdultConfirmed` är alltid sant. Åldersfrågan visas därför aldrig, och
  Rizzläget kan väljas, kommas ihåg och startas med rösten som alla andra lägen. Knappen heter "Rizz", utan "18+".
  - Flaggan `adult_confirmed` skickas fortfarande med flirtstilen, så servern behöver inte ändras.
  - Koden för `AgeGateView` finns kvar men används inte. Den kan tas bort när ingen behöver den längre.
- **Skyddsnätet för minnen (A5, B5)** stoppar nu bara tre saker:
  - hälsa;
  - kris;
  - ID-nummer, alltså personnummer, kontonummer, kortnummer och lösenord.

  Religion, politik, relationer, ursprung, var man bor och kontaktuppgifter stoppas inte längre i kod (A27 är alltså
  delvis tillbakatagen). Studieorden från A27 finns kvar, så "Läser om psykisk ohälsa i samhällskunskap" sparas.
- **Untested assumption:** att "ID-nummer" i B5 också omfattar lösenord och kontonummer. Jag har tagit med dem, eftersom
  ett minne skickas med varje fråga till servern. Säg till om de ska bort.

## Tester
Ändrade tester:

| Fil | Vad den kontrollerar nu |
|---|---|
| `A27Tests` | 14 fall stoppas (hälsa, kris och ID). 9 fall som stoppades förut släpps nu igenom, och 22 vanliga studieminnen släpps också igenom. |
| `AnswerAheadTests` | "Röstar på Moderaterna" stoppas inte längre. |
| `ActivationControllerTests` | Rizz kommer ihåg sitt läge som alla andra lägen. |
| `ModeTests` | Rizz har ingen åldersfråga. |
| `VoiceChannelTests` | "byt till rizzläge" säger inget om 18 år. |

## Till Kelly
- På demosidan: ta bort "18+" och texter om åldersgräns för Rizz (D112).
- Introt har fått en fjärde rad, "Frågor och svar skickas till oss". Bilderna av introt behöver tas om.

## Till Toby
- Skärmturen letar efter "Rizz 18+", men knappen heter nu "Rizz". Åldersfrågan (`rizz-aldersgrans`) finns inte längre.
- Samtyckessidan är på svenska. Knappen heter "Jag förstår, starta Lumen".

## Till Aron
- Samtycket visas en gång till för dig, eftersom texten nu säger att frågor och svar skickas till oss (D116).

## CI
Grönt i CI: iOS build 42811094899 (`2783edc`). Bygget för enhet räknar varningar som fel, och alla LumenTests är gröna.
