const { chromium } = require('playwright'); const fs=require('fs');
const D='docs/design/logo/rostning/'; const K={A:'A-klotet',B:'B-grona-formen',C:'C-orange-ringen',D:'D-glasklotet',E:'E-glasringen',F:'F-glasvagen'};
const png=f=>'data:image/png;base64,'+fs.readFileSync(f).toString('base64');
const ic=(s,pt,mask=true)=>`<img src="${s}" style="width:${pt}px;height:${pt}px;${mask?`border-radius:${pt*0.2237}px;`:''}display:block">`;
(async()=>{const b=await chromium.launch();const p=await b.newPage({viewport:{width:700,height:900},deviceScaleFactor:3});
const rows=Object.entries(K).map(([k,n])=>`<div style="display:flex;gap:14px;align-items:flex-end;padding:8px 0">
<div style="width:18px;font:600 14px sans-serif">${k}</div>${ic(png(D+n+'.png'),110,false)}${ic(png(D+'exakt/'+k+'.png'),110,false)}${ic(png(D+'exakt/'+k+'.png'),110)}
<div style="background:#0F1218;padding:8px;border-radius:10px;display:flex;gap:8px;align-items:flex-end">${ic(png(D+'exakt/'+k+'.png'),60)}${ic(png(D+'exakt/'+k+'.png'),29)}</div>
<div style="background:#fff;border:1px solid #ddd;padding:8px;border-radius:10px;display:flex;gap:8px;align-items:flex-end">${ic(png(D+'exakt/'+k+'.png'),60)}${ic(png(D+'exakt/'+k+'.png'),29)}</div></div>`).join('');
await p.setContent(`<html><body style="margin:0;background:#E9EDF3"><div id="s" style="padding:12px 16px;width:660px">
<div style="font:600 11px sans-serif;color:#5E6779;margin:0 0 4px 32px">förlaga · exakt 1024 utan mask · med iOS-mask · 60/29 pt mörkt · 60/29 pt ljust</div>${rows}</div></body></html>`);
await p.locator('#s').screenshot({path:D+'exakt/kontroll.png'}); await b.close();})();
