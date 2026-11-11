# Kelly Ke34: granskning av A52, A54 (och A53) (2026-11-11 11:28)

Underlag: CI "Simulator screenshots" 42999887377 på main 7444c47, iPhone 17 Pro, ljust och mörkt. Körningen hade
också Mina svar (A53, d846660), så den är med. Jämfört mot `docs/design/start-vadkan.md`, `mina-svar.md`,
`logo/rostning/vektor/README.md` och SYSTEM.md. Bilder: `reports/2026-11-11-a52-a54-granskning/` (g1 Vad kan
Lumen?, bladet och röstningen; g2 tack, Mina svar tom och lista; g3 redigering, Start, Välj läge).

## Omdöme
| Punkt | Omdöme |
|---|---|
| **A52 Vad kan Lumen?** | **Godkänd.** Raderna och orden som i Ke29, verklig status ("Behöver tillgång till Kalender" + Tillåt), Spotify och Ring "Kommer snart". Bladet "Lumen kan mer än svara" med tre exempel och "Visa allt Lumen kan". Start har nu "Allt Lumen kan ›" (Ke33 G1 stängd). Timer visar larmbehörighet; det är riktigt eftersom appen använder Apples larm för timern. |
| **A54 Röstningen** | **Godkänd med V1.** Bilderna är exakt mina mörka vektorer (medelavvikelse 0,0 mot `*-mork-1024.png`), 96 pt i en rad, iOS-maskens hörn, ordningen slumpad per användare (B, A, C i bilden) och sparad, namnen under, "Rösta" och "Senare", inget som gynnar någon. Tackskärmen med staplar i blått. |
| **A53 Mina svar** (extra) | **Godkänd med M1.** Proven som runda val (bättre än min rullgardin), tomläget med mina ord, listan med "Inspelat", redigeringen med LUMENS FÖRSLAG ovanför DITT SVAR, ⋯ och Spara. Provkortet har "Mina svar · 3 sparade ›". Utskriften av inspelningen sker på telefonen, så Scribe-frågan från Ke30 försvinner. |

## Fynd
| # | Var | Fynd | Förslag | Prio |
|---|---|---|---|---|
| V1 | Röstningen | "Rösta" är avstängd tills man valt (`.disabled`), men `LumenButtonStyle` ändrar inte utseendet, så knappen ser tryckbar ut fast inget händer | I `LumenButtonStyle`: läs `@Environment(\.isEnabled)` och visa avstängd som `surface`-yta med `muted` text (eller 40 % opacitet). Gäller alla blå knappar | Medel |
| V2 | Röstningen | Mycket tom yta mellan ikonerna och knapparna | Valfritt: ikonerna 104 pt, eller raden närmare mitten. Inte nödvändigt | Låg |
| M1 | Mina svar, redigering | "Använd förslaget igen" är halvfet bläck, inte en blå textknapp (SYSTEM.md: textknapp = blå) | Blå 15 semibold | Låg |
| G2 | Välj läge | Kvar från Ke33: alla lägen har blå ikon i mjuk cirkel | Grå ikon för ovalda | Låg |
| G3 | Intro, Första frågan, Om | "Ljud sparas inte" (FirstStartView 146 och 225, AboutView 9). Sömnläget sparar klipp på telefonen, och Mina svar spelar in | Deangelo avgör orden. Mitt förslag: ”Ljud sparas bara när du själv spelar in eller använder Sov.” | Före nästa testare |

## Inte granskat
- Inspelningsskärmen och Lyssnar med "Ditt svar" fanns inte i körningen; koden har dem (`ListeningScreen.swift` 193).
- iPhone SE och största text: Tobys runda.
- **Ej verifierat på enhet.** Kostnad: API 0 USD, ElevenLabs 0 tecken.
