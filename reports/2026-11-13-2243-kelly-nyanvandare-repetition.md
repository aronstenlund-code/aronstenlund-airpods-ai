# Kelly: repetitionsflödet som ny användare, plus A85, A86 och A83

Datum: 2026-11-13 22:43. Roll: Kelly Kapoor (design). Uppdrag från Aron: granska A85, A86 och A83 mot designen och gå
igenom hela repetitionsflödet som en ny användare.

## Vilka bilder
- **43505582385** (4623bc7) är ett iOS-bygge **utan skärmbilder** (artefakterna är build-logs, xcodeproj och ipa).
  Skärmbilderna för samma kod kommer från **"Simulator screenshots" 43508671912** (1363518, efter 4623bc7, grön).
  Genomgången nedan bygger på dem: 13 scener i ljust och mörkt, kontaktblad i
  `reports/2026-11-13-nyanvandare-bilder/` (`l0.jpg`, `l1.jpg`, i flödets ordning).
- Bilderna kommer **före** Angelas 270b0a0 (B1–B5 efter min A82-granskning) och dbfa91f (A85/A86). Därför syns B1
  och B2 fortfarande här. **B3 (ringen visar 6) och B4 (kontrollen börjar på steg 1 med "Väntar …") är stängda på bild.**

## A85, A86 och A83
| Punkt | Läge | Bedömning |
|---|---|---|
| **A86** "Kom förberedd till provet" | dbfa91f, granskad i koden (ingen bild än) | **Godkänd i koden:** rubriken på Hem utan prov är bytt. Ingressen ("Fota ditt material …") och knappen Nytt prov är oförändrade. Mina `repetition-texter.md`, `repetition.md` och skisserna `hem-tom`/`pub-hem` är uppdaterade. Bekräftas på bild. |
| **A85** felet "Ingen internetanslutning" | dbfa91f, granskad i koden | **Godkänd i koden:** "Ingen internetanslutning" bara när `NWPathMonitor` saknar nät, annars "Det gick inte att skapa frågorna. Försök igen." med knappen **Försök igen** (bara när material finns). Texten står nu i `repetition-texter.md` §13. Felet syns inte i någon scen. **Till Angela:** lägg till scenen `repMakeError`. |
| **A83** Publicera prov | Inte byggd (`- [ ]` i kön, ingen commit) | Inget att granska. Underlaget är `docs/design/publicera-prov.md` (Ke52). |

## Ny användare: det som är otydligt
Jag läste skärmarna i ordning, som någon som just laddat ner appen och aldrig sett den förut.

| # | Skärm | Vad en ny användare inte förstår | Förslag (text att kopiera) | Nivå |
|---|---|---|---|---|
| N1 | Uppspelningen, Tänk (`repPlayThink`) | **Svaret kommer bara om man trycker.** Utan tryck går appen vidare till nästa fråga efter betänketiden. En ny användare väntar på svaret, hör en ny fråga och tror att appen hoppade över eller är trasig. Raden ● Långt svar … är liten och grå. | **Första varvet i första provet:** under ringen står "Tryck på AirPods för svaret", och efter betänketiden säger rösten en gång "Tryck en gång för svaret." Från varv 2, eller efter första trycket, visas bara den tysta raden. Ingen ny ljudkostnad om meningen är en fast fil i appen. | **Hög** |
| N2 | Kontrollskärmen (`repControls`) | En fråga börjar plötsligt spelas i örat (D147 punkt 5), och ingenting förklarar varför. | Raden under rubriken (Ke50 §7): "Frågan spelas en gång så att trycken kommer fram." | Medel |
| N3 | Nytt prov (`repMaterial`) | **Skapa frågor** är grå, men det står inte varför. | Under den grå knappen: "Lägg till minst en sida, bild eller text." Raden försvinner när något är tillagt. | Medel |
| N4 | Välj läge (`moreModes`) | "Valet gäller **Starta-knappen**." Det finns nu två Starta-knappar (Starta prov och Starta Earmind). "Provläge" ligger bredvid Starta prov fast det är något annat. | Fotnot: "Valet gäller Starta Earmind. Starta prov använder aldrig mikrofonen." Provläge får raden "Förhör med rösten" i stället för "För dina prov" (spec §1: det gamla röstförhöret heter Förhör med rösten). | Medel |
| N5 | Hem utan prov (`repHomeEmpty`) | Sju saker under varandra: kortet, länken, FLER LÄGEN, tipset "Här startar du Earmind", Starta Earmind, Standardläge · Byt och Earmind kan allt. Det är svårt att se vad man ska göra. | B2 (rättad i 270b0a0 enligt Angela): bara kortet, länken och raden Fler lägen [BETA]. **Bekräftas på nästa bild.** | (B2) |
| N6 | Fortsätt där du var? (`repResume`) | "fråga 7 av 5" | B1 (rättad i 270b0a0). Bekräftas på nästa bild. | (B1) |
| N7 | Hem (`repHome`, `repHomeEmpty`) | Flamman "3" uppe till höger förklaras inte. Den nya användaren har inte pluggat i 3 dagar. | Visa den först efter första passet. VoiceOver: "3 dagar i rad". | Låg |
| N8 | Frågelistan (`repList`) | Ingen väg tillbaka (inget "‹ Hem" uppe till vänster) i scenen, och ingen Dela-rad i bild. | Kontrollera att listan ligger i navigationsstacken med Hem. B5: scen med Dela. | Låg |
| N9 | Hem, Earmind kan allt | Appen heter Earmind, men man säger "Lumen". | Känt och väntar på Aron (väckningsordet, HANDOVER-KELLY). Ingen ändring nu. | Låg |

**Det som är tydligt** (behåll): materialets fyra rutor och fotnoten om att material inte sparas, "Ljud klart" med
bock, raden om att Starta prov inte använder mikrofonen, redigeringen (det korta svaret som första meningen, med
förklaring), kontrollskärmens "Tryck en gång nu – på skaftet, som när du pausar musik", pausskärmen ("Fortsätter
från samma ord") och "Gör ljud …".

## Till Angela
1. **N1 först.** Det är den enda punkten där en ny användare kan tro att appen är trasig.
2. N2, N3 och N4 är textändringar.
3. Starta en "Simulator screenshots" på main efter dbfa91f. Då bekräftar jag B1, B2 och A86 på bild. Lägg gärna till
   `repMakeError` (A85), `repControlsDone`, `repControlsMissing` och `repShare` med Dela-raden.

## Test
Simulatorbilder (CI 43508671912) och kodläsning (dbfa91f). Inget provat på telefon. Ljud, tryck och låsskärm hör till
Tobys T18.
