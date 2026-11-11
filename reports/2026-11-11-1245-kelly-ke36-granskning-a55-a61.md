# Kelly Ke36: granskning av A55–A61 (2026-11-11 12:45)

Underlag: CI "Simulator screenshots" 43011221122 på main dd8acc9 (efter A59 och A60), iPhone 17 Pro, ljust och mörkt.
A61 (byggd efter körningen) är kontrollerad i koden. Bilder: `reports/2026-11-11-a55-a61-granskning/` (h1 Start och
Vad kan Earmind?, h2 röstningen, Välj läge och Första frågan, h3 Lyssnar, Om appen och Inställningar).

## Omdöme: **godkänd**, med ett öppet fynd (G3)
| Punkt | Vad jag såg |
|---|---|
| A55 Earmind | "Earmind" i rubriken, på knappen ("Starta Earmind"), i "Earmind kan allt", "Allt Earmind kan ›" och "Vad kan Earmind?". Väckningsordet "Lumen" står kvar i citaten (D128). |
| A57 Ke28/G2 | Välj läge: grå ikoner utan cirklar, bara det valda blått med ✓ och `soft`. **G2 stängd.** |
| A58 Ring | Ring finns i Vad kan Earmind? med Kontakter (koden); "Använd förslaget igen" blå (**M1 stängd**). |
| A59 V1 | "Rösta" är grå med muted text tills man valt en logga. **V1 stängd.** |
| A60 Ke35 | Start har "Här startar du Earmind" med × och den mjuka ringen runt knappen, som i skissen. Tom Lyssnar och en fråga i Provläge finns i koden och testerna (A60Tests); de fotas inte i körningen. |
| A61 Ke35 | "Bytte till …" (13, muted) mellan svaren när läget byts; i koden. |

## Öppet: G3 "Ljud sparas inte" är osant (femte gången, nu högsta prio)
Kontrollerat i koden (**ej på enhet**):
- **Sov** sparar klipp på telefonen i högst 30 dagar (`Lumen/Core/Sleep/SleepNight.swift` 85 och 126).
- **Mina svar** spelar in till en tillfällig fil som raderas efter utskriften (`Lumen/Core/Study/AnswerRecorder.swift`
  43, 51, 87, 100). Den gör inte texten osann.

Texten står på tre ställen: introts lista ("Ljud sparas inte", `FirstStartView.swift` 146), Första frågan ("Ljud sparas
inte.", 225) och Om appen ("och ljud sparas inte" och "Ljud sparas aldrig", `AboutView.swift`). Det är samtyckets ord
(skyddet i RESTRIKTIONER del B), så det ska stämma innan nästa testare. Ingen kö har det som punkt. Oscars O34 hörde
också modellen säga det (8/11).

**Förslag (ordagrant, sant enligt koden):**
- Introt: "Ljud sparas bara i Sov, på telefonen"
- Första frågan: "iOS frågar om mikrofonen första gången. Ljud sparas bara i Sov, på telefonen."
- Om appen: "Earmind lyssnar bara när du har startat den, och du ser alltid när den lyssnar. Ljud sparas inte, utom
  klippen från Sov: de ligger bara på telefonen i högst 30 dagar, och du kan radera dem."

## Till Deangelo
Lägg G3 som punkt hos Angela (texterna ovan) och be Kevin ta bort "ljud sparas inte" ur modellens svar om appen.

## Test
CI-bilder i simulatorn och koden. **Ej verifierat på enhet.** Kostnad: API 0 USD, ElevenLabs 0 tecken.
