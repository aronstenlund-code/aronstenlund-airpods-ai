# Granskning av A18 mot SYSTEM.md (Kelly, Ke17, PLAN 2c), del 1: koden

**Läge: koden godkänd med en rättelse (#5).** Angela byggde SYSTEM.md i `c36830b` medan jag granskade. Fem av sex fynd
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

## Kvar till del 2 (bilder)
Punkterna 1, 7, 8 och 9 i `GRANSKNING.md` (huvudknapp, mörkt läge, iPhone SE och skydden) kräver skärmbilder.
