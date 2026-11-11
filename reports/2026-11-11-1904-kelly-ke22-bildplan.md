# Kelly Ke22: bildplan och stillbilder för de 7 annonskoncepten (2026-11-11 19:04)

Ryan skrev manusen 2026-11-10 (R1b) och granskade dem 2026-11-11 (C, B4). Kvar för mig var bildplan och stillbilder,
plus att få in Earmind, D121 och Ryans rättelser.

## Vad som gjordes (`docs/marketing/annonser/ke22/`)
- **`bildplan.md`:** per koncept vad som syns och när, all text i bild, säkra ytan (ADS.md 23), testordning
  (K7, K1, K4, K6, K5, K2, K3). Ryans rättelser inarbetade:
  - K1 hook B och hörluren av vid klassrumsdörren (ingen fusk-läsning);
  - K4 ny premiss: frågan ställs mitt i ett samtal utan knapp ("Jag har inte rört telefonen på hela videon"),
    med appens ordagranna svar om fotosyntes;
  - K6 förhör i stället för trivia;
  - K7 timer i stället för kalender tills kalendern är provad på telefon, och kvällsförslaget som ett val;
  - K3 kortad till 12 s.
  Alla slutar med 1 s av den riktiga Start-skärmen och slutbilden. Ingen säger väckningsordet högt (Earmind vs
  "Lumen", D128).
- **`slutbild-earmind.png`** (1080 × 1920): den exakta glasklot-ikonen (D139), "Earmind", "AI i örat. Fungerar med
  AirPods.", "Starta Earmind en gång. Sen finns den i örat." (D121), "Gratis väntelista". Ersätter de fem gamla
  slutbilderna med andra namn.
- **`start-insert.png`:** den riktiga Start-skärmen ur CI 43011221122 i en telefonram med samma mening.
- **`omslag-1.jpg`–`omslag-7.jpg`:** hooken i rätt läge och storlek, etiketten "AI i örat" och en undertext.
  Scenbilden är en platshållare: den kommer från Gemini (Aron genererar). Jag kan inte göra realistiska scenbilder här.

## Till Deangelo och Ryan
- **Cookiebanner och pixlar på sajten** (Ryans B1) blockerar all mätning. Det har aldrig varit en punkt i min kö. Lägg
  den hos mig när Ryan har pixel-ID:n och Aron har sagt ja till kakor, så bygger jag bannern i SYSTEM.md-stil.
- R2 (testplan) kan börja: Ke22 är klar från min sida.

## Till Aron
- Väckningsordet: annonserna undviker att säga det. Blir det "Earmind" kan K4 och K7 få en replik med det.

## Test
Renderat i Chromium (Playwright), 1080 × 1920. Inget genererat i Gemini eller ElevenLabs. Kostnad: API 0 USD,
ElevenLabs 0 tecken.
