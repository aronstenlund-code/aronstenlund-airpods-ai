# A34 och A33: ljudsignaler, och provet med rösten i första starten (Angela, 2026-11-10)

Underlag: D109 och kön. **Allt är kod och enhetstester. Inget är hört eller provat på telefon.**

## A34: ljudsignaler i AirPods (D109)
Lumen spelar tre korta ljud:

| När | Ljud (tills Kelly väljer) |
|---|---|
| Lumen börjar lyssna (start, eller fortsätter efter en paus) | en kort ton, 880 Hz i 0,07 s |
| Lumen slutar lyssna (Avsluta, Pausa) | en lägre ton, 587 Hz i 0,09 s |
| Lumen hörde tal men valde att vara tyst (Standardläge, "inte en fråga") | ett mjukt "hm", 330 Hz i 0,12 s |

- **Var ljuden spelas:** bara i hörlurar. När ljudet går ut ur iPhonens egen högtalare spelas inget, eftersom mikrofonen
  då skulle höra tonen och den kunde nå ekofiltret eller VAD.
- **Kostnad:** tonerna görs lokalt i uppspelningsgrafen (`playTestTone`). Det blir inga nya anrop.
- **Av och på:** brytaren heter "Ljud när Lumen börjar och slutar lyssna" och finns under Inställningar ›
  Röstkommandon, bredvid tonen för "mer". Den är på från början.
- **Loggen:** varje ljud loggas som "Cue: start/stop/hm (A34)".
- **Till Kelly:** välj ljudens karaktär i SYSTEM.md. Tonerna är platshållare. Volymen är densamma som för
  "mer"-tonen (0,3), och det är en **untested assumption** att den är diskret nog.
- **Tester:** `A34Tests`. Start och stopp hörs, start hörs en gång per start, och brytaren stänger av dem.
- **CI:** grönt, iOS build 42819081919 (`7643474`).

## A33: kom igång med rösten (D109)
1. När det första svaret i första starten är uppläst och Lumen är tyst i 1,5 s går första starten vidare av sig själv
   till "Har du prov snart?". Kommer en ny fråga under tiden väntar den på svaret.
2. Lumen frågar högt: **"Har du prov snart? Säg vilket ämne och när."** och lyssnar.
3. Det korta svaret tolkas både på telefonen och av `/study-profile` (D84). Exempel: "biologi på fredag" eller "ja,
   matte nästa tisdag".
   - Svaret skrivs om till "jag har prov i …" och går samma väg som "Lumen, jag har prov i …".
   - Med ämne och datum sparas provet, och sidan stängs.
4. "Nej", "inte nu" och "jag har inget prov" fungerar som "Inte nu". Lumen säger "Okej. Du kan lägga till ett prov på
   Start när du vill."
5. Svaret blir aldrig en vanlig fråga till Lumen, eftersom turen kastas efteråt.
6. **Formuläret finns kvar som reserv.** Det ligger bakom "Skriv i stället" och har A22:s rad med områden, datum och
   årskurs. "Spara prov" syns först när formuläret visas.

- **Kod:**
  - `ExamAnswer` (`ProfileStatement.swift`);
  - `ListeningModel.askAboutExamByVoice` och `examQuestionDeclined`;
  - `AddExamView` (`showsForm`);
  - `FirstQuestionView` (går vidare efter svaret).
- **Tester:** `A33Tests` med nej-svar, korta svar som blir påståenden, och att "biologi på fredag" ger ämne och datum.

### Till Toby (T8)
- Första starten går vidare av sig själv efter första svaret. Testet behöver inte trycka på "Fortsätt", men knappen
  finns kvar.
- Provsidan visar inte formuläret förrän man trycker "Skriv i stället".
- Svara med en ljudfil, till exempel "biologi på fredag" eller "nej".

### Till Kelly
Se över bilden av provsidan. Den har nu rösten först och "Skriv i stället". Ta en ny skärmbild med scenen `addExamFirst`.

## Kända begränsningar
- **Untested assumption:** att 1,5 s efter svaret känns rätt. Säger eleven något direkt efter svaret blir det en ny
  fråga, och då väntar första starten.
- Säger eleven bara ett ämne utan datum sparas inget prov. Provet kommer då till profilen men inte till Start. Sidan
  står kvar, och formuläret finns där.

## CI
A33: grönt i CI, iOS build 42821993253 (`95c50e0`). Bygget för enhet räknar varningar som fel, och alla LumenTests är gröna.
