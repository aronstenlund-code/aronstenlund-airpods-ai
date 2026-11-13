// Ke51: skärmbilder av utkastet (mobil 390 och dator 1280, ljust och mörkt) till drafts/site-repetition/bilder/.
// Kör från repots rot: node drafts/site-repetition/shots.js   (playwright eller NODE_PATH + PW_CHROME som i repetition-render.js)
let pw; try { pw = require('playwright'); } catch { pw = require('playwright-core'); }
const path = require('path'), fs = require('fs');
const OUT = 'drafts/site-repetition/bilder';
fs.mkdirSync(OUT, { recursive: true });
(async () => {
  const b = await pw.chromium.launch(process.env.PW_CHROME ? { executablePath: process.env.PW_CHROME } : {});
  const errors = [];
  for (const [name, w, h] of [['mobil', 390, 844], ['dator', 1280, 900]]) {
    for (const scheme of ['light', 'dark']) {
      const p = await b.newPage({ viewport: { width: w, height: h }, colorScheme: scheme, deviceScaleFactor: 1 });
      p.on('pageerror', e => errors.push(`${name}/${scheme}: ${e.message}`));
      p.on('console', m => { if (m.type() === 'error') errors.push(`${name}/${scheme}: ${m.text()}`); });
      await p.goto(process.env.BASE ? process.env.BASE + '/drafts/site-repetition/index.html' : 'file://' + path.resolve('drafts/site-repetition/index.html'));
      await p.evaluate(() => document.fonts.ready);
      await p.waitForTimeout(400);
      await p.screenshot({ path: `${OUT}/${name}-${scheme}.png` });
      if (scheme === 'light') {
        await p.click('#t1'); await p.waitForTimeout(100);
        await p.locator('#rep').screenshot({ path: `${OUT}/${name}-langt-svar.png` });
        await p.click('#t3'); await p.waitForTimeout(100);
        await p.locator('#rep').screenshot({ path: `${OUT}/${name}-paus.png` });
        await p.locator('#kom-igang').screenshot({ path: `${OUT}/${name}-steg.png` });
      }
      await p.close();
    }
  }
  await b.close();
  console.log(errors.length ? 'FEL:\n' + errors.join('\n') : 'inga fel i konsolen');
})();
