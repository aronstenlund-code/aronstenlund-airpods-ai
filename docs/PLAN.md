# Plan: struktur för arbetet (Deangelo, 2026-11-09, rättad 2026-11-10)

Planen är regler, inte en lista med punkter. **Ordningen finns bara i köerna** (`prompts/queue/`), målen i faserna nedan. Inget i planen får stoppa arbetet: en session som inte kan ta en punkt tar nästa.

## 1. Prioritet när något nytt kommer in
1. **Blockerare från test** (Toby, Oscar eller Aron på telefon): läggs överst i rätt sessions kö.
2. **Ägarbeslut märkta brådskande.**
3. **Godkända punkter** i köns ordning.
4. **Backlog** (`BACKLOG.md`): flyttas till en kö när Aron godkänner eller när en fas behöver den.

## 2. Flödet
- Byggare (Angela, Kevin, Kelly) gör punkter → testare (Oscar, Toby) får en testpunkt per klar punkt → fynd blir nya punkter hos byggaren (prio 1).
- Beror en punkt på något som inte är klart: hoppa över, ingen väntar.
- Deangelo håller varje kö minst 2 punkter lång utifrån fasens mål, och säger till Aron när en session står still.

## 2b. Ingen står still (Aron 2026-11-09 22:39)
Så många sessioner som möjligt jobbar samtidigt. Är kön tom tar sessionen sin **stående uppgift** och skriver den som en egen punkt i sin kö:
| Session | Stående uppgift |
|---|---|
| Angela | Bygg nästa sak ur Kellys underlag i `docs/design/` (aldrig en egen omdesign vid sidan av). Finns inget: gör appen enklare, färre knappar per skärm, avancerat bakom en rad "Avancerat". |
| Kevin | K4-loopen: kör eval, rätta det sämsta fallet, mät igen. När det finns användare: utgå från deras delade frågor (2d). |
| Kelly | Äger designsystemet (`docs/design/SYSTEM.md`). Granska Angelas och Tobys senaste skärmbilder mot systemet och mot riktiga pluggappar, skriv fynden som underlag. Sedan demosidan. |
| Oscar | Oberoende test av den senaste klara K-punkten som saknar O-punkt, annars väx verklighetsbanken (O15): fler kreativa, felformulerade och verkliga fall. |
| Ryan | Läs annonsresultaten, stäng av det som inte fungerar, skala upp det som gör det, inom budgeten i `docs/ADS.md`. |
| Toby | Omtest av den senaste klara A-punkten med skärmbilder (ljust, mörkt, iPhone SE, största text), annars förstagångsanvändaren i simulatorn. |
Fokus för allt som syns: **lätt att förstå, lätt att komma igång, aldrig överväldigande, en tydlig väg framåt.**

## 2c. Design (Aron 2026-11-10: ska se ut som andra pluggappar, inte som en vibe-kodad app)
- Kelly äger designsystemet, Angela bygger det. Ingen ändrar utseendet utan underlag i `docs/design/`.
- En A-punkt som ändrar utseendet är klar först när skärmbilderna (ljust, mörkt, iPhone SE) finns i rapporten och Kelly har granskat dem.
- Jämförelse: Quizlet, Speak, Duolingo, Apple Anteckningar/Fitness. Det som aldrig får finnas: platshållarbilder, utvecklartext för eleven (licenser, modellnamn, "1.00×"), dubbla negationer, handstil som dekoration, röda knappar utom vid fel, ständiga instruktionsrader.

## 2d. Ägarbeslut och kostnad
- Alla frågor till Aron samlas i `docs/TILL-ARON.md` (Deangelo håller den, kortast möjligt, med "rekommenderar"). Sessionerna skriver "Till Aron" i sina rapporter; Deangelo flyttar dit.
- API-kostnad: varje session skriver kostnaden per punkt på tavlan. Riktmärke **5 USD per dag** i snitt för test och eval; enstaka dagar runt 12 USD är okej (D110). Krediten fylls på varje månad, men aldrig slösa: kör inte om fall som redan är mätta, använd billigaste modellen som räcker, och skriv varför i rapporten när dagen går över.
- **ElevenLabs-krediter (Aron 2026-11-10):** tester får inte slösa på ElevenLabs. Testtal genereras **en gång** och återanvänds från `scripts/qa/audio-cache/` (eller görs med macOS `say` / Apples röster i CI); Scribe används bara när punkten uttryckligen gäller taligenkänning, och då med så kort ljud som möjligt. Skriv antal tecken och Scribe-sekunder i rapporten. I dag gick krediterna slut 08:10, delvis av Deangelos ljudtest.
- **Allt sparas:** varje testkörning sparar rådata (fråga, vad som hördes, svar, tid, modell, kostnad) i `reports/qa/data/` eller `reports/eval/` och pushas. Ljud sparas aldrig i git (artefakter). Inget svar som kostat pengar får försvinna.
- **Riktiga användare tar över testandet:** så fort det finns användare blir deras frågor (bara de som valt att dela historik, D57, utan personuppgifter) den viktigaste testbanken. Kevins och Oscars stående uppgifter börjar då där: hämta veckans delade frågor, gruppera dem, mät de vanligaste och de som gick fel. De påhittade bankerna blir reserv.

## 2e. Kontext i självständigt läge
"Byt snart" stoppar inte arbetet, men efter **två** komprimeringar gör sessionen klart pågående punkt, skriver överlämningen och slutar. Deangelo ger Aron en startprompt när han är tillbaka.

## 3. Verifiering på telefon
- Allt märks verifierat på enhet / i CI / i simulator / ej verifierat.
- Aron kör `docs/DEVICE-TEST-QUICK.md` när han kan. Fynden blir prio 1. Bygget fortsätter under tiden.

## 4. Faser (mål, inte punkter)
| Fas | Mål | Klart när |
|---|---|---|
| 1 | Provläge stabilt på telefon, och appen ser proffsig ut | 20 min Provläge på iPhone + AirPods utan döv mikrofon, "första svaret räcker" enligt Aron, och Aron tycker att de 5 viktigaste skärmarna ser ut som en riktig pluggapp |
| 2 | Pluggfunktionerna (övningsprov, repetition, plan, uttal, länkar) | Alla godkända K/A-punkter för det klara och testade av Oscar/Toby |
| 3 | Inför beta | Developer-konto, TestFlight, integritetspolicy, kostnad per timme mätt, namn beslutat |
| 4 | Beta | 10–20 elever på TestFlight, användning och kostnad mätt |

Faserna överlappar: punkter för nästa fas tas när köns tidigare punkter väntar på något.

## 5. Kontext och sessioner
Varje session byts efter 5 punkter eller en komprimering (`prompts/queue/README.md` punkt 7).

## 6. Datum som inte får missas
| Datum | Vad | Vem |
|---|---|---|
| senast fre 13 nov | Installera om appen, den gamla går ut lör 14 nov | Aron |
| före 3 dec | Anthropic-nyckeln från 3 nov går ut (ej verifierat för nyckeln i Max-kontot) | Deangelo kollar, Aron byter |
| ca 7 dec | `SUPABASE_ACCESS_TOKEN` går ut | Aron förnyar |
