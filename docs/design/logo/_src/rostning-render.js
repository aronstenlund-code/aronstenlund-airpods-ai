// Kelly, Ke31: gör PNG av röstningsikonerna och en kontrollbild i 60 pt och 29 pt, ljust och mörkt.
// Kör från repots rot: node docs/design/logo/_src/rostning-render.js
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const DIR = 'docs/design/logo/rostning/vektor';
const KEYS = [['A', 'klotet', 'A · Klotet'], ['B', 'grona-formen', 'B · Den gröna formen'], ['C', 'orange-ringen', 'C · Den orange ringen']];

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });

  // 1. PNG 1024 av varje SVG.
  for (const [k, n] of KEYS) for (const m of ['mork', 'ljus']) {
    const svg = fs.readFileSync(path.join(DIR, `${k}-${n}-${m}.svg`), 'utf8');
    await page.setContent(`<html><body style="margin:0">${svg}</body></html>`);
    await page.locator('svg').screenshot({ path: path.join(DIR, `${k}-${n}-${m}-1024.png`) });
  }

  // 2. Kontrollbild: hemskärm ljus/mörk, 60 pt (@3x = 180 px) och 29 pt (@3x = 87 px), plus förlagan.
  const uri = (k, n, m) => 'data:image/svg+xml;base64,' + Buffer.from(fs.readFileSync(path.join(DIR, `${k}-${n}-${m}.svg`))).toString('base64');
  const orig = (k, n) => 'data:image/png;base64,' + fs.readFileSync(`docs/design/logo/rostning/${{A: 'A-klotet', B: 'B-grona-formen', C: 'C-orange-ringen'}[k]}.png`).toString('base64');
  const ic = (src, pt) => `<img src="${src}" style="width:${pt}px;height:${pt}px;border-radius:${pt * 0.2237}px;display:block">`;
  const col = (k, n, label, m, bg, ink) => `
    <div class="col">
      <div class="lab" style="color:${ink}">${label}</div>
      <div class="row">${ic(uri(k, n, m), 60)}${ic(uri(k, n, m), 29)}</div>
    </div>`;
  const panel = (m, bg, ink, title) => `
    <div class="panel" style="background:${bg}">
      <div class="title" style="color:${ink}">${title}</div>
      <div class="cols">${KEYS.map(([k, n, l]) => col(k, n, l, m, bg, ink)).join('')}</div>
    </div>`;
  const html = `<html><head><style>
    body{margin:0;font-family:-apple-system,Helvetica,Arial,sans-serif;background:#888}
    .panel{padding:18px 20px 22px} .title{font-size:12px;font-weight:600;letter-spacing:.04em;text-transform:uppercase;opacity:.6;margin-bottom:12px}
    .cols{display:flex;gap:28px} .col{width:150px} .lab{font-size:11px;margin-bottom:8px}
    .row{display:flex;align-items:flex-end;gap:14px}
    .big{display:flex;gap:16px;padding:20px;background:#fff}
    .pair{display:flex;flex-direction:column;align-items:center;gap:6px;font-size:11px;color:#5E6779}
  </style></head><body><div id="sheet" style="width:540px">
    <div class="big">${KEYS.map(([k, n]) => `<div class="pair">${ic(orig(k, n), 72)}<span>förlaga</span>${ic(uri(k, n, 'mork'), 72)}<span>vektor mörk</span>${ic(uri(k, n, 'ljus'), 72)}<span>vektor ljus</span></div>`).join('')}</div>
    ${panel('mork', '#0F1218', '#EEF1F7', 'Mörkt läge · mörk ikon · 60 pt och 29 pt')}
    ${panel('mork', '#FFFFFF', '#141A2E', 'Ljust läge · mörk ikon (röstningen)')}
    ${panel('ljus', '#FFFFFF', '#141A2E', 'Ljust läge · ljus ikon')}
    ${panel('ljus', '#0F1218', '#EEF1F7', 'Mörkt läge · ljus ikon')}
  </div></body></html>`;
  const p2 = await browser.newPage({ viewport: { width: 540, height: 900 }, deviceScaleFactor: 3 });
  await p2.setContent(html);
  await p2.locator('#sheet').screenshot({ path: path.join(DIR, 'kontroll-60pt.png') });
  await browser.close();
  console.log('klart');
})();
