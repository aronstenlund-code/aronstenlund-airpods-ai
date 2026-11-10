# Granskning av A18 mot SYSTEM.md (Kelly, Ke17, PLAN 2c)

**Läge: godkänd med rättelser** (se del 2: sex rättelser, varav fyra ska göras före nästa T3). Del 1, koden: godkänd med en rättelse (#5). Angela byggde SYSTEM.md i `c36830b` medan jag granskade. Fem av sex fynd
från min första läsning (08:00) är redan rättade. Del 2, skärmbilderna i ljust, mörkt och SE, kommer när Angelas bilder finns i `reports/`.

Underlag: `git grep` på `origin/main` 2026-11-10 ca 08:10 (**kod**). Angelas oincheckade ändringar i samma mapp är inte
granskade.

## Rättelser till Angela, omgranskade mot `c36830b` ("A18 design system", 08:05)
| # | Vad | Läge efter c36830b (**kod**) |
|---|---|---|
| 1 | Röd handstilsring "5 dagar kvar" | **Rättad:** `RedPenRing` ritar nu en bricka (`soft`, blå text, helt rund). Namnet finns kvar. |
| 2 | Rutpapper på kort | **Rättad:** `GridPaper` ritar nu systemets kort (`raised`, hörn 20, mjuk skugga, hårlinje i mörkt). |
| 3 | Handstil | **Rättad:** `questionFont` ger Familjen Grotesk semibold, minst 15. Inställningen finns kvar i koden men påverkar inget. |
| 4 | Frågan i blått | **Rättad:** `muted` i Lyssnar och Första frågan. |
| 5 | Rött i lyssnarraden när den är aktiv | **Kvar:** `ListeningIndicatorBar.swift:40` (punkten) och `:57` ("Avsluta") är röda när Lumen lyssnar. Förslag: blå punkt som Lyssnar-brickan och "Avsluta" i bläck. |
| 6 | "1.00×" | **Rättad:** hastighet i ord enligt commiten; `"%.2f×"` finns inte längre i `SettingsView`. |

## Godkänt i koden
- **"Avsluta" behålls** (Angelas skäl: rösternas ord, och "klar" betyder redan något i D72). SYSTEM.md och skissen är
  ändrade efter det: Avsluta är en neutral sekundär knapp.
- "Inget prov just nu" som brytare är borta. Den heter nu "Jag har ett prov" (`SettingsView.swift:171`).
- ErrorCard använder rött, vilket är rätt eftersom det är ett fel.

## Del 2: skärmbilderna
Underlag: `reports/2026-11-10-a18-skarmbilder/`, 20 bilder: Intro, Första frågan, Start, Lyssnar och Inställningar på
iPhone 17 Pro och iPhone SE, i ljust och mörkt läge. Bilderna kommer från simulatorn. Varje fynd är märkt **skärmbild**
eller **mätt** (pixelvärde ur bilden).

**Start: godkänd.** Skärmen följer skissen: NÄSTA PROV, brickan "5 dagar kvar", D97:s två knappar med en rad under
varje, ANDRA PROV som lista, och Bara fråga och Fler lägen. Den fungerar på SE och i mörkt läge.

### Rättelser till Angela
| # | Skärm | Fynd | Ska bli | Före nästa T3? |
|---|---|---|---|---|
| R1 | Intro | Ringarnas mitt (den blå punkten) ligger mitt i Elias ansikte, inte vid hörluren. Elias är liten i ett brett kort med mycket vitt (**skärmbild**). | Bilden fyller kortet (`scaledToFill`, toppjusterad, som på sidan och i `bilder/system/intro.png`), och `ringOrigin` räknas mot den synliga bilden. | ja |
| R2 | Intro, SE | Testa nu täcker löfte 2 och 3 och "Läs mer". Bara det finstilta under knappen visar allt (**skärmbild**). | En mening under rubriken ("Telefonen stannar i fickan.") och mindre hjältebild på SE, så att alla tre löftena och Läs mer syns ovanför knappen. Skyddet (GRANSKNING.md 9) måste synas. | ja |
| R3 | Intro och Första frågan, mörkt | Bakgrunden bakom innehållet är #000000, men bandet längst ner är #0F1218 (**mätt**). Det syns som en kant. | Hela skärmen ska vara `background` (#0F1218), som på Start och Lyssnar. | ja |
| R4 | Lyssnar och Första frågan | Brickan säger "Startar …" medan knappen säger "Lyssna igen", alltså pausat (**skärmbild**, simulatorns läge). | Brickan ska säga det som gäller: "Pausad" när den är pausad. Det rör `ListeningScreen.swift:119` (`.idle, .error`) och `FirstStartView.swift:209`. | ja |
| R5 | Inställningar | Rösten heter fortfarande "Adam" och Provlyssna är en egen rad (**skärmbild**). | Röst-sidan enligt `bilder/system/rost.png`: beskrivning, ▶ på raden och ✓. | nej |
| R6 | Lyssnarraden (andra skärmar) | Punkten och "Avsluta" är röda när Lumen lyssnar (del 1 #5, **kod**). | Blå punkt och "Avsluta" i bläck. | nej |

### Små avvikelser (gör när det passar)
- Intro har två meningar under rubriken (SYSTEM: en).
- Inställningar har en liten titel i stället för en stor rubrik. Prov (datum och årskurs) ligger kvar i Inställningar
  (SYSTEM: proven sköts på Start). Svarslängden heter Anpassad och har en lång förklaring (SYSTEM: Lagom och en kort rad).
- Loggan är fortfarande radiovågorna. Det är inget fel: den väntar på Arons val (Ke12).

### Skydden (GRANSKNING.md 9)
- Samtyckesmeningen står under Testa nu. **OK**.
- Lyssnar-brickan syns på Lyssnar och Första frågan. **OK**.
- Tummen ned finns på svaret. **OK**.
- På SE syns löftena ovanför knappen bara delvis (R2).
