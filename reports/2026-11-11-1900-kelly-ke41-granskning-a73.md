# Kelly Ke41: granskning av A73, rätt text om ljud (2026-11-11 19:00)

Underlag: Angelas A73 (8afb5bc, `reports/2026-11-11-1850-angela-a73-ljudtext.md`), granskat i koden (texterna), mot
D138: "Ljudet blir text och sparas inte av Earmind. Sömnläget sparar klippen bara på din telefon."

## Omdöme: **godkänd**, med en rättelse (L1)
Meningen står ordagrant i introts lista (`FirstStartView.swift` 152), på Första frågan (231), i Om appen
(`AboutView.swift` 9 och 13), i samtycket (`ConsentView.swift` 35 och 41) och i mikrofonfrågan
(`InfoPlist.xcstrings`). Inget "Ljud sparas inte" eller "Ljud sparas aldrig" syns längre i appen. Det här stänger
G3 (Ke33–Ke36).

## Fynd
| # | Var | Fynd | Förslag | Prio |
|---|---|---|---|---|
| L1 | Om appen › Licenser (`AboutView.swift` 38) | "ElevenLabs Scribe … Ljudet skickas för att skrivas ut och sparas inte." Det påstår något om ElevenLabs som vi inte vet; D135 säger att ElevenLabs kan spara enligt sina villkor | "Ljudet skickas för att skrivas ut. ElevenLabs hanterar det enligt sina villkor." | Medel |
| L2 | Samtycket | Ljudmeningen står två gånger (punkt 1 och punkt 3) | Behåll den i punkt 1 ("Talet skrivs ut av ElevenLabs"); punkt 3 handlar om text | Låg |
| L3 | `Localizable.xcstrings` | Två oanvända gamla poster ("Audio is not stored" → "Ljudet sparas inte", "No audio is saved." → "Inget ljud sparas.") och en med "Lumen's answers"; ingen kod använder dem | Ta bort vid tillfälle, så att de inte kommer tillbaka av misstag | Låg |

**Ej verifierat på enhet** (texterna lästa i koden). Kostnad: API 0 USD, ElevenLabs 0 tecken.
