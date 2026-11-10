# A23 – Snabba proffsfixar (Angela, 2026-11-10)

Deangelos punkt (Aron 2026-11-10: appen ska inte se ut som en vibe-kodad app). Det mesta byggdes samtidigt med A18
(samma skärmar), så skärmbilderna ligger i A18-rapporten. **Simulator/CI, inget provat på telefon.**

| Delpunkt | Gjort |
|---|---|
| 1. Om appen: licenserna på en egen sida | `AboutView` visar bara löftena, en rad om AI-servern och versionen. Licenslistan ligger under "Licenser" (`LicencesView`). |
| 2. Inställningar | Brytaren "Inget prov just nu" är borta: ett provdatum betyder att det finns ett prov. Hastigheten heter Lugn / Normal / Snabb (0,85 / 1,0 / 1,2) i stället för "1.00×". "Provlyssna" är en vanlig rad. Röstavsnittet är på svenska ("Läs upp svaren", "Röst", "iPhonens röst"; texten var på engelska). Röstens namn med beskrivning väntar på K14:s röster (se Kvar). |
| 3. Start (D97) | Provkortet har **två** knappar: blå **"Förhör mig"** ("Lumen frågar ut dig och svarar på dina frågor") och grå **"Få A-svar till provet"** ("Lumen svarar bara när du frågar"). Namnen är oförändrade. "Få A-svar" startar Provläge utan kontrollfrågor: `provAnswersOnly` gör att tutor-profilen skickas med `Kontrollfrågor: inga` (`ListeningModel.tutorPersona`). Provraderna har inga mikrofonknappar, och instruktionsraden längst ner är borta. |
| 4. Lyssnar | "Avsluta" är neutral (rött bara vid fel). När appen är pausad heter knappen "Lyssna igen" och är blå; när den lyssnar visas "Pausa". |
| 5. Ingen ny funktion | Inget nytt utöver D97:s andra knapp, som redan fanns som "Få A-svar". |

## Testresultat
- **CI:** grönt, run 42773767993.
- **Kelly** granskar bilderna (PLAN 2c).

## Kvar
- Röstens namn med beskrivning ("Svensk, lugn") när Kevins K14-röster har beskrivningar i `/voices`.

## CI
Grönt i CI: iOS build run 42773767993 (commit bda589a): bygget för enhet (varningar = fel) och alla LumenTests gröna.
