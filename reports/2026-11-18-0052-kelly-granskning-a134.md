# Granskning av A134: köpdelen (Kelly (moln), 2026-11-18)

Underlag: grenarna `fable/screens-a134` (iPhone 17 Pro, körning 44199413253, commit 15fe6f1) och `fable/screens-a134-se`
(iPhone SE, största text). Sammanställt i `reports/2026-11-18-a134-granskning/a.jpg` (ljust: bladet, räcker inte,
veckokort, första skärmen med veckokort) och `b.jpg` (mörkt, SE största text). Jämfört mot `docs/design/kop.md` (Ke73 + Ke77).
Allt är **sett på bild i Simulatorn** med en låtsasbutik i appen (rättat efter Angela Fable: StoreKit-filen är inte körd, Toby provar den i T48); inga riktiga köp.

## Stämmer
- Bladet: siffran, Fyll på med tre tonade prisknappar, märket "Bäst värde" på 2 000, "Ett prov ≈ 6 000 krediter.",
  Veckokort med "cirka 3 prov", Bjud in med 2 000, fotnoten (riktlinje 3.1.2) och Villkor · Integritet · Återställ köp.
- Räcker inte: "120 krediter · du har 88 · Fyll på", Spela grå, Starta prov fylld (en fylld knapp, som Ke72).
- Veckokort: kapseln och bladet säger "Veckokort" (D222), "16 200 av 20 000 tecken kvar i veckan", Hantera veckokortet,
  "Förnyas automatiskt den 24 nov för 79,00 kr.", första skärmen "Ingår".
- Mörkt läge läsbart. SE största text: prisknappen staplas under namnet, som avsnitt 4.

## Att rätta (till Angela Fable)
1. **SE största text, raden vid Spela:** "Fyll på" står som en egen kolumn till höger och "·" hänger kvar sist på
   raden före. Gör raden till en enda text som flödar (länken som del av samma Text/AttributedString), så att "Fyll på"
   bryts som ett vanligt ord.
2. **Luft överst i bladet:** stort tomrum mellan rubriken och siffran (och "Veckokort"). Siffran ska ligga direkt under
   rubriken, som i skisserna; minska toppmarginalen till ungefär en radhöjd.

## Godtaget
- Priserna visas som "10,00 kr" och "79,00 kr". Det är `Product.displayPrice` för svensk region och så skriver App
  Store själv; skisserna sa "10 kr". Ingen egen formatering.
- Länkarna Villkor och Integritet: sidorna finns men är inte publicerade (Ke78 väntar på Arons ja).

## Inte sett
- Välkomstkrediterna (`valkommen.png`) och raden efter en inbjudan finns inte bland bilderna (byggs i A141?).
- Köpflödet (Apples ruta, snurran, "Köpet gick inte igenom") kan bara ses vid ett köp (**otestat**).

## Efter rättelserna (2026-11-18 01:20)
`reports/2026-11-18-a134-bilder/kop-efter-kellys-rattelser.jpg`: raden vid Spela flödar i största text ("Fyll på" bryts
som ett ord) och siffran ligger direkt under rubriken. **Godkänt.** Fables tre nya köptexter är godtagna; den första
kortad till "Köpet är gjort. Krediterna kommer när EarMind har kontakt igen." (kop.md, avsnitt 5).
Kvar för servern (Kevin): ett fält för välkomstkrediter, för inbjudan som gett krediter och för gränsen 10 i månaden,
och namnet på standardrösten (så att kortet kan visa "Astrid ▾" i stället för "Röst ▾").
