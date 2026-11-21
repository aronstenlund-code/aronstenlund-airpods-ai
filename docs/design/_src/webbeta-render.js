// Kelly Ke86: render the web beta sketch (docs/design/_src/webbeta.html) to docs/design/bilder/webbeta/<lang>-<mode>.png
const { chromium } = require('playwright'); const path = require('path');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 846, height: 892 }, deviceScaleFactor: 2 });
  const src = 'file://' + path.resolve(__dirname, 'webbeta.html');
  for (const v of ['en-light', 'en-dark', 'sv-light', 'sv-dark']) {
    await p.goto(src + '?v=' + v);
    await p.screenshot({ path: path.resolve(__dirname, '../bilder/webbeta/' + v + '.png') });
  }
  await b.close(); console.log('klart');
})();
