# A12 – Tobys skärmfynd (Angela, 2026-11-09)

Kort: Tobys fyra viktigaste fynd från T3 är rättade:
1. Rizz-åldersgränsen kapas inte längre.
2. Samtycket syns vid knappen.
3. En nekad mikrofon visas på Start.
4. Knappar och rader kapas inte vid största text.

Efter-bilderna kommer från Tobys skärmrunda på A12-koden (körning 42661012604, simulator) och ligger i
`reports/2026-11-09-a12-skarmbilder/`. Före-bilderna är Tobys i
`reports/apptest/2026-11-09-t3-skarmbilder/avvikelser/`. **Simulator, ej enhet.**

## Fynd och rättning
| Fynd (T3) | Före | Rättning | Efter |
|---|---|---|---|
| 1. Rizz-åldersgränsen kapas | `1-rizz-kapad-liten-iphone.png`, `1-rizz-kapad-storsta-text.png` | Texten radbryts (`fixedSize`) och rullar. Knapparna sitter fast nedtill. Arket kan växa och öppnas i full höjd vid tillgänglighetsstorlekar. | `efter-1-rizz-liten-iphone.png`: hela rubriken och texten syns. `efter-1-rizz-storsta-text-fore-detent-fix.png` är tagen före full höjd-rättningen: rubriken syns, men förklaringen låg under knapparna. Det är rättat i e311eed, och Tobys nästa runda bekräftar. |
| 2. Samtycket syns inte på liten iPhone | `2-samtycke-syns-inte-liten-iphone.png` | Meningen vid "Testa nu" räknar nu upp de tre punkterna. Bilden krymper på liten skärm och försvinner vid största text. "Läs mer" ligger fritt från knappraden. | `efter-2-samtycke-liten-iphone.png`: punkterna står vid knappen. |
| 3. Nekad mikrofon gör ingenting | `3-mikrofon-nekad-fragor-inget-hander.png` | Start stannar och visar kortet "Lumen hör dig inte" med "Öppna Inställningar". Det gäller både Frågor och Provläge. | `efter-3-mikrofon-nekad-start.png` |
| 4/5. Största text: kapat och ord brutna mitt i | `4-lyssnar-knappar-kapade-storsta-text.png` m.fl. | Knappar: en rad som krymper (lägst 50 %). Pausa och Avsluta staplas vid tillgänglighetsstorlekar. Lägesnamn: två rader. Lyssnar-rubriken: två rader. Kommandoraden: hela texten. | Två rader bröt orden mitt i ("Paus/a"). Det syntes i rundan och är rättat i e311eed, men inte fotat än. |

## Inte gjort
- **Fynd 6:** språkväljaren växer inte.
- **Fynd 7:** knapparna täcker beskrivningen i Intervju och Socialt.
- **Fynd 9:** kontrasten på "Dela historik" i mörkt läge.
- **Fynd 11:** provets namn saknas i Byt läge.
- **Fynd 12:** Läs mer och Inställningar har iOS standardstil.
- Mindre fynd. Ingen av dem stod i A12-punkten.

## Till Toby
- **Rundan fastnade en gång:** på liten iPhone ljust hittades inte "Integritet och samtycke" (`liten-light`). Den nya
  raden "Röstkommandon" (A6) ligger under "Mer", före "Egna kommandon". Raderna längre ner hamnar därför ett steg
  längre ner. Mörkt läge hittade raden.
- **Ändrade texter:**
  - Meningen vid Testa nu.
  - Lyssnar-rubriken kan säga "Hör inte, försöker igen" (A11).
  - Kommandoraden kommer från tabellen (A9.1).
- **Kör gärna rundan igen** på e311eed eller senare för att få efter-bilder av fynd 1 och 4/5 vid största text.

## Tester
- Grönt i CI: 42661012831, och e311eed (42678968025).
- Inga nya enhetstester: det är layout, och skärmrundan är testet.

## Concerns
Inga.
