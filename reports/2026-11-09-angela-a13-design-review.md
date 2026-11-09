# A13 – Designgranskning (Angela, 2026-11-09)

Kort: alla sju punkter är byggda. Grönt i CI (körning 42693453845). Efter-bilderna kommer från mitt
skärmbildsflöde (iPhone SE och iPhone 17 Pro, ljust och mörkt).
**Ej verifierat på enhet.**

## Vad som ändrades
1. **Inställningar: Vanliga, Avancerat och Om appen.** Inga funktioner togs bort.
   - **Vanliga, högst upp:**
     - Röst och hastighet;
     - Svarslängd;
     - Röstkommandon och Minne;
     - Prov (profilen);
     - Utseende och Språk;
     - Integritet och samtycke.
   - **Mer:** Anteckningar, Historik, Studiekort, Förberedelser, Egna kommandon, Provsession, Feedback och förslag,
     och **Om appen**.
   - **Avancerat**, hopfällt längst ner (valet sparas):
     - Mikrofon och känslighet;
     - Taligenkänning (Scribe, lokal röstdetektor, bara min röst);
     - pauser, Provläge, Rizz-nivå och kalibrering;
     - röstprofil;
     - Diagnostik.
   - **Om appen:** licenserna och de tekniska förklaringarna (WeSpeaker, pyannote, Silero, FluidAudio, Spotify-SDK,
     typsnitt). Licenstexten i röstprofilen hänvisar dit.
   - Röstprofilens text sa fortfarande "Auto svarar inte på dina egna ord", vilket inte gäller sedan A8. Det är
     rättat.
   - Spotify-SDK:n står nu i `THIRD_PARTY_NOTICES.md` som undantag från MIT/Apache/BSD-regeln, eftersom uppdraget
     A6 valde den.
2. **Nivåmätare på Lyssnar.**
   - Fem små staplar i appens blå, till höger om "Lyssnar". De följer mikrofonen mellan −60 och −15 dBFS.
   - Stilla när ingen igenkänning går. Då står A11:s "Hör inte, försöker igen".
   - Utan animation med "Reducera rörelse".
3. **Tomt läge i Provläge:**
   - provets ämnesord som chips (högst 8);
   - knappen **Förhör mig**, som är samma sak som "Lumen, förhör mig";
   - **alla** tidigare frågor och svar i passet, nyaste först. Förut syntes bara det senaste.
4. **Flera prov på Start.** Det fungerade redan: `upcoming()` sorterar på datum, det närmaste visas som stort kort och
   resten som rader under. Kontrollerat i koden, så jag byggde inget nytt.
5. **Start (ägarbeslut):**
   - Frågor och Provläge visas på Start.
   - Intervju, Socialt och Rizz 18+ ligger under **Fler lägen** (öppnas på plats, valet sparas).
   - Röstkommandona är oförändrade.
6. **`IntroHeroView`:**
   - Rutpapper och Elias som frilagd PNG (`Assets.xcassets/IntroElias`) när bilden finns. Till dess en platshållare
     (hörluren).
   - Ringarna ritas i SwiftUI och sprids tre gånger från `IntroHeroView.ringOrigin`, ett justerbart värde (andel av
     ytan). Med "Reducera rörelse" står de still.
   - Videoloopen finns inte.
   - **Aron:** lägg den godkända bilden i `IntroElias` (högst 300 kB @3x, mörk variant om kanten syns) och justera
     `ringOrigin` till hörluren.
7. **Skärmbilder:** se nedan.

## Skärmbilder före och efter (iPhone SE och Pro, ljust och mörkt)
**Var bilderna kommer från:**
- **Efter:** `reports/2026-11-09-a13-skarmbilder/`, från mitt skärmbildsflöde (simulator, demodata).
  - iPhone SE: körning 42697414257.
  - iPhone 17 Pro: körning 42697509079.
- **Före:** Tobys T3 i `reports/apptest/2026-11-09-t3-skarmbilder/pro-light/` och `pro-dark/`.
- Tobys skärmrunda på A13 (42693453684) avbröts innan den tog bilder.

| Skärm | Före (T3) | Efter (SE / Pro, ljust och mörkt) | Vad som syns |
|---|---|---|---|
| Inställningar | `pro-light-15-installningar-1.png` … `-20-installningar-6.png` (sex sidor: mikrofon per läge, Scribe, dB-reglage överst) | `efter-se-light-settings.png`, `efter-pro-dark-settings.png` … | Röst och hastighet, Svarslängd, Röstkommandon och Minne överst. Det tekniska ligger under Avancerat. |
| Om appen | finns inte | `efter-*-about.png` | Licenserna och vad varje del gör. |
| Start | `pro-light-13-start-med-prov.png` (fyra cirklar) | `efter-se-light-home.png`, `efter-pro-*-home.png` | Flera prov sorterade på datum (Biologi stort, Engelska och Historia under). Frågor och Provläge som cirklar. Fler lägen ligger nedanför (syns på Pro). |
| Lyssnar | `pro-light-09-lyssnar-efter-forsta-start.png` | `efter-*-listening.png` | Nivåmätaren till höger om tillståndet (grå när inget hörs) och tidigare frågor och svar under det senaste. |
| Intro | `pro-light-01-intro.png` | `efter-*-intro.png` | `IntroHeroView` med platshållare. Bilden togs när ringarna redan hade tonat bort. Efter rättningen i den här commiten vilar de synliga som i loggan. |

**Inte fotat:**
- Provlägets tomma läge med ämneschips och "Förhör mig". Skärmbildsscenen visar Frågor.
- "Fler lägen" utfällt.
- "Säg ja för mer" (A15).

Toby får gärna ta dem i nästa T3.

## Till Toby (skärmrundan behöver uppdateras)
**Inställningar har ändrats:**
- "History" heter "Historik".
- "Feedback & suggestions" heter "Feedback och förslag".
- "Rå transkription och svar" och "Diagnostik" ligger under **Avancerat**: tryck "Avancerat" först.
- "Integritet och samtycke" ligger högt upp.
- "Om appen" är ny under Mer.

**Start:**
- Fyra cirklar har blivit Frågor och Provläge.
- Intervju, Socialt och Rizz nås via **Fler lägen**.

**Lyssnar:** i Provläge finns ämneschips och knappen **Förhör mig** innan första svaret.

Kör gärna om T3 med de nya stegen.

## Concerns
Inga.
