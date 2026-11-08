#!/usr/bin/env python3
"""Oscar QA O2, follow-up probes on the published demo page: mic button contrast over its animation, keyboard activation of the
mic button, honeypot geometry, repeated cold loads, focus after submit. Costs no demo questions except one."""
import io, json, pathlib, sys, time
from playwright.sync_api import sync_playwright
from PIL import Image
sys.stdout.reconfigure(encoding="utf-8")
URL = "https://aronstenlund-code.github.io/aronstenlund-airpods-ai/"

def lum(c):
    f = lambda v: (v/255)/12.92 if v/255 <= 0.03928 else (((v/255)+0.055)/1.055)**2.4
    return 0.2126*f(c[0]) + 0.7152*f(c[1]) + 0.0722*f(c[2])
def ratio(a, b):
    x, y = lum(a), lum(b); return (max(x, y)+0.05)/(min(x, y)+0.05)

with sync_playwright() as pw:
    for scheme in ("light", "dark"):
        b = pw.chromium.launch(args=["--use-fake-ui-for-media-stream", "--use-fake-device-for-media-stream"])
        ctx = b.new_context(viewport={"width": 390, "height": 844}, color_scheme=scheme, locale="sv-SE", permissions=["microphone"])
        p = ctx.new_page(); p.goto(URL, wait_until="load")
        box = p.locator("#disc").bounding_box()
        res = []
        for i in range(8):
            png = p.screenshot(clip={"x": box["x"]+6, "y": box["y"]+box["height"]*0.78, "width": 14, "height": 6})
            # the label sits on the disc; take the disc fill from a spot away from text and the text colour from computed style
            fill = Image.open(io.BytesIO(png)).convert("RGB").getpixel((7, 3))
            text = p.evaluate("(()=>{const c=getComputedStyle(document.querySelector('#disclabel')).color.match(/\d+/g).map(Number);return c})()")
            op = p.evaluate("getComputedStyle(document.querySelector('#disc')).opacity")
            res.append((fill, text[:3], op, round(ratio(text[:3], fill), 2)))
            p.wait_for_timeout(450)
        print(scheme, "disc fill/text/opacity/ratio:", res)
        # keyboard on the disc
        p.focus("#disc"); p.keyboard.down("Space"); p.wait_for_timeout(900)
        s1 = p.inner_text("#disclabel"); p.keyboard.up("Space"); p.wait_for_timeout(700)
        print(scheme, "space on disc: label while held:", repr(s1), "| after:", repr(p.inner_text("#disclabel")), "| hint:", repr(p.inner_text("#hint")))
        p.keyboard.press("Enter"); p.wait_for_timeout(700)
        print(scheme, "enter on disc: label:", repr(p.inner_text("#disclabel")), "| hint:", repr(p.inner_text("#hint")))
        hp = p.evaluate("(()=>{const e=document.querySelector('.hp');const r=e.getBoundingClientRect();const cs=getComputedStyle(e);return {x:r.x,y:r.y,w:r.width,h:r.height,pos:cs.position,op:cs.opacity,clip:cs.clip}})()")
        print(scheme, "honeypot box:", hp)
        ctx.close(); b.close()
    # focus after submit
    b = pw.chromium.launch(); ctx = b.new_context(viewport={"width": 1280, "height": 800}); p = ctx.new_page(); p.goto(URL, wait_until="load")
    p.fill("#txt", "vad är en triangel"); p.press("#txt", "Enter"); p.wait_for_timeout(5000)
    print("focus after submit:", p.evaluate("(document.activeElement.id||document.activeElement.tagName)"), "| aria-live on #a:", p.get_attribute("#a", "aria-live"))
    ctx.close(); b.close()
    # cold loads, fresh browser each time
    for i in range(3):
        b = pw.chromium.launch(); ctx = b.new_context(viewport={"width": 390, "height": 844}); p = ctx.new_page()
        t0 = time.time(); p.goto(URL, wait_until="load"); w = round((time.time()-t0)*1000)
        n = p.evaluate("(()=>{const n=performance.getEntriesByType('navigation')[0];const pt=performance.getEntriesByType('paint').find(x=>x.name==='first-contentful-paint');return [Math.round(n.responseEnd),Math.round(n.domContentLoadedEventEnd),pt?Math.round(pt.startTime):null]})()")
        print("cold load", i+1, "wall", w, "ms; responseEnd/DCL/FCP", n)
        ctx.close(); b.close()
