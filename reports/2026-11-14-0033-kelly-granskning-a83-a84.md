# Kelly: granskning av A83 (Publicera prov) och A84 (röstval), plus A87:s rättelser, på bild

Datum: 2026-11-14 00:33. Bilder: CI "Simulator screenshots" **43524695222** (iPhone 17 Pro, 9d3ce32, grön), ljust och
mörkt. Kontaktblad: `reports/2026-11-14-a83-granskning/` (`e1` ljust, `e1d` mörkt). Underlag: `docs/design/publicera-prov.md`
(Ke52) och SYSTEM.md §0. iPhone SE (43524701139) och största text (43527827811, 43527832906 på 76e293f) granskas när de
är klara.

## Bedömning
**A83 godkänd med ett medelfynd. A84 godkänd med ett lågt fynd. A87:s K2, K3 och K5 är stängda på bild.**

| Scen | Bedömning |
|---|---|
| `repPublish` | **Godkänd.** Form med Skola, Ämne (meny), Provdatum, fotnoten om vad som publiceras ("Aldrig foton, dokument eller ditt namn") och brytaren "Visa ett användarnamn" av med "Av: provet visas utan namn." Knappen är grå med "Saknas: provdatum". Exakt Ke52. |
| `repSchools` | **Godkänd.** Skolan med Byt, Ämne som meny, KOMMANDE PROV och TIDIGARE, och "Lägg till" som liten `.bordered` på raden. Användarnamnet syns bara där det valts ("plugghajen"). |
| `repSchoolsEmpty` | **Godkänd.** Systemets tomläge, "Inga prov här än" och uppmuntran en gång. Knappen "Mina prov" från Ke52 saknas, vilket är okej, eftersom bakåt finns. |
| `repPublication` | **P1 (medel):** visar bara titel, ämne, datum, skola och antal frågor, och sedan Rapportera. **Frågorna syns inte** innan man lägger till provet. Ke52 (`pub-forhand.png`): de fyra första frågorna, "och 16 frågor till" och "Lyssna på första frågan". Utan dem vet man inte vad man lägger till. |
| `repVoice` | **A84 godkänd.** Röst A/B/C med ▶ och ✓, och fotnoten "Rösten går inte att byta efteråt, eftersom ljudet görs med den." (D151). **P2 (låg):** "Röst A/B/C" säger inget. Ge dem en kort beskrivning, som i Ke14 ("Lugn", "Tydlig", "Snabb"), när Aron har valt namn efter blindtestet. Rubriken är "Stämmer det här?", så rösten ligger i sammanfattningen, vilket är rätt plats (före ljudet). |
| `repHome` | **K2 stängd:** "⊕ Nytt prov" med text. Raden "Prov från din skola" finns under proven. |
| `repList` | **K3 stängd:** frågornas titlar i textfärg. |
| `repMakeError` | **K5 stängd:** felet "Det gick inte att skapa frågorna. Försök igen." med Försök igen överst. |

Mörkt läge har inga fel.

## Svar till Angela Fable om största text (även i SYSTEM.md §10)
- "Biologipro-vet": systemets avstavning med bindestreck är tillåten när ett ord inte får plats på en rad.
- "Prov från di…": inte tillåtet. Vid tillgänglighetsstorlekar blir rubriken inline, och titeln står som första rad
  i listan med radbrytning.

## Test
Simulatorbilder, inte telefon.
