# Kelly: granskning av A98 (Spela in i Mina svar) och A95 (kontrast) på bild

Datum: 2026-11-14 13:59. Bilder: CI "Simulator screenshots" **43595060459** (iPhone 17 Pro) och **43595064575** (iPhone SE,
största text), kod bf9e578. Angela Fables kontaktblad: `reports/2026-11-14-a95-a98-bilder/` (`a98-17pro-ljust.jpg`,
`a98-17pro-morkt.jpg`, `a98-se-storsta-text-ljust.jpg`, `a95-17pro-morkt.jpg`, `a95-17pro-ljust.jpg`).

## A98: Spela in (D173)
**Godkänd.** Formuläret har numrerade sektioner (1. Fråga, 2. Svar), en fylld knapp nederst som alltid är nästa steg
(Spela in svaret, sedan Stoppa, sedan Klar), en röd prick bara medan det spelas in, och "Svaret är inspelat · 00:34"
med Spela in igen. Det följer SYSTEM §0. Fotnoten om ljudet stämmer med D133: utskriften görs på telefonen, ljudfilen
raderas vid Klar eller Avbryt, och bara texten skickas.

| # | Fynd | Ska vara | Nivå |
|---|---|---|---|
| M1 | Tomt läge: sektionen 2. Svar säger "Välj eller skriv frågan först. Mikrofonen startar inte förrän du trycker Spela in svaret.", och samma "Välj eller skriv frågan först." står under den grå knappen. Samma sak står två gånger. | I sektionen bara "Mikrofonen startar när du trycker Spela in svaret." (som i läget med fråga). Raden under knappen står kvar. | Låg |
| M2 | Största text (SE): tiden bryts ("00:12 av" / "10:00"), och "Svaret är inspelat · 00:34" över tre rader. | Vid tillgänglighetsstorlekar står tiden på egen rad ("00:12" stort, "av 10:00" under i `.secondary`) och "Svaret är inspelat" med tiden på en egen rad. Det rullar, men blir lättare att läsa. | Låg |

## A95: kontrast
**Godkänd.** Fyllda knappar i mörkt läge har mörk text på den ljusa accentfärgen (6,9:1), som i mina skisser, och
raden under huvudknappen har textfärg. Avstängda knappar (Starta prov på kontrollskärmen i mörkt läge) är nästan
osynliga. Det är systemets avstängda stil och är undantaget från kontrastkravet. Det får vara så.

## Svar på frågan om systemets grå text
**Låt systemets grå (`.secondary`) vara kvar** i undertexter, fotnoter och sektionsrubriker (D160). Två undantag, där
texten bär något man måste läsa:
1. Raden om data ovanför **Fortsätt** på Välkommen. Det är samtycket, så den ska vara i `.primary` (eller `.secondary`
   i `.footnote` med vikt `.medium`), aldrig ljusare än `.secondary`.
2. Förklaringen under en **grå huvudknapp** ("Lägg till minst en sida, bild eller text.", "Välj eller skriv frågan
   först."). Den säger varför man inte kommer vidare, så den ska vara i `.primary`, som Angela Fable redan gjort i A98.
Allt annat står kvar som systemet ritar det.

## Test
Simulatorbilder, inte telefon.
