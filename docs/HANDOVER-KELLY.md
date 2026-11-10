# Överlämning: Kelly (demosidan och design), session 2026-11-10 kväll (Ke23, Ke25–Ke28)

Det här står inte i rapporterna (`reports/*kelly*`).

## Verktyg
- Förhandsvisning: `python -m http.server 8765 -d site` (sidan) och `8790` från repots rot (skisser i `docs/design/_src/`).
- **Mät med puppeteer-core@23** (scratchpad, `npm i puppeteer-core@23`). Chrome headless med `--window-size` klipper
  under ca 500 px och ignorerar mörkt läge. Använd `setViewport` och `emulateMediaFeatures`.
- Text på bilder med PIL: gör om `site/fonts/familjen-grotesk.woff2` till TTF med fontTools (`flavor=None`), sedan
  `set_variation_by_axes([vikt])`. Python via heredoc tolkar å/ä/ö fel i `str.replace`: lägg skriptet i en fil eller använd Edit.
- PNG med `quantize(128)` tar bort små färgprickar. Ta JPEG när bilden har statusfärger.
- **App Store-bilder:** kör workflowen "Simulator screenshots" (workflow_dispatch, `device: iPhone 17 Pro Max` ger
  1320×2868). Ladda ned artefakten via API med token från `git credential fill`, och kör sedan
  `docs/marketing/appstore/_src/appstore.py`.
- Lighthouse: `npx -y lighthouse … --blocked-url-patterns="*supabase.co*"` (senast 100×4, 20:24).
- **Varumärken:** EUIPO eSearch fungerar i den inbyggda webbläsaren, men ladda om sidan för varje sökning
  (hash-byte visar förra resultatet). TMview spärrade efter ca 15 sökningar ("Problem detected"). Försök inte ta dig förbi.

## Fallgropar
- Delad checkout: andras ändringar ligger osparade. `git add <mina filer>` och kontrollera `git diff --cached --name-only`
  före commit. Ett delat dokument med andras osparade rader (DECISIONS): lägg bara in min rad i indexet
  (`git hash-object -w` + `update-index --cacheinfo`). Nekad push: `git pull --rebase --autostash`, och kontrollera
  sedan "Applied autostash". I `git stash list` låg två gamla autostash-poster som inte är mina; de är orörda.
- Deangelo ändrar köpunkter medan jag jobbar (Ke23 fick tre namn till 19:57). Läs om `kelly.md` före varje statusändring.
- Kör `date` innan du skriver en tid.

## Öppna trådar
- **Ke24** väntar på Arons nummer (jag rekommenderar 4). Underlag: `docs/design/namn/storlekar.png`.
- **Namn:** jag rekommenderar Earmind (Earwise är rött). PRV är inte kontrollerat. Slutbilder till annonserna finns för
  fem namn i `docs/marketing/annonser/slutbild/`; gör en för Earmind när namnet är bestämt (`_src/slutbild.py`).
- **App Store (Ke25):** integritetspolicy saknas (`site/integritet.html` när Aron säger ja). Bild 1–2 visar Lumen
  och radiovågorna och byts efter Ke24.
- **"Ljud sparas inte"** blir osant med A49 (sömnläget). Deangelo avgör texten.
- **Elias hörlur är vit och Apple-lik** (F1 i Ke28): ny bild behövs före App Store.
- Safari och iPhone är fortfarande inte provade för sidan.
