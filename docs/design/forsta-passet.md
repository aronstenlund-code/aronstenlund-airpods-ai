# Första passet och Lyssnar som börjar tomt (Kelly, Ke35, 2026-11-11)

Svar på Tobys A50-runda (`reports/apptest/2026-11-11-1200-toby-t8b-a50-forstagang.md`), fynd 3, 5 och 6, som han
lämnade till Deangelo och mig. Skisser i `bilder/start2/ke35-*.png` (ljust till vänster, mörkt till höger), källa
`_src/start2.html`. Till Angela. **Skisser, inget provat på telefon.**

## Fynd 5: förstagångsanvändaren ser aldrig nya Start → **landa på Start**
Dagens mål 1 är "begriplig på 5 sekunder", och Aron förstod inte hur man börjar (D124). Då måste den nya användaren se
Start-knappen, inte bara Lyssnar.
- När introt är klart (första frågan, Fortsätt, provsteget och delningsfrågan) **avslutas förstagångspasset** och
  appen visar Start. Lumen lyssnar inte. Delningsfrågan kommer före Start, inte ovanpå Lyssnar.
- Ovanför knappen visas en ruta **en gång** (`ke35-start-forsta.png`): "Här startar du Lumen" och "Sen lyssnar den
  tills du trycker Avsluta. Du ser alltid när den lyssnar." Med × uppe till höger. Knappen har en mjuk ring
  (`soft`, 4 pt) så länge rutan syns.
- Rutan försvinner för alltid efter första trycket på Starta Lumen eller ×. Den räknas inte som en instruktionsrad
  (SYSTEM.md avsnitt 4), eftersom den bara visas en gång.
- Varför inte låta Lumen lyssna vidare: då lär sig användaren aldrig knappen och hittar inte tillbaka nästa gång.
  D121 ("starta en gång, sen finns den i örat") gäller från och med första egna trycket.

## Fynd 3: Lyssnar visar förra sessionens svar → **varje Starta börjar tomt**
- **Ny start** (Starta Lumen, "Förhör mig", eller start med rösten från Start) = tom skärm i alla lägen
  (`ke35-lyssnar-tom.png`). Mitt på skärmen står "Fråga vad du vill." och "Svaret kommer i örat och här." (muted,
  17 och 15). I Provläge med förhör: Lumens första fråga i stället.
- **Byte av läge medan Lumen lyssnar** (Byt läge på Lyssnar, eller "Lumen, byt till provläge") behåller passets svar.
  Under dem står en tunn avdelare med "Bytte till Provläge" (13, muted) (`ke35-lyssnar-bytt.png`).
- Gamla svar finns i Historik, inte på Lyssnar.

## Fynd 6: Provläge frågar fem saker första gången → **högst en fråga**
Med Starta Lumen i Provläge blir det i dag 8 tryck till Lyssnar. Mål: 2 tryck från Start (Byt › Provläge, Starta).
- **Finns ett prov** (från introt eller Start): inga frågor. Lumen startar direkt med provet.
- **Finns inget prov:** en enda fråga, "Har du prov snart?" (samma skärm som A22, runda chips för ämne och datum,
  "Spara prov" och "Inte nu"). "Inte nu" startar Provläge ändå, utan prov.
- Resten får standardvärden och frågas aldrig i förväg: årskurs från provet, kontrollfrågor på, mellanlånga
  förklaringar. Delämnet frågas i första förhöret (som i A22). Allt går att ändra i Inställningar › Provläge och med
  rösten ("kortare", "längre").
- Bladet i dag har ljuslila fyllda knappar för varje val. Det är inte systemet: om något av det behövs igen, använd
  en vanlig lista med ✓ eller runda chips.

## Fynd 7 (tillgänglighet, Angelas)
Raden under Starta Lumen ska vara **ett** element: "Läge: Standardläge. Byt läge". Mittpricken ska inte läsas upp.
