// Kelly, Ke31/Ke40: PNG av röstningsikonerna (A–F), appikonen D (vanlig, mörk, tonad) och kontrollbilder.
// Kör från repots rot: python3 docs/design/logo/_src/rostning.py && node docs/design/logo/_src/rostning-render.js
// (Tonad görs av python-steget nedan, se rostning-tonad.py.)
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const DIR = 'docs/design/logo/rostning/vektor';
const KEYS = [
  ['A', 'klotet', 'A · Klotet'], ['B', 'grona-formen', 'B · Den gröna formen'], ['C', 'orange-ringen', 'C · Den orange ringen'],
  ['D', 'glasklotet', 'D · Glasklotet'], ['E', 'glasringen', 'E · Glasringen'], ['F', 'glasvagen', 'F · Glasvågen'],
];
const ORIG = { A: 'A-klotet', B: 'B-grona-formen', C: 'C-orange-ringen', D: 'D-glasklotet', E: 'E-glasringen', F: 'F-glasvagen' };

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  const svgs = fs.readdirSync(DIR).filter(f => /^[A-F]-.*-(mork|ljus|svart)\.svg$/.test(f));
  for (const f of svgs) {
    await page.setContent(`<html><body style="margin:0">${fs.readFileSync(path.join(DIR, f), 'utf8')}</body></html>`);
    await page.locator('svg').screenshot({ path: path.join(DIR, f.replace('.svg', '-1024.png')) });
  }

  const uri = f => 'data:image/svg+xml;base64,' + fs.readFileSync(path.join(DIR, f)).toString('base64');
  const png = f => 'data:image/png;base64,' + fs.readFileSync(f).toString('base64');
  const ic = (src, pt) => `<img src="${src}" style="width:${pt}px;height:${pt}px;border-radius:${pt * 0.2237}px;display:block">`;
  const css = `body{margin:0;font-family:-apple-system,Helvetica,Arial,sans-serif}
    .panel{padding:16px 18px 20px} .title{font-size:12px;font-weight:600;letter-spacing:.04em;text-transform:uppercase;opacity:.6;margin-bottom:12px}
    .grid{display:grid;grid-template-columns:repeat(3,1fr);gap:18px 20px} .lab{font-size:11px;margin-bottom:6px}
    .row{display:flex;align-items:flex-end;gap:12px} .pair{display:flex;flex-direction:column;align-items:center;gap:4px;font-size:10px;color:#5E6779}`;

  // 1. Alla sex: förlaga, mörk, ljus; och 60/29 pt på mörk och ljus bakgrund (röstningen visar mörk ikon).
  const panel = (bg, ink, title) => `<div class="panel" style="background:${bg}"><div class="title" style="color:${ink}">${title}</div>
    <div class="grid">${KEYS.map(([k, n, l]) => `<div><div class="lab" style="color:${ink}">${l}</div>
      <div class="row">${ic(uri(`${k}-${n}-mork.svg`), 60)}${ic(uri(`${k}-${n}-mork.svg`), 29)}</div></div>`).join('')}</div></div>`;
  const top = `<div class="panel" style="background:#fff"><div class="grid">${KEYS.map(([k, n]) => `<div style="display:flex;gap:8px">
      <div class="pair">${ic(png(`docs/design/logo/rostning/${ORIG[k]}.png`), 52)}förlaga</div>
      <div class="pair">${ic(uri(`${k}-${n}-mork.svg`), 52)}mörk</div>
      <div class="pair">${ic(uri(`${k}-${n}-ljus.svg`), 52)}ljus</div></div>`).join('')}</div></div>`;
  let p2 = await browser.newPage({ viewport: { width: 640, height: 900 }, deviceScaleFactor: 3 });
  await p2.setContent(`<html><head><style>${css}</style></head><body><div id="s" style="width:640px">${top}
    ${panel('#0F1218', '#EEF1F7', 'Mörkt läge · 60 pt och 29 pt')}${panel('#FFFFFF', '#141A2E', 'Ljust läge · 60 pt och 29 pt')}</div></body></html>`);
  await p2.locator('#s').screenshot({ path: path.join(DIR, 'kontroll-sex.png') });

  // 2. Appikonen D: hemskärm ljus och mörk med vanlig, mörk och tonad ikon i 60 och 29 pt, och symbolen i rubriken.
  const tonad = path.join(DIR, 'D-glasklotet-tonad-1024.png');
  const tonadSrc = fs.existsSync(tonad) ? png(tonad) : uri('D-glasklotet-svart.svg');
  const sym = fs.readFileSync(path.join(DIR, 'D-glasklotet-symbol.svg'), 'utf8');
  const home = (bg, ink, label, src) => `<div style="background:${bg};padding:14px 16px;border-radius:14px">
    <div style="color:${ink};font-size:11px;opacity:.7;margin-bottom:8px">${label}</div>
    <div class="row">${ic(src, 60)}${ic(src, 29)}</div></div>`;
  const header = (bg, ink, color, pt) => `<div style="background:${bg};padding:12px 16px;border-radius:14px;display:flex;align-items:center;gap:${pt * 0.3}px">
    <span style="display:inline-block;width:${pt}px;height:${pt}px;color:${color}">${sym.replace('<svg ', '<svg width="100%" height="100%" ')}</span>
    <b style="font-size:${pt}px;color:${ink}">Earmind</b></div>`;
  p2 = await browser.newPage({ viewport: { width: 600, height: 700 }, deviceScaleFactor: 3 });
  await p2.setContent(`<html><head><style>${css}</style></head><body><div id="s" style="width:600px;background:#E9EDF3;padding:16px;display:grid;grid-template-columns:1fr 1fr;gap:12px">
    ${home('#FFFFFF', '#141A2E', 'Ljust läge · vanlig ikon (Any)', uri('D-glasklotet-mork.svg'))}
    ${home('#0F1218', '#EEF1F7', 'Mörkt läge · mörk ikon (Dark)', uri('D-glasklotet-svart.svg'))}
    ${home('#2A3550', '#EEF1F7', 'Tonad (Tinted), iOS färgar själv', tonadSrc)}
    ${home('#FFFFFF', '#141A2E', 'Reserv: ljus ikon', uri('D-glasklotet-ljus.svg'))}
    ${header('#FFFFFF', '#141A2E', '#2346C8', 24)}${header('#0F1218', '#EEF1F7', '#7F9BFF', 24)}
    ${header('#FFFFFF', '#141A2E', '#2346C8', 17)}${header('#0F1218', '#EEF1F7', '#7F9BFF', 34)}
  </div></body></html>`);
  await p2.locator('#s').screenshot({ path: path.join(DIR, 'D-appikon-kontroll.png') });
  await browser.close();
  console.log('klart');
})();
