# K113: appen säger `share_history: true` när Dela historik är på (D247)

Angela Schrute (moln, Fable 5.2), 2026-11-20 16:50–17:26. Main, sammanslagning 5a301006 (grenen
`claude/fervent-fermi-34hrer`, 193f0599). 0 ElevenLabs. **Verifierat i CI med en fejkad server. Inte kört mot den
riktiga servern och inte på enhet.**

## 1. Vad som är gjort
Sedan Kevins K113 skriver servern repetitionslägets frågelogg bara för testkonton och för den som delar. Appen säger
nu vem som delar:
- **Dela historik på** (Inställningar › Feedback och förslag, D57): varje sparning av ett prov skickar
  `share_history: true`, på toppnivå i anropet.
- **Dela historik av**, som är förvalet och det en ny installation har: fältet skickas inte alls, och servern loggar
  ingenting.
- Det gäller båda sparanropen: `save`, och `save` med `start: true` (en ny text i Säg i AirPods).
- Reglaget läses vid varje sparning, så en ändring gäller från nästa sparning.

## 2. Tekniska detaljer
- `DrillCloudClient.sharesHistory` är en funktion som svarar ja eller nej; förvalet är nej.
- `DrillCloudClient.sharing(_:on:)` lägger till fältet bara när svaret är ja. Inget annat i anropet ändras.
- `AppContainer` kopplar den till `ShareSettings.isSharing`, samma inställning som delad historik redan använder.

## 3. Avvikelse från Kevins rad
Kevin nämner också `stats`. **Appen skickar ingen tryckstatistik alls** (ingen `stats`-åtgärd finns i `Lumen/`), så
där finns inget att märka. Börjar appen skicka den ska samma fält med.

## 4. Testresultat
- **Testerna skrevs först** (`K113ShareHistoryTests`, fyra stycken) och körde mot klienten med en fejkad server:
  - av: inget fält i `save` eller i `save` med start;
  - på: `true` i båda;
  - reglaget följs vid varje sparning (av → på → av);
  - bara fältet läggs till.
- **CI: iOS build 44766429356 grön** på 193f0599, med alla fyra. Bygget på main efter sammanslagningen körde när
  rapporten skrevs (main hade fått en ändring i samma fil av Angela Fable; sammanslagningen gick utan konflikt).
- **Inte prövat:** att servern verkligen skriver rader när fältet finns och inga när det saknas. Oscar gör omtestet.

## 5. Följder
- **Privacy manifestet är oförändrat.** "Annat användarinnehåll" har kvar syftet Analys: det gäller delad historik
  och lyssnarlägenas logg efter samtycke, och nu också provens frågor för den som delar.
- **Texten under reglaget i appen** säger att egna frågor och svar laddas upp och sparas i högst 12 månader. Den
  nämner inte att nya och ändrade provfrågor nu också skickas (14 dagar, utan koppling till kontot). Orden är Kellys;
  jag har bett henne om dem (Ke85) och lägger in dem när de finns.

## 6. Nästa steg
- Oscar: omtest mot servern (av → inga rader, på → rader).
- Kelly: orden under reglaget.

## Tillägg 18:50: main är grönt
iOS build 44773231144 på main (5a301006) är grön, alla 21 steg, med `K113ShareHistoryTests`. **Verifierat i CI.**
Kelly har skrivit orden för reglaget (`docs/design/texter-integritet.md`); de är inlagda på grenen och byggs.

## Tillägg 18:57: orden för reglaget är på main
Kellys ord (Ke85, `docs/design/texter-integritet.md`) är inlagda ordagrant, sammanslagning c41248e9: texten under reglaget
Dela historik och frågan efter lyssnarsamtycket säger nu båda sakerna med var sin tid (egna frågor och svar högst
12 månader; nya och ändrade provfrågor högst 14 dagar, utan koppling), på svenska och engelska. Ett test läser
svenskan ur den byggda appen (`theWordsSayBothWhatIsSharedAndForHowLong`). iOS build 44782584808 grön på grenen.
**Verifierat i CI, inte sett på bild.**

