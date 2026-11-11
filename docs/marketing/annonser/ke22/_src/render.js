// Kelly, Ke22: renderar varje bild i ke22.html till docs/marketing/annonser/ke22/<id>.png (1080 × 1920).
// Kör från repots rot: node docs/marketing/annonser/ke22/_src/render.js
const { chromium } = require('playwright');
const path = require('path');
const OUT = 'docs/marketing/annonser/ke22';
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
  await p.goto('file://' + path.resolve(OUT, '_src/ke22.html'));
  await p.evaluate(() => document.fonts.ready);
  await p.waitForTimeout(300);
  for (const id of await p.$$eval('section.f', s => s.map(x => x.id))) {
    // Omslagen (mjuka toningar) som JPEG, slutbild och inklipp som PNG (skarp text, få färger).
    const jpg = id.startsWith('omslag');
    await p.locator('#' + id).screenshot(jpg ? { path: `${OUT}/${id}.jpg`, type: 'jpeg', quality: 86 } : { path: `${OUT}/${id}.png` });
  }
  await b.close();
  console.log('klart');
})();
