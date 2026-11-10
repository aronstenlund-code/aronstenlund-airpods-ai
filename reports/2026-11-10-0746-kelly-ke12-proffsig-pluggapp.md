# Ke12: proffsig pluggapp, designsystem och de 5 viktigaste skärmarna (Kelly, 2026-11-10)

Kort: `docs/design/SYSTEM.md` är det nya designsystemet. Det har ingen handstil och inget rutpapper, en accentfärg,
kort med mjuk skugga och en huvudknapp per skärm. Det innehåller också tre loggförslag och före/efter-skisser för
Intro, Första frågan, Start, Lyssnar och Inställningar, i ljust och mörkt. Angela bygger det i A18.
**Skisser, ingen appkod ändrad, inget provat på telefon.**

## Vad som gjorts
1. **Jämförelse** med Quizlet, Speak, Duolingo och Apple Anteckningar/Fitness (SYSTEM.md §1).
   - Det som gör dem proffsiga är luft, typografi, en accentfärg, en illustrationsstil och inga gimmickar.
   - Jämförelsen bygger på vad jag vet om apparna och är **ej verifierad mot dagens App Store-sidor**. Inga bilder därifrån ligger i repot.
2. **Systemet** (§2–4):
   - Färger: 9 tokens, ljust och mörkt. Rött bara vid fel.
   - Typsnitt: Familjen Grotesk, 8 stilar.
   - Avstånd, hörn, skugga och ikoner (SF Symbols).
   - Komponenter: knappar, kort, brickor, Lyssnar-brickan och listor.
   - Ton i texterna.
   - Rutpappret, handstilen och lägesfärgerna tas bort.
3. **Logga och appikon (U5)**, tre förslag (`bilder/system/logo.png`, `logo/*.svg`):
   - A. Aha-punkten, som jag rekommenderar.
   - B. Bubblan.
   - C. Örat.
   - Inga Apple-lika AirPods (5.2.5), och alla tre fungerar oavsett namn.
4. **Introts hjältebild:** Elias i ett ljust kort, samma som på sidan, i stället för de små grå hörlurarna.
5. **Före/efter** i `docs/design/bilder/system/` (10 bilder plus 2 loggblad). Före-bilderna är A13- och T3-bilderna från
   simulatorn. Allt på Deangelos lista över saker som ska bort är borttaget:
   - röd ring och blå handstil;
   - "Få A-svar till provet";
   - lägescirklar och mikrofoner på provrader;
   - instruktionsrader;
   - licenser (bara under Om Lumen › Licenser);
   - "Provlyssna", "1.00×", "Adam" och "Inget prov just nu";
   - röd Avsluta.
6. Samtycket står kvar under Testa nu ("Testa nu betyder att du godkänner punkterna ovan"), och tummen ned (D57) står
   kvar på svaret.

## Beslut
`docs/DECISIONS.md` "Ke12 (design)": SYSTEM.md ersätter D86:s skollook (rutpapper, handstil, röd penna) i appen.
Demosidan följer i en egen punkt.

## Till Aron
1. **Välj logga:** A (rekommenderas), B eller C. Bild: `docs/design/bilder/system/logo.png`.
2. Röstnamnet "Adam" visas som en beskrivning ("Mansröst, lugn"). Bekräfta att rösten ska beskrivas så.

## Concerns
Inga.

## Nästa
- Angela: A18 enligt SYSTEM.md.
- Kelly: demosidan i samma system, med samma typsnitt, utan handstil och nästan utan rutpapper. Det blir en stående
  punkt (Ke13).
