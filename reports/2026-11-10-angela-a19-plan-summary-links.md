# A19 – Repetition, sammanfattning, plan och länkar i appen (Angela, 2026-11-10)

Bygger på Kevins K17 (`reports/2026-11-10-1135-kevin-k17-spaced-repetition-plan.md`) och K19
(`reports/2026-11-10-0950-kevin-k19-learning-links.md`). **CI och simulatorlogik. Inget provat på telefon, och inga
riktiga notiser är sedda.**

## Vad som gjordes
1. **Planen på Start:**
   - När Start visas skickar appen alla kommande prov till `/study-plan`. Med varje prov följer historiken per begrepp
     (`{date, ok}`) och provets egna ämnen utan historik, så att planen finns från första dagen.
   - Provkortet visar dagens pass: "I dag: 10 min Biologi (cellandning, klorofyll)".
   - Saknas ett pass i dag visas "Öva mer på" som förut.
2. **Frågan från planen:** när Provläge startas för ett prov läser Lumen upp `prompt` ("I går missade du cellandning och
   mitos. Ska vi ta dem nu?"). Det sker en gång om dagen per prov, och inte med "Förhör mig" (förhöret börjar då direkt),
   inte i "Få A-svar" och inte när ämnet först måste frågas (A24).
3. **Påminnelser:**
   - Varje dag i planen blir en lokal notis kl. 16, till exempel "10 minuter biologi i dag" och "cellandning, mitos. Säg
     ”Lumen, förhör mig”."
   - Gamla notiser ersätts vid varje uppdatering.
   - iOS frågar om notiser **först när eleven trycker** "Påminn mig om passen kl. 16" på provkortet. Den frågan dyker
     aldrig upp av sig själv på Start, så den kan inte stoppa någon annans test eller första starten.
   - Inställningar › Påminnelser har en brytare "Påminn om dagens pluggpass" (på från början) som stänger av dem.
4. **Historiken:** övningsprovets resultat (A16, `topic` = begreppet) sparas per prov och begrepp med datum.
   **Kvar:** förhörssvaren i Provläge sparas inte än, eftersom appen inte vet vilket begrepp en förhörsfråga gällde.
   Den behöver ett begrepp från /answer (se Till Kevin).
5. **Sammanfattningen vid "avsluta":**
   - **När:** "Lumen, avsluta" eller knappen Avsluta i Provläge, efter minst två egna besvarade frågor.
   - **Anropet:** ett sista /answer med `session_end: true` (fragment "avsluta").
   - **Efter svaret:** Lumen läser upp sammanfattningen. Den sparas som studiekort ("Sammanfattning: Biologi, 10 nov.")
     och tillsammans med passet i Anteckningar, och sedan slutar Lumen.
   - **Om något strular:** ett andra tryck på Avsluta slutar direkt. Ett fel eller 45 s utan svar slutar också.
   - **Inte i:** övningsprovet, provsessionen och minitestet, som har egna slut.
6. **Länkar (K19):**
   - `done.resource` blir en tryckbar rad under svaret med titel, källa ("UR Play") och "kan kräva skolkonto" när
     `login_likely` är sant.
   - Raden finns också i Historik och i den sparade anteckningen (turen bär länken).
   - En notis med titeln skickas också, eftersom telefonen ligger i fickan. Den öppnar länken i Safari. Här frågar iOS
     om notiser första gången, eftersom eleven själv bad om länken.

## Beslut (DECISIONS A19)
- **Notisernas tid:** kl. 16 (`LumenNotifications.planHour`) tills Aron bestämmer, se Till Aron.
- **iOS-frågan om notiser** kommer bara efter ett tryck, eller när eleven bett om en länk.
- **Planens fråga** läses upp när Provläge startas, inte när appen öppnas. Ett tal som hörs utan att man startat något
  bryter mot "Lyssnar bara när du har startat den".

## Tester
`LumenTests/A19Tests.swift`:
- historiken per prov och begrepp, med taket 30;
- begreppen med historik först, sedan provets ämnen utan dubbletter;
- raden "I dag: …";
- förfrågan och svaret (snake case);
- notisen kl. 16, aldrig bakåt i tiden;
- `session_end` och `concept_stats` i /answer;
- `done.resource` avkodas och hamnar på turen.

## Kända begränsningar
- Bara övningsprov fyller historiken i dag (punkt 4).
- **Untested assumption:** att UNUserNotificationCenter-delegaten öppnar Safari från en notis när appen är i bakgrunden.
  Det behöver provas på telefon.
- Planen hämtas varje gång Start visas, inte i bakgrunden. Notiserna för kommande dagar finns ändå kvar, eftersom de är
  schemalagda.
- "Ibland av sig själv när eleven kört fast" (K19) är inte byggt. Kevin föreslår `stuck: true` från appen, och det
  är nästa steg.

## Till Kevin
1. Ett begrepp per förhörsfråga och rättning i Provläge (till exempel `done.concept` och `done.correct`), så att
   historiken för `/study-plan` också fylls av förhör och inte bara av övningsprov.
2. `description` i `/voices` (A26).

## Till Aron
- Ska påminnelsen komma **kl. 16**, som nu, eller vid en annan tid? Det är Kevins fråga i K17. Påminnelserna går att stänga
  av i Inställningar.

## CI
Grönt i CI: iOS build 42796721366 (`9b58004`, med A26, A16 och A19). Bygget för enhet räknar varningar som fel, och alla
LumenTests är gröna, A16Tests, A19Tests och A26Tests inräknade. Skärmbilder från simulatorn: körningarna 42796736014
(iPhone 17 Pro) och 42796744858 (SE), i `reports/2026-11-10-a26-a16-skarmbilder/`.
