# Ke80: App Store-produktsidan klar (Kelly (moln), 2026-11-18, D232, TILL-ARON #27)

**Inget är uppladdat eller publicerat.** Allt ligger i `docs/appstore/` för Aron att lägga in efter sitt ja.
0 ElevenLabs (bara demodata i Simulatorn).

## Vad som gjordes
1. **Eget bildflöde** `.github/workflows/kelly-appstore-shots.yml`: samma steg som Angela Fables "Fable screens", men på
   **iPhone 17 Pro Max**, bara ljust, **utan nedskalning och komprimering**, och appen startas med `-say.hasPlayed YES`
   så att raden "Du kan låsa telefonen …" (D209, inte provad på telefon) inte syns. **En macOS-maskin per körning** (D217).
   Fables flöde är orört. Körning **44309786844** (main 97a0286): 9 bilder, alla **1320 × 2868** (verifierat med
   `sips` i flödet och PIL här), grenen `kelly/appstore-shots-ke80`.
2. **7 App Store-bilder** `docs/appstore/69-1..7.jpg` (1320 × 2868) med `appstore.py`: Skriv. Lyssna. · Om och om igen. ·
   Hur ska det låta? · Spela igen. · Fota boken. · Tryck för svaret. · Börja gratis. Rubrikerna i Inter Display (finns i
   molnet, nära SF Pro Display); oförändrade skärmbilder i en enkel ram.
3. **Alla texter** i `docs/appstore/README.md`: namn **EarMind** (7), undertitel **Lyssna och plugga i hörlurarna** (30),
   reklamtext (127/170), beskrivning (1 862/4 000, med röster, Hur ska det låta?, välkomstkrediter och inbjudan),
   nyckelord (99/100), support- och marknadsförings-URL earmind.vercel.app, integritets-URL /integritet och villkor
   /villkor i beskrivningen (krav för prenumeration, 3.1.2; **Ke78 inte publicerad**), kategori, åldersgräns **13+**.
4. **Kontrollen** (README §5): varje påstående mot `granskning.md` och main, märkt [V]/[S]/[L]/[O]. Låst skärm, "andra
   hörlurar" och "fungerar utan nät" står **inte** i texten. `granskning.md` §1 pekar nu på README.

## Strykt och flaggat
- **Bilden av bladet Röst är struken:** scenen `repSayVoices` visar "Att provlyssna" med en röst under granskning
  ("Hindi"), som bara admin ser. En App Store-bild får inte visa det vanliga användare inte har. Angela Fable ombedd om en
  scen utan avsnittet; bilden läggs då in som nr 4.
- **Bild 7** visar priserna från låtsasbutiken ("10,00 kr", "79,00 kr"). Riktiga priser kommer från App Store Connect;
  ändras de: ta om bilden.
- **Åldersgräns 13+** är ett förslag (**untested assumption**): Rizzläget (milda flirtförslag, D112) och AI-innehåll.
  Aron svarar ärligt i Apples formulär.

## Före inskickning (till Aron/Deangelo)
1. Ke78 publicerad (länkarna i beskrivningen och integritets-URL:en).
2. Produkterna i App Store Connect och med i bygget (annars ser granskaren "Paketen kunde inte hämtas …").
3. Ändras en skärm: kör flödet igen och `appstore.py` (kommandon sist i README).

## Test
Bildstorlek kontrollerad (7 × 1320 × 2868). Bilderna granskade som bild här (sett i Simulatorn, **inte på telefon**).
Teckenantal räknade med Python.
