# Oscar O54: Oberoende test av Kevins omgång 18/20 (Intervjuläget utan CV)

Datum: 2026-11-12, 01:07–01:10 (svensk tid). Stående uppgift (PLAN 2b).
Kevins omgång 20 (`reports/2026-11-12-0050-kevin-standing20-interview-ad.md`, `dc710dd`) och omgång 18: utan CV ska texten räknas som annonsen, aldrig som elevens egna fakta. Erfarenhet som CV:t inte nämner ska aldrig påstås, varken att eleven har den eller inte har den. "Det är en bra fråga" sägs inte.

**Skript:** `scripts/qa/o54_interview_ad_live.py`.
- Tre **nya** annonser (kafé i Uppsala, lager i Jönköping med truckkort, barnvakt i Malmö) och fyra intervjufrågor per annons.
- Intervjuläge = `mode: tutor`, `persona: interview`, och `persona_setup` innehåller bara annonsen, som appen skickar den utan CV.

**Rådata:** `reports/qa/data/2026-11-12-010935-o54.json`.
**Kostnad:** under 0,01 USD enligt usage. **Gradering:** för hand. Mallen missade "Jag har tidigare jobbat".

## Resultat: **7/12 rena, 5/12 gör annonsens krav till elevens egna fakta** (prio 2)
| Annons (krav i annonsen) | Svar som påstår kravet som elevens fakta |
|---|---|
| Lager: "Truckkort krävs. **Du har jobbat i lager tidigare och är van vid tunga lyft.**" | "har du truckkort eller körkort" ger "**Jag har tidigare jobbat i lager och är van vid tunga lyft**, så jag kan snabbt sätta mig in i rutinerna." "berätta om dig själv" ger "**Jag är van vid fysiskt arbete och tunga lyft** …" |
| Barnvakt: "**Du har erfarenhet av barn och kan simma.**" | "vad har du för erfarenhet" ger "**Jag har erfarenhet av barn och kan simma** …". "har du jobbat med det här förut" och "berätta om dig själv" ger båda "**Jag kan simma** …" |
| Kafé: "Erfarenhet av kassa och kaffemaskin är meriterande." | Inga (4/4 rena: "jag vill lära mig kaffemaskinen ordentligt") |

**Det som fungerar:**
- **0 förnekanden.** Ingen "jag har inte jobbat med …".
- **0 floskler.** Inget "Det är en bra fråga".
- Truckkort och körkort påstås aldrig, och frågan undviks i alla tre annonserna.

**Bedömning:** rättningen i `userFacts` gör att annonsen inte längre räknas som elevens fakta i koden. Men modellen gör fortfarande om annonsens **"Du har …"/"Du kan …"** till "Jag har …"/"Jag kan …". Eleven får då ett färdigt svar att säga på en riktig intervju med påhittad erfarenhet, till exempel att den har jobbat i lager tidigare. Det är just det omgång 18 skulle stoppa.

**Rättning (till Kevin, prio 2):**
- Skriv in i intervjuprompten: krav i annonsen är arbetsgivarens krav, aldrig elevens egenskaper. Utan CV sägs bara egenskaper som inte går att kontrollera ("jag lär mig snabbt") eller en fråga tillbaka ("Har du jobbat i lager förut? Säg i så fall …").
- Eller: ett kodfilter som stryker en mening som upprepar en "Du har/kan …"-mening ur annonsen i jag-form.
- Lägg mina tre annonser som en hållout.

**Märkning:** verified live mot servern. Appens Intervjuläge är inte provat på telefon.
