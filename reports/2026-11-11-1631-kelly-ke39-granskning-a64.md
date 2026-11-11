# Kelly Ke39: granskning av A64, största text (2026-11-11 16:31)

Underlag: Tobys skärmtur i T13 (`reports/apptest/2026-11-11-t13/tur-pro-dark-storsta-text-*.jpg`, mörkt, största
text, simulatorn), mot SYSTEM.md avsnitt 10 (Ke37).

## Omdöme: **godkänd**
| Regel (avsnitt 10) | På bilderna |
|---|---|
| 1 Inga ord bryts mitt i | Ja: "Standardläge" hel, "NÄSTA PROV" hel, "Mina svar" hel |
| 2 Rader med två delar staplas | Läget och "Byt", rubriken och "7 dagar kvar", datumet och "Ändra", "Mina svar" och "Lägg till ›" |
| 3 Versalrubriker på en rad | "NÄSTA PROV" på en rad |
| 4 Stora rubriker kapas inte | "Vad kan Earmind?" bryts i innehållet, liten rubrik i navigationsraden |
| 5 Hjälptext kapas inte | "Earmind frågar ut dig och svarar på dina frågor" på tre rader |
| 6 Loggan följer texten | Ja, i rubriken |

## Små rester
| # | Var | Fynd | Prio |
|---|---|---|---|
| S1 | Start, lägesraden | Frågetecknet framför "Standardläge" skalar inte (litet bredvid stor text). Samma som regel 6: `@ScaledMetric` eller `.imageScale` som följer texten | Låg |
| S2 | Lyssnar, navigationsraden | Underrubriken kapas: "Svarar när någon fråg…". Regel 5: låt den gå på två rader, eller dölj underrubriken vid största text (läget står redan i rubriken) | Låg |

"Här startar du Earmind" tar mycket plats vid största text, men knappen syns direkt under, och rutan visas bara en gång.

## Kvar sedan tidigare
G3 "Ljud sparas inte" (Ke36) och K1 "Dela historik" grå (Ke38) har ingen punkt i Angelas kö.

**Ej verifierat på enhet.** Kostnad: API 0 USD, ElevenLabs 0 tecken.
