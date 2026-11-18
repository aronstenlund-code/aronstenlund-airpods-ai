# Tobys T48-fynd, T50 ihop med Kevin, och bilder till Kelly (Angela Fable, moln)

Klart 2026-11-18 09:28. **Verifierat i CI: iOS build 44263906468 grön på min gren (enhetsbygge, varningar som fel,
LumenTests), och sett på bild i Simulatorn med låtsasdata. Inte provat mot servern eller App Store, och inte på
enhet.** 0 ElevenLabs.

## T48: Krediter-bladet utan produkter, och Återställ köp utan svar
1. **Inga produkter från App Store:** bladet visade ingenting där paketen skulle stå. Nu står avsnittet Fyll på
   kvar med raden "Paketen kunde inte hämtas från App Store just nu." och knappen **Försök igen**, som frågar App
   Store igen. Raden visas först när App Store har svarat tomt, inte medan bladet laddar. (Orden är Tobys förslag;
   Kelly granskar.) **Så ser bladet ut för Aron i dag**, eftersom produkterna inte finns i App Store Connect än.
2. **Återställ köp snurrade utan slut** i en Simulator utan Apple-konto: App Store svarade aldrig. Nu väntar knappen
   högst 15 sekunder och säger sedan "Det gick inte att hämta köpen just nu. Försök igen om en stund." Kommer svaret
   senare lämnas köpen ändå till servern.
3. **Sällsynt (1 körning av 7): ett tryck på texten på kortet öppnade inte spelaren.** Inte återskapat och inte
   rättat. Jag ser ingen orsak i koden; behöver en körning till där det händer, med loggen.

## T50: "Kolla nätet" när nätet var uppe
- **Appens del är rättad och på main sedan 07:35** (`reports/2026-11-18-0735-angela-fable-t50-langsam-server.md`):
  ett andra tryck på Spela väntar på det första tryckets svar, och raden säger "Det tar längre tid än vanligt." när
  nätet är uppe (Kellys ord).
- **Inte avgjort: varför servern ibland inte svarar inom 10 sekunder.** Jag har skickat Kevin vilka anrop appen gör
  (save, sedan start) och Tobys tre körningar med tider, och bett om tiderna ur loggen. Inget svar när detta skrevs.
  Min gissning (kallstart, eller taggarna som läggs vid sparning med stil) är obekräftad.
- Så länge det är oklart kan raden komma vid första Spela på en ny text. Om 10 sekunder ska ändras är Deangelos
  beslut (D219.3), när Kevin har tiderna.

## Bilder till Kelly
`reports/2026-11-18-granskning-bilder/` (Simulatorn, flödena 44263836923 och 44263842346):
- `a133-a135-a139.jpg`: Obegränsat (A133) · "Det tar längre tid än vanligt." med Försök igen · "Ljudet kunde inte
  hämtas. Kolla nätet." (A135) · korta tal: "5,3k krediter kvar" och "1,3k krediter" (A139).
- `a136-a140-t48.jpg`: Senaste · AI:s val "Vald efter stilen · …" (A140) · bladet utan produkter (T48) ·
  "Spelar i AirPods · Astrid".
- `se-storsta-text.jpg`: iPhone SE med största text: bladet Röst, raden efter 10 sekunder, bladet utan produkter.
- A141 (välkomstkrediter, inbjudan) och A136/A140 i övrigt finns sedan i natt i `reports/2026-11-18-a140-bilder/`
  och `reports/2026-11-17-a136-bilder/`; Kelly har godkänt dem.
- **Saknas på bild:** Senaste-kapselns tillägg ("· Lugnt"). Kapseln med stil hamnade utanför skärmen; scenen är
  omordnad och körs om. A135:s "Ljudet hämtas när du startar" och tangentbordets förslag finns inte på bild.

## Tester
`LumenTests/A134ShopTests.swift`: utan produkter säger bladet det först när App Store har svarat, och Försök igen
hämtar dem; Återställ köp svarar även när App Store aldrig gör det.

## Otestat (antaganden)
- Att App Store verkligen svarar tomt (och inte med fel) när produkterna saknas i App Store Connect; båda fallen
  ger samma rad.
- Att 15 sekunder är rätt väntan för Återställ köp på en riktig telefon med Apple-konto.
