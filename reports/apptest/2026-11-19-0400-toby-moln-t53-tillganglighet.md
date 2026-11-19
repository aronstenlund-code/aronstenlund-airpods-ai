# T53 – Tillgänglighet i apptesterna (A148, Kelly Ke79)

Toby (moln), 2026-11-19 04:00. Simulatorn (iPhone 17 Pro, iOS 26, Xcode 26.6). Största texten (`simctl ui content_size accessibility-extra-extra-extra-large`). Riktig server med x-earmind-test, falskt ljud, 0 ElevenLabs. **Allt är verifierat i Simulator** (VoiceOver-etiketterna ur XCTest-trädet, granskningen med Xcodes `performAccessibilityAudit`), **inte med VoiceOver på enhet.**

## Vad som gjordes
- SayFlowTests fick ett tillgänglighetsläge (`LUMEN_T36_A11Y=1`).
  - Det körs av det nya `scripts/apptest/t53.sh` och `.github/workflows/apptest-t53.yml`, som är kopior av t36.
  - På första skärmen, det spelande kortet, Senaste, kreditbladet och Radera konto läser testet Kellys Ke79-ord.
  - Höjderna på Villkor, Integritet och Återställ köp mäts.
  - Xcodes tillgänglighetsgranskning körs på varje skärm. Fynden skrivs ut men gör inte testet rött.
- Radera konto i T53 trycker bara Avbryt. Ingenting raderas.

## Resultat (körningar 44436344437, 44439180352, 44444292610, 44449376221)
| Ke79 | Läses | |
|---|---|---|
| 2 Fältet | "Säg i AirPods" | OK |
| 3 Kostnaden | "Kostar 93 krediter" | OK |
| 8 Tempot | "Tempo, normal" | OK |
| Hur länge | "Hur länge, 10 minuter" | OK |
| Spela | "Spela i 10 min" | OK |
| 9 Kortet som spelar | "Spelar i AirPods med Adam, 9 minuter kvar" (pausad: ", pausad") | OK i T36 med standardtext. Vid AX5 nådde testet inte Spela, se nedan |
| 4 Senaste | hela texten: "Klorofyllet i bladen fångar ljuset. Växten gör socker av vatten och koldioxid. Körning N." | OK i T36 med standardtext |
| 7 Bäst värde | – | otestat: inga produkter i ett UI-test |
| Villkor, Integritet, Återställ köp | 52 punkter höga vid AX5 | OK (minst 44) |
| Radera konto | frågan "Radera kontot?" med knapparna "Radera konto" och "Avbryt" vid AX5 | OK |

**Xcodes granskning vid AX5** (fynd, inte rött):
- Start, med text i fältet:
  - contrast 4: "Du kan låsa telefonen. Det hörs i AirPods ändå." och "Kom förberedd till provet".
  - dynamicType 5: "delvis stöd" för "1,5k krediter kvar", "Hur ska det låta?", "Adam", fältet och raden om låst telefon.
  - sufficientElementDescription 2–3: ett element utan namn, 44 pt högt.
- Kreditbladet: contrast och dynamicType på "Klar" i bladets list (systemets knapp).
- Inställningar › Konto: dynamicType 2–3, textClipped 1–2 (vilken text syns inte i trädet).
- Kelly bedömde i Ke79 att kontrastfynden på grå hjälptext och avstängda knappar inte är fel. Raderna ovan är vanlig text, så de skickas ändå till henne.

## Det som inte gick, och varför (testet, inte appen)
- **Spela vid AX5:** knappen ligger på skärmen (y 670–714 av 874), är påslagen men "inte tryckbar" för XCTest. Tangentbordet var kvar uppe efter att fältet fyllts, och tangenterna (skift, retur) stod i trädet. Testet fick inte ner tangentbordet vid AX5, varken genom att trycka utanför eller svepa. Därför nåddes varken kortet som spelar eller Senaste vid AX5.
- Punkt 9 och 4 är kontrollerade med standardtext i T36 (44444292560 och 44449376312, båda gröna i alla 15 delar).
- Att tangentbordet inte går att stänga utan att trycka på något fält vid AX5 kan vara värt att titta på (untested assumption: på telefon finns tangenten "Klar" eller nedsvepning).

## Nästa
- t53.sh skriver nu också "keyboard"- och "scrollIntoView"-rader, så att nästa körning visar vad som hände med tangentbordet.
- T36:s tester är ihopslagna med main (03:1x). T53-läget finns på main men körs bara med t53.sh.
