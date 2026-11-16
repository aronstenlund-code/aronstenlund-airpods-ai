// Kelly, Ke69: renderar varje skärm i sag.html till docs/design/bilder/sag/<id>.png (ljust | mörkt).
// Kör från repots rot: node docs/design/_src/sag-render.js
// Utan playwright i repot: NODE_PATH=<mapp med playwright-core> och PW_CHROME=<sökväg till chrome>.
let pw; try { pw = require('playwright'); } catch { pw = require('playwright-core'); }
const path = require('path');
const fs = require('fs');
const OUT = 'docs/design/bilder/sag';
fs.mkdirSync(OUT, { recursive: true });
(async () => {
  const b = await pw.chromium.launch(process.env.PW_CHROME ? { executablePath: process.env.PW_CHROME } : {});
  const p = await b.newPage({ viewport: { width: 900, height: 1000 }, deviceScaleFactor: 1 });
  await p.goto('file://' + path.resolve('docs/design/_src/sag.html'));
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(300);
  const only = process.argv[2];
  for (const id of await p.$$eval('section.pair', s => s.map(x => x.id))) {
    if (only && id !== only) continue;
    await p.locator('#' + id).screenshot({ path: `${OUT}/${id}.png` });
  }
  await b.close();
  console.log('klart');
})();
