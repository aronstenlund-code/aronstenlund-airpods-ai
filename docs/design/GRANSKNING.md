# Granskning av utseendet (PLAN 2c, Kelly)

En A-punkt som ändrar utseendet är klar först när skärmbilderna (ljust, mörkt, iPhone SE) finns i rapporten och jag har
granskat dem. Det här är listan jag går igenom. Svaret skrivs i `reports/YYYY-MM-DD-HHMM-kelly-granskning-<A-punkt>.md`
som **godkänd**, **godkänd med rättelser** (lista) eller **inte godkänd** (lista). Varje rad märks med vad den bygger på:
skärmbild, kod eller antagande.

## Underlag
- Bilder i `reports/` för varje ändrad skärm: ljust, mörkt och iPhone SE (minsta skärm). Saknas något granskar jag det
  som finns och skriver vad som saknas.
- `docs/design/SYSTEM.md` och skisserna i `docs/design/bilder/system/`.

## Listan
1. **En huvudknapp:** högst en blå knapp per skärm. D97 är ett undantag: provkortet har "Förhör mig" (blå) och "Få A-svar
   till provet" (sekundär), med en rad under varje.
2. **Rött bara vid fel:** ingen röd knapp för Avsluta, Stoppa eller dagar kvar.
3. **Ingen handstil och inget rutpapper** i gränssnittet. Frågor står i halvfet grå text ovanför svaret.
4. **Ord:** samma ord på knappen som det man säger till Lumen. Inga dubbla negationer och ingen utvecklartext
   (licenser utanför Om, modellnamn, "1.00×", röstnamn). Ingen ständig instruktionsrad.
5. **Typografi:** bara Familjen Grotesk. Rubriker 28–34 bold, brödtext 17, svar 20, fotnot 13. Inget klipps vid största
   textstorlek.
6. **Färg och kort:** en accent. Kort med hörn 20 och mjuk skugga i ljust läge, `raised` utan skugga i mörkt. Brickor
   är helt runda.
7. **Mörkt läge:** inget försvinner mot bakgrunden (grupper, chips, segmentreglage). Elias-kortet är ljust.
8. **iPhone SE:** huvudknappen syns utan att man scrollar på första start, Start och Lyssnar.
9. **Skydd som aldrig får försvinna:** samtyckesmeningen under Testa nu, att man alltid ser när Lumen lyssnar (Lyssnar-
   brickan eller indikatorn) och tummen ned på svaret (D57).
10. **Tomma lägen och fel:** en mening och en handling (till exempel Lumen hör dig inte, Start utan prov).
