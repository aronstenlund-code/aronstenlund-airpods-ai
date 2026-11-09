# Kevin K11: Anrop som hänger, stump och citat (Oscar O5)

Datum 2026-11-09 · Uppgift: `prompts/queue/kevin.md` K11 · Underlag: `reports/qa/2026-11-09-1800-oscar-o5-forhor-k7.md` (fynd 1, C och D) · Driftsatt i fyra omgångar (Deploy backend 42699522743, 42701883744, 42702283305; den första körningen 42697732432 föll på typfel, se nedan). Allt nedan är **verified live** (anrop mot driftsatt backend, `scripts/k11-eval.py`) där inget annat står. **Inget är testat på telefon eller AirPods.**

## Resultat
| Krav | Före | Efter |
|---|---|---|
| Inget svar tar mer än ~8 s (Provläge, Sonnet) | 1 av 3 derivatafrågor hängde > 90 s (Oscar) | **0 av 10 över 8 s.** Första text max 4,5 s (Anna/Fredrik med tänkande), totalt max 7,3 s. 10 av 10 svar 200 och inte tomma |
| Ingen stump efter en filtrerad mening (Intervju, alkohol) | 1 av 2 (Oscar) | Första körningen efter ändring 1: **2 av 5** ("Det är precis den noggrannheten …", "Det är just den ansvarskänslan …"). Efter ändring 2 och 3: **0 av 6** besvarade (resten fick 429, se Kvar) |
| Strindberg-citatet | påhittat (Oscar) | 5 av 5 utan påhittat citat: 2 ordagranna citat **bekräftade av sökningen** (runeberg.org, novellen "Ett dockhem" i Giftas), 2 "Jag kan inte citera det ordagrant, men …", 1 svar med innehållet med egna ord |

Filer: `reports/eval/k11-2026-11-09-first.{json,md}` (alla 20 fall), `reports/eval/k11-2026-11-09-stump.json` (intervjufallen efter ändringen).

## Vad som ändrats
**1. Tidsgräns och omstart (`answer/llm/deadline.ts`, ny):** en wrapper runt modellanropet i /answer.
- Första ordet måste komma inom **5 s**, eller **7,5 s** när modellen tänker (textuppgifter, "var säker"). Annars avbryts anropet och samma fråga skickas en gång till på standardmodellen (Haiku 5.5) utan tänkande.
- Ett serverfel före första ordet (5xx, överbelastning, 429 från Anthropic) går om på samma sätt. Fel på kvoten eller nyckeln går inte om.
- Står strömmen still i 4 s efter att svaret börjat, slutar svaret där med det som redan sagts.
- Webbsvar får 12 s och går inte om, eftersom en ny sökning tar lika lång tid. Appen har sin egen reserv.
- Omstarter loggas som `llm_fallback` och stopp som `llm_stalled` (modell, orsak, ms).
- Varför 5 och 7,5 s: Oscars O8 mätte första text p95 6,6 s med tänkande och under 2,5 s utan. Gränsen ligger strax över det, så att omstart plus ett Haiku-svar (~1 s) ryms inom ~8 s.

**2. Stump (`answer/speech.ts`):**
- Efter en bortfiltrerad mening räknas fler inledningar som en stump och stryks: "Det är just/precis …", "Just den …", "Den här …", "Samma …", "Den erfarenheten …".
- Den **första** meningen i ett intervjusvar prövas likadant, plus "Det har lärt/gett/gjort mig …".
- Varför: live öppnade modellen själv svaret så, utan att något filtrerats före. Prompten (`missingFactNote`) säger nu också att första meningen ska stå på egna ben.

**3. Citat (`answer/web.ts`, `speech.ts`, `llm/anthropic.ts`, `handler.ts`):**
- En begäran om ett citat av en person ("citera X", "ett citat av X", "vad sa X om …"; inte låtar, verser eller hela texter) slår på en citatkontroll.
- Ett ordagrant citat (4 ord eller fler inom citattecken) sägs bara när samma ord finns i det som webbsökningen gav. Det läses ur API:ets citeringar (`cited_text`), som nu skickas vidare som en egen bit (`cite`).
- Annars stryks meningen. Om inget hunnit sägas frågar /answer en gång till, med instruktionen att börja "Jag kan inte citera det ordagrant, men …" och säga innehållet med egna ord.

## Fel på vägen
Den första deployen föll på typkontrollen. Den nya biten `cite` gjorde att `exam`, `memory`, `provlage-eval`, `study-cards` och `study-profile` läste tokenantal från något som inte var en usage-bit. Jag rättade det till `else if (type === "usage")`. Node-shimmen fångar inte typfel (känt).

## Tester
Lokalt (Node-shim) är answer **258 gröna**, varav 9 nya i `k11_test.ts`:
- omstart vid tidsgräns och vid överbelastning, men inte vid kvotfel;
- ett stopp efter text;
- ett webbanrop utan reserv;
- stumpfallen;
- personcitat mot låtar;
- citat som bekräftas eller stryks.

Actions (Deno, med typkontroll) är grönt.

## Kvar och risker
- **429 vid täta intervjufrågor:** i omkörningen av stumpfallen fick 14 av 20 anrop 429, med två testanvändare och ett anrop var tredje sekund. Det är samma sak som Tobys T6-fynd 7, som ligger i **K12**. Jag har inte rört gränserna här.
- **Citat via webben tar 5–9,5 s** till första text (1 av 5 över 8 s). Webbsvar har inte 8-sekundersgränsen, eftersom sökningen tar tiden.
- Vid en omstart loggas kostnaden med den första modellens pris, så den blir något för hög. Det är försumbart.
- Omstarten på Haiku ger ett svagare svar på textuppgifter (inget tänkande). Det är bättre än tystnad, men det syns inte i måtten eftersom ingen omstart skedde i mätningen.
- Stumpfiltret är en lista med inledningar. Nya formuleringar kan slinka igenom (**untested assumption**: fler varianter finns).

## Kostnad
Ungefär 0,25 USD (35 anrop, varav 15 Sonnet).

## Nästa
Ordning enligt Aron 2026-11-09: K14 (brådskande, ägarbeslut) → K16 → K12 → K13 → K15 → K17 → K18 → K19 → K4 → K5 → K6.
