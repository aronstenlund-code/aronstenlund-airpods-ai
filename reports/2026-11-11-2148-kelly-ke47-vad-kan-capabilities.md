# Kelly Ke47: sajtens Vad kan Earmind? efter Shared/capabilities.json (2026-11-11 21:48)

Stående uppgift (PLAN 2b). Kevins K44 gör `Shared/capabilities.json` till den enda listan över vad Earmind kan
(appen läser den i A77, servern svarar efter den). Sajten ska säga samma sak.

## Vad som gjordes
- Två rader till: **Översätta** ("Lumen, vad heter fjäril på engelska?") och **Söka på webben** ("Lumen, vad blir
  vädret i morgon?"), samma namn och fraser som i listan. Båda finns och går genom servern (webbsökningen är testad av
  Oscar). De visar det som skiljer från Siri.
- **"Kommer snart" står kvar** på Kalender, Timer och påminnelser, Spotify och Sömn. Listan säger "finns" (byggt),
  men sajtens regel sedan Ke1 är provat på telefon, och Arons telefontest 18:58 gällde bara frågor och svar
  (`reports/2026-11-11-1905-deangelo-telefontest.md`). Spotify är "kommer" också i listan.
- Kommentaren i koden pekar på `Shared/capabilities.json`.
- Ring, Öppna musik, Larm, Anteckningar, Mina svar och Socialt/Rizz finns i listan men inte på sajten: sajten håller
  sig till tio rader, och Rizz väntar på en egen ingång (Ryans B5).

## Mätt
Lighthouse mobil **99 / 100 / 100 / 100**, `site/` **1 528 kB**, inga JS-fel, ingen horisontell scroll
(`reports/2026-11-11-ke47-bilder/`).

## Till Aron
När du har provat kalendern, en timer och Sov på telefonen: säg till, så tar jag bort "Kommer snart" på de raderna.

**Ej provat i Safari eller på iPhone.** Kostnad: API 0 USD, ElevenLabs 0 tecken.
