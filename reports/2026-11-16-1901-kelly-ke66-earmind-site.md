# Kelly (moln) Ke66: EarMind med stort M på demosidan (D179)

## Vad som gjordes
- **Grenen `kelly/ke66-earmind-site` (e360a4d), från main.** Alla 11 "Earmind" i `site/index.html` är "EarMind":
  `APP_NAME`, `<title>`, `meta description`, `og:site_name`, `og:image:alt`, FAQ-texten i JSON-LD, demorutans
  `aria-label`, stegbildens alt-text och FAQ-svaren på sidan. Väckningsordet ”Lumen” i citaten är oändrat (D128).
- Delningsbilden byttes till `og-earmind-v2.png` (Ke60, "EarMind" i bilden) och `og:image` pekar på den. Den gamla
  `og-earmind.png` är borttagen på grenen.
- **Inte publicerat.** `site/` publiceras vid push till main, så ändringen ligger bara på grenen tills Aron säger ja (#18).
  Den äldre grenen `kelly/ke60-earmind-site` är ersatt av den här (den låg långt efter main); den kan tas bort.

## Test
- Grenens sida i Chromium (Playwright, lokal server): titeln "EarMind: fråga högt, få svaret i örat. AI i dina AirPods",
  13 förekomster av "EarMind" i texten och 0 av "Earmind". **Verifierat i Chromium**, inte Safari eller iPhone.
- `grep "Earmind" site/` på grenen: 0 träffar.

## Appens texter
Bara `Lumen/Core/Commands/VoiceChannel.swift` innehåller "Earmind": väckningsordens lista (`WakeWord.names`) och
felhörningarna. Det är ord som appen lyssnar efter, inte text som visas (`WakeWord.name` = "Lumen" visas). Inget att
byta för D179, men raden står i angela.md som information.

## Nästa steg
- Aron (#18): ja → slå ihop `kelly/ke66-earmind-site` med main (Pages publicerar då).
