# A15 – "Mer?" efter korta svar: ja, nick eller tryck (Angela, 2026-11-09)

Kort: efter ett kort svar i Frågor och Provläge öppnas ett fönster på 5 s.
- **Signal:** en mjuk ton (120 ms, kan stängas av) och "Säg ja för mer" på skärmen. Lumen frågar inte.
- **Ja:** "ja", "mer", "utveckla", "gärna", en nick eller ett tryck på AirPods ger det utvecklade svaret.
- **Stänger:** "nej", tystnad, en skakning eller en ny fråga.
- **Grönt i CI** (körning 42701351863). **Ej verifierat på enhet.**
- **Väntar på K13:** Kevins cache för det långa svaret och signalerna till /memory är inte klara. Tills dess hämtas det
  långa svaret som "utveckla" (`continue_more`, finns), så målet under 1 s nås inte än.

## Vad som byggdes
**När fönstret öppnas (`MoreOffer`)**
- Svaret är kort: högst två meningar och 40 ord.
- Svaret slutar inte med "?". Provlägets kontrollfrågor besvaras med "ja" själva (D83), så de krockar inte.
- Inget prov eller minitest pågår.
- Fönstret öppnas en gång per svar.

**Vad som räknas**
- **Röst:** bara hela yttrandet ("ja men vad är fotosyntes" räknas inte), och bara bärarens röst (D81).
- **Nick:** samma huvudrörelse som D86.
- **AirPods-tryck:** betyder "mer" medan fönstret är öppet. Annars pausar det som förut.

**Tonen och skärmen**
- Tonen är 1 320 Hz i 120 ms. Den stängs av under Inställningar › Röstkommandon › "Ton när du kan säga "ja" för mer".
- Lyssnarskärmen visar "Säg ja för mer" i blått så länge fönstret är öppet.

## Väntar på K13
1. **Cachat långt svar:**
   - när /answer ger ett id för det långa svaret byter `takeMore` till det i stället för "utveckla";
   - målet under 1 s gäller först då.
2. **Signalerna** (ja, nej, tystnad, rättelse med sammanhang) till /memory, och raden "Utvecklade svar i Historia" i
   Minne: jag bygger dem när K13 har ett kontrakt.
   - Minne visar redan K10:s inlärda inställningar, så en längdinställning från K13 syns där om den kommer i samma
     form.

## Tester (`LumenTests/A15Tests.swift`, gröna)
- Ja, nej och annat. Ett "ja" mitt i en mening räknas inte.
- Bara korta svar utan frågetecken öppnar fönstret.
- **Hela vägen:**
  - kort svar → fönstret öppnas → "Ja." → stängs → ny begäran med "utveckla";
  - "nej" stänger utan någon ny begäran.
- **Nick kontra skakning** går inte att testa utan AirPods. Koden är samma som D83:s.

## Till Toby
- **Ny text:** "Säg ja för mer".
- **Ny inställning:** "Ton när du kan säga "ja" för mer".
- **Fråga:** kan du köra ett kort svar och sedan "ja" i simulatorn?
