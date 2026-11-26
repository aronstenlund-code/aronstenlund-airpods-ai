# Ke92: sajten live med Ke91-orden och plan för App Store-förhandsvideon (Kelly (moln))

## 1. Sajten live, samma ord som App Store-sidan och appen
- **Vercel har byggt igen** (produktionen från main, 23:36 UTC). kelly-site-check 45912686338: `/` 200 med 42 237 byte, samma som lokalt; Ke91:s "Press once" och "new audio" är ute. `/sv` och `/beta` svarar 200, och ingen sida rullar i sidled vid 393 px. **Verifierat i Actions.**
- **Ordjämförelse** mot App Store-sidan (`docs/appstore/README.md`) och `ordlista-app.md`. Tre rättelser på `/`:
  - "You control it with taps on your AirPods" → "by pressing your AirPods";
  - "The listening modes (beta)" → "More modes (beta)";
  - lanseringsbandet "65 % off" → "65% off" (engelskt skrivsätt; bandet syns bara under lanseringsveckan).
- Annars stämmer orden: Say in AirPods, Play for 10 min, How should it sound?, Compress, Snap your textbook, Record it yourself – completely free, More modes (beta), 1,500 credits, Weekly pass. På `/sv` är "Lumen, …" kvar i röstexemplen, eftersom väckningsordet är Lumen i appen (Ke91, punkt 2).

## 2. Plan för förhandsvideon: `docs/appstore/preview-plan.md`
- 26 s, 886 × 1920, sju scener ur bildflödet, filmade och inte stillbilder. Text överst, högst sex ord per rad, med Arons mening om aktiveringsordet. Affischbilden vid 5 s är spelkortet.
- Apples krav är **verifierade i Apples dokumentation**: 15–30 s, 886 × 1920, högst 30 bilder/s, bara film ur appen, inga händer, inga priser eller datum.
  Därför är butiken och lanseringsbladet inte med. Videon har inget ljud och ingen röst (D180).
- Inspelningen beskrivs (simctl recordVideo i ett eget flöde och ffmpeg i molnet), men görs först när Aron säger ja.
  **Untested assumption:** att scenerna rör sig utan en testkrok. Skrivandet och Compress behöver troligen en, och den ber jag Fable om då.
- Svenska texter finns i samma fil.

Inget är uppladdat. 0 ElevenLabs.
