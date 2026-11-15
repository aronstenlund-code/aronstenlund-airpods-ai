# Kelly (moln): granskning av A109 (påminnelsen, D194) på bild

Underlag: grenarna `fable/screens-a109-17pro-1` (körning 43735883325, 2174824, iPhone 17 Pro) och
`fable/screens-a109-se-xxxl-1`/`-2` (iPhone SE, största text). Scener repReminderAsk, repReminderSettings,
repReminderDenied och settings. Granskat mot `docs/design/repetition-texter.md` §14. **Simulatorn, inte enhet.**
Angela Fables rapport fanns inte på main när jag granskade; bilderna gick att hämta från grenarna.

## Resultat: godkänd med P1–P2 (medel) och P3–P4 (låga)
Alla texter är ordagrant §14: frågan (Vill du ha en påminnelse? / Påminn mig / Inte nu / fotnoten), Inställningar
(Påminn mig att plugga, Tid 18:00, fotnoten) och notiser avstängda (Öppna Inställningar, "Notiser är avstängda för
EarMind."). Inga utropstecken. Mörkt läge utan fel.

| # | Nivå | Var | Fynd | Rättning |
|---|---|---|---|---|
| P1 | medel | settings | Två avsnitt för samma sak: **Påminnelse** (Påminn mig att plugga, 18:00) och det gamla **Påminnelser** (Påminn mig varje dag, 16:00, lyssningslägets studieplan). Två reglage med nästan samma namn och två tider. | I Inställningar bara **Påminnelse** (D194). Det gamla flyttas till Fler lägen-sidan som **Studieplan · Beta** med sin egen tid, eller tas bort om Deangelo hellre vill det. Kör båda vore två notiser samma kväll. |
| P2 | medel | repReminderAsk, SE största text | Raden under rubriken klipps av under knapparna ("EarMind kan påminna dig klockan 18 d…"), och man kan inte skrolla till resten. | Bladets innehåll i en `ScrollView`, knapparna fasta nederst (som MainActionBar). |
| P3 | låg | repReminderAsk, SE största text | "?" hamnar ensamt på en egen rad ("påminnelse / ?"). | Mindre rubrikstil vid `.accessibility1` och uppåt (`.title2`), eller `minimumScaleFactor(0.8)` på rubriken, så att ordet och tecknet står ihop. |
| P4 | låg | repReminderAsk, 17 Pro | Bladet är högt med en stor tom yta mellan texten och knapparna. | `presentationDetents` som passar innehållet (till exempel `.height` eller `.medium`). |

Avsnittsrubriken står som "Påminnelse" i stället för mina versaler "PÅMINNELSE". Det är iOS 26:s stil, och det godtas.

## Nästa steg
- Angela Fable: P2 först, sedan P3–P4. P1 behöver Deangelos ja (vart lyssningslägets studieplan tar vägen).
- Deangelo: P1.

## Omgång 2 (2026-11-15 18:29): P2–P4 godkända
Bilder: grenarna `fable/screens-a109-17pro-2`, `-se-1` och `-se-xxxl-3` (körningar 43739964928, 43739970576, 43739967798, edf5d3a).
- **P2:** texten ligger i en `ScrollView` med knapparna fasta nederst (`safeAreaInset`, ReminderViews.swift). På stillbilden
  fortsätter texten under knapparna, som den ska. Att den går att skrolla är sett i koden, inte provat.
- **P3:** "påminnelse?" står ihop i största text. Godkänt.
- **P4:** bladet är `.medium` och passar innehållet på 17 Pro och SE. Godkänt.
- Kvar: **P1** hos Deangelo.
