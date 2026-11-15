# Kelly Ke62: App Store-bilderna och demosidans utkast från dagens bygge

Roll: Kelly Kapoor (design, lokal session). Uppdrag: `prompts/queue/kelly.md` Ke62 (Deangelo på Arons uppdrag). **Inget publicerat.**

## Vad som gjordes
- **Bygge:** senaste gröna iOS-bygget är **43645181127 (09885ad)**. Appkoden (`Lumen/`, `Shared/`) är oförändrad mellan
  09885ad och main 51f6a03 (`git log 09885ad..origin/main -- Lumen Shared` är tom). Därför tog jag skärmbilderna från main.
- **Skärmbilder:** CI "Simulator screenshots" **43664022683** på **iPhone 17 Pro Max**, `screens: rep`, grön. Alla bilder
  är exakt 1320 × 2868. De visar EarMind med stort M, A87 i hela appen, A88/A89 (årskurs, ingen svarslängd), A93 (Gör med
  ChatGPT i Material), A99/A100 och förhandsvisningen.
- **`docs/appstore/69-1.jpg` … `69-5.jpg`** är omgjorda ur de bilderna (Fota materialet, Frågor med A-svar, Starta prov,
  Tryck för svaret, Dela med klassen / Prov från din skola). Kontrollerat: appens text i bild 2 lyder "… gratis
  EarMind-konto".
- **Demosidans utkast** (`drafts/site-repetition/img/`): Hem, Nytt prov, frågelistan och första frågan, ljust och mörkt,
  ur samma körning.
- **App Store-texten granskad mot appen i dag** (`docs/appstore/README.md`): repetitionsläget först och de lyssnande lägena
  som BETA stämde redan. Beskrivningen har nu det som finns i dag: Gör med ChatGPT, årskurs, språkprov på sitt språk, röst
  och tempo, Dela när ljudet är klart, Publicera prov och Prov från din skola, hjälpen Fråga om EarMind och gränsen "15 nya
  frågor med ljud per månad ingår" (D155). "Andra Bluetooth-hörlurar" är struket (inte provat). 2 052 av 4 000 tecken.
  Tabellen "Måste stämma" har fått två rader (gränsen och de nya funktionerna, provade i simulatorn men inte på telefon).

## Kvar
- Rubrikerna i App Store-bilderna är Segoe UI. Gör om dem med SF Pro Display på en Mac före inskickning.
- Integritetspolicy, åldersgräns och integritetsetiketter. Publicering bara efter Arons ja.
- **Till Angela (låg):** `VoiceChannel.swift` har `names = ["Lumen", "Earmind"]`, och kommentaren säger att `name` är det
  appen "says and shows". Visas namnet någonstans ska det vara "EarMind" (D179). Jämförelsen av väckningsordet ändras inte.
- A104-bilderna (Angela Fable) har inte kommit. De granskas av Kelly (moln).

## Test
Bilderna är kontrollerade i kontaktblad och i en förstoring av bild 2. Inget är provat på telefon.
