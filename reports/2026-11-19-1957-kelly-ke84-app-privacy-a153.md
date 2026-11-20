# Ke84: App Privacy-svaren och granskningsanteckningarna klara, och A153 (Kelly (moln), 2026-11-19, D238, D239)

**Inget är inlagt i App Store Connect och inget publicerat.**

## 1. App Privacy (`docs/appstore/granskning.md` §2b) – klar att klicka in
Engelska som i Apples formulär, en rad per datatyp (collected, linked, tracking, purposes). Tracking: No överallt.
Efter Angela Schrutes A152 (`PrivacyInfo.xcprivacy`, svar ur koden på §2 punkt 3–4):
- **Other User Content** får syftet **Analytics** (frågeloggarna, ej kopplade, högst 14 dagar; delad historik, frivillig,
  kopplad, högst 12 månader).
- Ny rad **Customer Support** (rapporter: "Fel svar?", "rapportera", Feedback och förslag; kopplad, högst 90 dagar).
- **Minnen** sparas inte på servern → inte "collected".
- Foton och köphistorik stängda ur koden (raderas inom en timme; `/purchase`).
Kvar som **[O]** i filen är bara sådant som måste provas på telefon (låst skärm, AirPods-modeller, orange prick).

## 2. Granskningsanteckningarna (§3) – klara att klistra in
Sex punkter på engelska: Säg i AirPods med stil och röster, prov, Fler lägen med samtycke och indikator, krediter
(1 500 i månaden, inbjudan, paket, veckokort, köp verifieras), konto och Radera konto, högtalare. Varje påstående
kontrollerat i koden (listan under texten). **Inget om 5 000 välkomstkrediter (D239)** och inget om låst skärm.

## 3. D239: inga löften om välkomsten förrän Team ID
App Store-beskrivningen, bild 8 ("Börja gratis. 1 500 krediter ingår varje månad.") och demosidan säger 1 500 i månaden;
5 000 läggs till när välkomsten är på. Demosidan pushad och Vercels gren snabbspolad (d266506).

## 4. Ke78-utkastet (grenen, inte publicerat)
Analysavsnittet skrivet om efter A152: frågeloggar 14 dagar, rapporter 90 dagar, delad historik 12 månader (commit
611cbbb, bilder tagna om). 15 → **14 overifierade punkter** (9 i integritet, 5 i villkor).

## 5. A153 (Angela Fable): Spela över tangentbordet vid största texten
Bilder `fable/screens-a153f-*` (sammanställda i `reports/2026-11-19-ke84-bilder/`), **sett i Simulatorn, inte på telefon**:
en Spela åt gången, tät remsa (inget syns igenom på SE AX5), kostnaden läsbar ("Spela 120 krediter", "Fyll på 120
krediter"), ▶ först i stilraden. **Godkänt.** Granskat på Fables gren; A153 var inte på main vid granskningen.

## Beslut kvar (Deangelo/Aron, hög)
**Frågeloggen i repetitionsläget (A152 punkt 3 b) har inget samtycke** och nämns inte i Välkommen. Antingen en mening i
Välkommen › Läs mer och i policyn, eller av i App Store-versionen. App Privacy-svaren gäller som koden är i dag.

## Tillägg: A153 på main (2026-11-19 20:30, `reports/2026-11-19-a153-bilder/`)
Arken (17 Pro och SE, standard och största text, ljust och mörkt) stämmer med det godkända: kostnaden inne i Spela
("Spela 120 krediter"), remsan tät ända ner till tangenterna, "Fyll på 120 krediter" vid 88 kvar, ▶ i stilraden grå när
krediterna inte räcker. **Godkänt på main** (sett i Simulatorn, inte på telefon).
