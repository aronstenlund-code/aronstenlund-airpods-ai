# K69: snabbare "Skapa frågor" (Kevin, 2026-11-15 02:55, delvis klart, överlämnat till molnet)

## Kort
- **Hastigheten är klar och driftsatt** (d057284 och a3c2c5b, live i deploy d77433d).
- **Var tiden gick:** "Stämmer det här?" visas efter steg 1 i `/exam drill` (`answers: false`). Steg 1 var en Haiku-plan som skrev sammanfattning, cirka 2 400 tecken anteckningar och frågorna i ett svar, och sedan ett kontrollsteg som väntade på hela planen.
- **Ändringen:**
  - Anteckningarna skrivs i ett eget anrop samtidigt som frågorna. Det är samma modell, samma systemprompt (cachad) och samma material.
  - Kontrollsteget börjar så fort frågorna finns.
  - Inget i prompterna för frågor eller svar ändrades.

## Mätning (server, testkonto, 0 ElevenLabs)
Väggtid från anrop till svar, mätt från den här datorn (`scripts/k69-measure.py`, data i `reports/qa/data/2026-11-15-*-k69-*.json`).

| Material | Frågor | Före | Efter |
|---|---|---|---|
| Biologi, 10 foton | 3 | 8,5 s | 6,2 s |
| Biologi, 10 foton | 15 | **10,1 s** | **5,2–5,4 s** |
| Biologi, 10 foton | 20 (materialet bär 15) | 8,8 s | 5,1 s |
| Biologi, text | 15 | 8,4 s | 4,3 s |
| Biologi, text | 20 | 8,2 s | 3,9 s |
| Franska revolutionen, 5 foton | 15 | 8,5 s | 8,9 s (en körning med kontroll 2,4 s och plan 5,8 s, alltså en långsam körning; fler mätningar behövs) |

- **Fördelning före (15 frågor, foton):**
  - plan 6,5 s, varav anteckningarna är det mesta av texten
  - kontroll 1,5–2,9 s
  - nät och uppstart 1–2 s
- **Efter:** frågedelen 2,7–3,9 s och anteckningarna 3,5–4,5 s samtidigt, sedan kontrollen 0,8–1,5 s medan anteckningarna blir klara.
- **Kostnad Claude:** cirka 0,04 USD för mätningarna. Ett prov kostar några tiondels öre mer eftersom materialet skickas två gånger till Haiku: foton cirka 22 000 tokens × 0,10 USD per miljon, alltså cirka 0,002 USD.
- **Kostnad ElevenLabs:** 0.

## Fynd och rättning
- **Ett falskt 422 i första mätningen.** Frågedelen för 10 foton gav ett svar utan frågor och utan "unreadable", och servern sa då att materialet inte gick att läsa.
- **Rättat (a3c2c5b):** blir frågedelen tom utan skäl körs planen i ett anrop som förut, med loggraden `drill_questions_part_empty`. Live efter rättningen gav samma material 200 och 3 frågor.

## Verifierat och inte verifierat
- **Verifierat:**
  - 618 tester gröna
  - `check` ren
  - den driftsatta versionen innehåller rättelsen (`git merge-base`)
  - tiderna ovan live
- **Inte verifierat:**
  - **Kvaliteten:** O63/O64 är inte omtestat efter delningen. Frågorna skrivs nu utan att modellen först skriver anteckningarna i samma svar. Det kan påverka frågorna (**otestad antagelse** att det inte gör det). Det är den kvarvarande delen av K69.
  - **Tiden i appen:** appen lägger på uppladdning av fotona och sin egen tid. Toby mätte 12 s för 3 frågor i simulatorn. Hur mycket appen lägger på har jag inte mätt.
  - **20 frågor efter rättningen:** de körningarna stoppades av 429, eftersom /exam begränsar anropen per konto och jag bara hade ett konto.

## Det som skulle kräva en sämre modell (inte byggt)
- **Kontrollsteget i samma anrop som frågorna:** sparar 0,8–1,5 s, men frågorna kontrolleras då inte av ett andra steg, och K52 och K67 bygger på den kontrollen.
- **Kortare anteckningar** (under cirka 900 ord): ger svarsmodellen mindre underlag. Inte en sämre modell, men sämre svar.

## Mer tid utan sämre kvalitet (förslag)
- **Strömma de första frågorna till appen**, så att "Stämmer det här?" kan visas efter frågedelen (cirka 3 s). Kräver ändring i appen och ett SSE-kontrakt.
- **Starta svarssteget i bakgrunden** medan eleven läser "Stämmer det här?". Det skulle ta tid från Starta prov, inte från den här skärmen.

## Nästa (Kevin i molnet)
- **Avsluta K69:**
  - kör O63/O64-kontrollen på appens väg (`scripts/k66-quality-check.py` och `scripts/k67-live-check.py`, med ett konto per prov och högst cirka 30 registreringar per timme)
  - jämför med O64 (0 cirkulära och 0 "materialet")
  - säg sedan till Oscar att mäta om (O63/O64 och tiden)
- **Om kvaliteten blir sämre:** återställ delningen. Det är commit d057284, och reserven a3c2c5b kan stå kvar.
