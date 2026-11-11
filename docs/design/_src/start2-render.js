// Kelly, Ke29: renderar varje skärm i start2.html till docs/design/bilder/start2/<id>.png (ljust | mörkt).
// Kör från repots rot: node docs/design/_src/start2-render.js
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');
const OUT = 'docs/design/bilder/start2';
fs.mkdirSync(OUT, { recursive: true });
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 900, height: 1000 }, deviceScaleFactor: 1 });
  await p.goto('file://' + path.resolve('docs/design/_src/start2.html'));
  await p.evaluate(() => document.fonts.ready);
  for (const id of await p.$$eval('section.pair', s => s.map(x => x.id))) {
    await p.locator('#' + id).screenshot({ path: `${OUT}/${id}.png` });
  }
  await b.close();
  console.log('klart');
})();
