# Ljudtest med bakgrundsljud (Deangelo, 2026-11-10 07:40–08:05)

Hela kedjan utan telefon: tal från `/tts` (Adam, Saga, Max) → bakgrundsljud → AirPods-likt filter (100–7000 Hz) → Scribe v2 Realtime som appen (stt-token, VAD, keyterms från profilen i Provläge) → `/answer` (Frågor = auto, Provläge = tutor + profil). 62 fall, varje i ett roterande ljud, 16 fall i alla sex ljud = 142 körningar. Skript `scripts/qa/deangelo_audio.py`, rådata `reports/qa/data/2026-11-10-deangelo-audio.json`. /answer 1,02 USD + ElevenLabs-tecken för TTS och Scribe-minuter (inte uppmätt).

**Begränsning (viktig):** talet är syntetiskt och tydligt. Riktiga tonåringar, en lärare 3 m bort och den riktiga AirPods-mikrofonen är svårare. **Ej verifierat på enhet.**

## Taligenkänning per ljud (nyckelordet hört)
| Ljud | Körningar | Nyckelord hört | Ordagrant |
|---|---|---|---|
| Tyst | 23 | 23 | 18 |
| Klassrumsprat 10 dB | 21 | 21 | 16 |
| Matsal 5 dB (prat + klirr) | 19 | 18 | 13 |
| Tunnelbana 5 dB (mullrande brus) | 22 | 22 | 20 |
| Musik 10 dB | 17 | 17 | 14 |
| Vind/gata 8 dB | 18 | 17 | 15 |
| **Totalt** | **120** | **118 (98 %)** | **96 (80 %)** |

Det enda riktiga hörfelet: matsal, Saga: "Hur länge ska man koka pasta?" → "Hur länge ska man koda först då?" (Lumen var tyst, rimligt).
"Ordagrant" missar mest skiljetecken och siffror ("20 % av 400"), som Lumen förstår ändå.

## Beteende (svar när det ska, tyst när det ska)
- **99 av 101** rätt (19 körningar i musik/vind fick inget /answer-anrop när budgeten tog slut).
- Tyst rätt på alla "inte frågor" i alla ljud: "Öppna boken på sidan fyrtiotvå", "Har du gjort läxan?", "Kan du räcka mig suddet?", "Mamma, jag kommer snart".
- Fel: "Förklara enklare." ensamt i Provläge utan tidigare svar → tyst (kan försvaras), och hörfelet ovan.
- Första text p50 1,27 s, max 5,2 s.

## Fynd
1. **Scribe stänger anslutningen (1008 invalid_request) i 22 av 39 strömmar** när keyterms-listan innehöll vissa termer (Historia och Samhällskunskap). Testskriptet kortar inte termerna som appen gör sedan A14, så det är **troligen** skriptets fel, inte appens. Men om appen någon gång skickar en term Scribe inte tål blir Lumen döv i hela passet. → Oscar: hitta exakt vilken regel Scribe har (längd, antal ord, tecken) och kontrollera att appens filter täcker den.
2. Bakgrundsljud är **inte** den svaga länken med tydligt tal. Nästa risk är riktiga röster och avstånd. → Aron: spela in 2 minuter i ett riktigt klassrum eller kök (Diagnostik › Spela in plugg-session), så kör Oscar samma kedja på det.
