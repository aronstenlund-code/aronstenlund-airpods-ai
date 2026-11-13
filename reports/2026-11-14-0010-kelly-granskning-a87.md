# Kelly: granskning av A87 (Apple-stil), A88, A89 och A90 på bild

Datum: 2026-11-14 00:10. Roll: Kelly Kapoor (design). Underlag: `docs/design/SYSTEM.md` §0 (D160),
`reports/2026-11-13-2300-kelly-ke53-apple-stil.md` (A87-listan), `docs/design/repetition-texter.md` och Arons text (A90).

## Bilder
| Körning | Telefon | Resultat |
|---|---|---|
| 43519509067 | iPhone 17 Pro, ljust och mörkt, alla scener | **grön** |
| 43519515040 | iPhone SE, ljust och mörkt | **grön** |
| 43519595624 | 17 Pro, största text | **failure**, inga bilder |
| 43519600621 | SE, största text | **failure**, inga bilder |
Kod 3382ae2 (A87 9e40c95 + A90). Kontaktblad: `reports/2026-11-14-a87-granskning/` (`p1`/`p2` 17 Pro ljust, `p1d`
mörkt, `se1` SE). **Största text är inte granskad,** eftersom båda körningarna saknar bilder.

## Bedömning
**A87 godkänd med två medelfynd.** Appen ser nu ut som iOS: systemets tomläge på Hem, listor och formulär med iOS
bakgrund, SF Pro, `.borderedProminent` för den enda fyllda knappen, huvudknappen fast nederst på Nytt prov, i
frågelistan och på kontrollskärmen, `ShareLink` och en ⋯-meny i frågelistan, uppspelningen utan bricka och Avsluta
som grå knapp. Mörkt läge och iPhone SE håller.

| Ke53-punkt | Status på bild |
|---|---|
| 1 Nästa steg alltid synligt | **Klar.** Skapa frågor, Starta prov och kontrollskärmens knappar ligger fast nederst, också på SE |
| 2 Hem som tomläge/lista | **Klar.** `repHomeEmpty` har en fylld knapp, Klistra in en länk och Fler lägen · Beta. Flamman är en rad med text ("3 dagar i rad") |
| 3 SF Pro | **Klar** i repetitionsflödet |
| 4 Systemknappar | **Klar** |
| 5 Systemfärger och listor | **Klar** |
| 6 Nytt prov som Form | **Klar,** och N3-raden under den grå knappen finns |
| 7 Frågelistan | **Klar,** utom K3 nedan |
| 8 Fortsätt utan dialog | Scenen finns inte längre. Granskas när Hem visar ett påbörjat prov |
| 9 Kontrollskärmen | **Klar:** cirkel med prickar, en instruktion, lista, Hoppa över under knappen |
| 10 Uppspelningen | **Klar:** N1-raden "Tryck på AirPods för svaret" i `repPlayFirst`, svart ring och Avsluta grå |
| 11 Fler lägen | **Delvis:** N4-fotnoten ("Valet gäller Starta Earmind. Starta prov använder aldrig mikrofonen.") och "Förhör med rösten" finns. BETA-märket per rad finns kvar (Angelas kö) |
| 12 Redigera som Form | **Klar,** med det korta svaret i fotnoten |
| **A88** årskurs | **Klar:** "Vilken årskurs? åk 9" som meny i Nytt prov |
| **A89 / D162** | **Klar:** ingen rad "Långa svar". Fotnoten "Varje fråga får ett kort och ett långt svar." |

## Fynd
| # | Var | Fynd | Ska vara | Nivå |
|---|---|---|---|---|
| **K1** | `repControls`, `repControlsDone`, `repControlsMissing` (A90) | Under "Medan frågan spelas:" står rad 1 som **"Tryck** 1 gång för frågans A-svar." Arons text är "Medan frågan spelas: **tryck** 1 gång …". Alla ord är rätt, men den stora bokstaven gör att texten inte är exakt Arons. | **"tryck 1 gång för frågans A-svar."** med litet t, som i Arons text och `repetition-texter.md` §7. Raderna 2 och 3 är ordagranna. | Medel (Aron vill ha texten exakt) |
| **K2** | Hem (`repHome`, `repHomeEmpty`) | Nere till vänster finns bara en **+** utan text, och nere till höger "Öppna länk". En ny användare vet inte att + betyder Nytt prov. | `Label("Nytt prov", systemImage: "plus.circle.fill")` med texten synlig, som "Ny påminnelse" i Påminnelser (Ke53 Hem, `apple/hem.png`). "Öppna länk" kan ligga i samma meny eller stå kvar. | Medel |
| K3 | Frågelistan (`repList`, `repShare*`) | Frågornas titlar står i accentfärgen, så hela listan ser ut som länkar. | Titlarna i `.primary`. Bara "Lägg till fråga" i accentfärgen. Raderna är tryckbara ändå (chevron). | Låg |
| K4 | `repShare` | Visar Historiaprovet med "ljud klart", så läget "Delas när ljudet är klart (x av y)" syns fortfarande inte i bild. | Ett prov med ljudet på väg i scenen. | Låg |
| K5 | `repMakeError` | Felet (A85) syns inte i bild. Scenen visar Nytt prov med text och en blå Skapa frågor. | Rulla så att felraden och Försök igen syns, eller lägg felet överst. | Låg |
| K6 | Största text | Båda körningarna med största text misslyckades (43519595624, 43519600621). | Kör om, så granskar jag SYSTEM §10 (inga ord brutna mitt i, rubriker kapas inte). | Medel (ej granskat) |

## Till Angela Fable
K1 och K2 först (texten ska vara exakt, och + ska säga vad den gör). Sedan K3–K5 och en ny körning med största text.

## Följder hos mig
- Demosidans utkast (`drafts/site-repetition/`, Ke54) har nu A87:s bilder (`repPlayFirst`, `repMaterial`, `repList`).
- App Store-förhandsvisningarna (`docs/appstore/69-*.jpg`, Ke56) är omgjorda med A87:s bilder. De är fortfarande
  uppskalade från 17 Pro och har Segoe UI i rubrikerna.

## Inte granskat
A83 (Publicera prov): scenerna `repPublish`, `repSchools`, `repSchoolsEmpty`, `repPublication` och `repVoice` kommer i
nästa körning. Inget är provat på telefon.
