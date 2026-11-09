# A9 punkt 2–3 – Kommandon med egna ord och inlärda inställningar (Angela, 2026-11-09)

Kort: appen använder nu Kevins K10.
1. **Kommandon med egna ord.** När backend är säker på ett appkommando ("kan vi byta till frågor") gör appen det
   och bekräftar. "Nej" eller "ångra" inom 5 s tar tillbaka det.
2. **Rättelser blir inställningar.** "Kortare", "enklare", "mer exempel" och "det där var fel" direkt efter ett svar
   går till /memory och blir en inställning med räckvidd.
3. **Minne › Inlärda inställningar.** Inställningarna visas som läsbara rader, går att ta bort eller låta gälla
   överallt, och skickas med varje fråga.

Grönt i CI (körning 42690189387). **Ej verifierat på enhet.** Punkt 1 (tips): `reports/2026-11-09-angela-a9-command-tips.md`.

## Punkt 2: kommandon med egna ord (K10.1)
**Ta emot och utföra**
- `meta.app_command` = `{action, mode?, confidence}` läses (`AppCommand`). Vid säkerhet ≥ 0,8 anropas
  `answerAppCommand`. Det kommer inget svar, så bekräftelsen är appens.
- **Vad varje kommando gör:**
  - `switch_mode` → samma lägesbyte som rösten, som säger lägets namn (D74);
  - `pause` → "Pausar.";
  - `stop` → "Slutar lyssna.";
  - `resume` → lyssnar igen.
- **Lägre säkerhet:** svaret kommer som vanligt, och appen gör ingenting. Att erbjuda kommandot ("Menar du …?") är
  inte byggt.

**Ångra**
- "nej", "ångra", "fel", "det var fel" eller "inte det" som hela yttrandet inom 5 s gör kommandot ogjort:
  - lägesbyte → tillbaka till förra läget;
  - paus → fortsätt;
  - stopp → starta igen i samma läge.
- Lumen säger "Okej, ångrat."
- Ångra kontrolleras före klagomålen, så "det var fel" direkt efter ett appkommando ångrar i stället för att
  rapportera.

**"Lumen" krävs fortfarande utom i Prov och Frågor.** Backend sköter det: K10 skickar bara kommandot där.

## Punkt 3: inlärda inställningar (K10.2–3)
**Rättelserna**
- "Lumen, svara kortare", "kortare", "längre", "förklara enklare", "ge ett exempel" och "det där var fel" inom
  120 s efter ett svar skickas till `POST /memory` med `correction: {text, context}` och hela listan som `settings`.
- Kontexten:
  - läge (backendnamn);
  - ämne och prov i Provläge;
  - svarstyp: matte om ämnet är Matematik, annars från svarets `answer_type` (study = explanation, fact = fact).
- Svarets lista ersätter den sparade (`PreferenceStore`, UserDefaults, högst 30).
- Det lokala som A7 gör (sessionens längd, rapporten) sker som förut.

**Varje /answer skickar**
- `preferences` (listan);
- `pref_profile` (gjord i telefonen med samma regler som `profileOf`, högst 300 tecken);
- `pref_context: {subject, exam}`.
- Utan inlärda inställningar skickas inget.

**Minne › Inlärda inställningar**
- Raderna har samma ord som Kevins `describe()`: "Kortare svar i matte", "Fler exempel inför Geografiprovet".
- Svep för **Ta bort**, eller **Överallt** för att vidga räckvidden. Det ersätter de smalare raderna med samma
  innebörd.
- Det är den ändring som går att göra. Byta värde (kortare ↔ längre) görs genom att säga det.

## Tester (`LumenTests/A9bTests.swift`, gröna i 42690189387)
- `app_command` och `answer_type` läses ur meta.
- Inställningarna skickas med i rätt form, och utan inställningar skickas inget.
- Raderna läses som backendens.
- Ångra-orden gäller bara hela yttrandet, och lägesnamnen översätts.
- Listan sparas, profilen byggs, ta bort och "Överallt" fungerar.
- Säkert kommando: paus → "nej" → lyssnar igen. "Nej" utan kommando gör ingenting.

## Kvar och risker
- **Ångra efter paus eller stopp går inte att säga på riktigt**, eftersom Lumen inte lyssnar då. Det fungerar för
  lägesbyte, och för paus och stopp bara som kodväg.
- **Rättelser utan "Lumen"** (som "för långt") skickas inte om de inte är ett av A7:s kommandon. Backend känner igen
  fler formuleringar än appen skickar.

## Till Toby
- Lägg in i T6:
  - "kan vi byta till frågor" i Provläge → Frågor, och "nej" direkt efter → tillbaka;
  - "kortare" efter ett svar → raden "Kortare svar i …" i Minne.
- **Ändrade texter:** Minne har en ny sektion, "Inlärda inställningar".

## Concerns
Inga.
