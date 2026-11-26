# Ke89: Spela in själv – designunderlag och sajten (Kelly (moln), 2026-11-26, D263)

- **Designunderlag** `docs/design/spela-in-sjalv.md` för Angela Fable (A165): en ingång på Start (rad med kapseln
  **Helt gratis**), skärmen för en samling (namn, kort med fråga/svar, Spela in · ▶ · Spela in igen, Lägg till fråga,
  Öva), övningen i samma spelare som proven, bladet vid 402 eller `provider_*` (en gång per tillfälle) och alla ord på
  svenska och engelska. Rad i `angela-fable.md` och meddelande till Fable.
- **Sajten, live:** "**Record it yourself – completely free.**" / "**Spela in själv – helt gratis.**" med en mening om att
  frågorna spelas in med egen röst, utan krediter, och att ljudet stannar på telefonen. (Funktionen byggs nu i A164/A165;
  appen är inte ute, så raden beskriver det som kommer.)
- **Lanseringsbandet inkopplat (Ke88 del 2):** sajten läser `GET /functions/v1/purchase` → `launch_offer` (K119) och visar
  "65 % off everything – launch week" med nedräkning mot `ends_at` bara när det inte är null. I dag null → dolt.
- **Live** (kelly-site-check 45775788008, 07:30 UTC): `/` 200 (41 542 byte), `/sv` 200, `/beta` 200; 393 px utan vågrät
  rullning på alla tre (Chromium i Actions).
- **Granskat på bild (Simulatorn):** A161 (lanseringsrad, överstruket pris, veckokortets första vecka, bladet) och A163
  (Komprimera/Ångra/raden) – inget fel. A160: "Telefonens modell: Rätt." föreslås bli "Rättat på telefonen: Rätt." /
  "Checked on your phone: Right." (orden "modell" säger användaren inget). A162: Arons mening står exakt; rak apostrof
  som i hans text får stå.
