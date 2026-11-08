#!/usr/bin/env python3
"""Oscar QA O2: the published demo page (GitHub Pages) in a real browser (Playwright Chromium; WebKit only if installed).

  python -I scripts/qa/demo_site.py

Uses at most ~8 real demo questions (visitor cap 5 + 1 over the cap, network cap 20/day is not approached), 3 waitlist rows
(oscar-qa-*@example.com, to be deleted by someone with database access) and 9 stt-token requests. Writes
reports/qa/data/<stamp>-demo-site.json and screenshots to reports/qa/shots/ (JPEG, each <= 500 kB).
"""
import datetime as dt, json, pathlib, sys, time
from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[2]
URL = "https://aronstenlund-code.github.io/aronstenlund-airpods-ai/"
SHOTS = ROOT / "reports/qa/shots"
SHOTS.mkdir(parents=True, exist_ok=True)
log = []
STAMP = dt.datetime.now().strftime("%H%M%S")


def rec(test, **kw):
    kw["at"] = dt.datetime.now().strftime("%H:%M:%S")
    log.append({"test": test, **kw})
    print(test, json.dumps(kw, ensure_ascii=False, default=str)[:700], flush=True)


def shot(page, name):
    p = SHOTS / f"demo-{name}.jpg"
    page.screenshot(path=str(p), type="jpeg", quality=55)
    kb = p.stat().st_size // 1024
    if kb > 500:
        page.screenshot(path=str(p), type="jpeg", quality=35)
        kb = p.stat().st_size // 1024
    rec("shot " + name, kb=kb)


def lum(rgb):
    def f(c):
        c /= 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = rgb
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def ratio(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


CONTRAST_JS = """
() => {
  const sel = ['h1','h2','p','.hint','.left','.chip','.pill','.note','.fieldmsg','.formmsg','footer','label','a','input','.disc','.q','.a','button'];
  const out = [], seen = new Set();
  const parse = s => { const m = s.match(/rgba?\\(([^)]+)\\)/); if (!m) return null; const p = m[1].split(/[ ,\\/]+/).filter(Boolean).map(Number); return {r:p[0],g:p[1],b:p[2],a:p.length>3?p[3]:1}; };
  const bg = el => { let e = el; while (e) { const c = parse(getComputedStyle(e).backgroundColor); if (c && c.a > 0.9) return [c.r,c.g,c.b]; e = e.parentElement; } return [255,255,255]; };
  for (const s of sel) for (const el of document.querySelectorAll(s)) {
    const t = (el.innerText || el.placeholder || '').trim(); if (!t || t.length > 90) continue;
    const r = el.getBoundingClientRect(); if (r.width < 2 || r.height < 2) continue;
    const cs = getComputedStyle(el); if (cs.visibility === 'hidden' || cs.display === 'none') continue;
    const key = s + '|' + t.slice(0, 30); if (seen.has(key)) continue; seen.add(key);
    const c = parse(cs.color); const op = parseFloat(cs.opacity);
    out.push({sel: s, text: t.slice(0, 40), color: [c.r,c.g,c.b], alpha: c.a * op, bg: bg(el), size: parseFloat(cs.fontSize), weight: cs.fontWeight});
    if (out.length > 60) return out;
  }
  return out;
}
"""


def contrast(page, name):
    items = page.evaluate(CONTRAST_JS)
    bad = []
    for it in items:
        c, b, a = it["color"], it["bg"], it["alpha"]
        eff = [round(c[i] * a + b[i] * (1 - a)) for i in range(3)]
        r = ratio(eff, b)
        large = it["size"] >= 24 or (it["size"] >= 18.66 and int(it["weight"]) >= 700)
        need = 3.0 if large else 4.5
        if r < need:
            bad.append({"sel": it["sel"], "text": it["text"], "ratio": round(r, 2), "need": need, "size": it["size"]})
    rec("contrast " + name, checked=len(items), failing=bad)


def focus_walk(page, name, n=35):
    seq, nofocus = [], []
    page.evaluate("document.activeElement && document.activeElement.blur()")
    for i in range(n):
        page.keyboard.press("Tab")
        d = page.evaluate("""() => { const e = document.activeElement; if (!e || e === document.body) return null;
            const cs = getComputedStyle(e); const r = e.getBoundingClientRect();
            return {tag: e.tagName.toLowerCase(), id: e.id, text: (e.innerText || e.getAttribute('aria-label') || e.placeholder || '').trim().slice(0, 36),
                    outline: cs.outlineStyle + ' ' + cs.outlineWidth, shadow: cs.boxShadow === 'none' ? '' : 'shadow', inView: r.top >= 0 && r.bottom <= innerHeight + 2,
                    w: Math.round(r.width), h: Math.round(r.height)}; }""")
        if d is None:
            break
        if seq and seq[0]["tag"] == d["tag"] and seq[0]["id"] == d["id"] and seq[0]["text"] == d["text"] and i > 2:
            break
        seq.append(d)
        if d["outline"].startswith("none") and not d["shadow"]:
            nofocus.append(d["tag"] + "#" + d["id"] + ":" + d["text"])
    small = [s["tag"] + "#" + s["id"] + ":" + s["text"] + f" {s['w']}x{s['h']}" for s in seq if s["w"] < 44 or s["h"] < 44]
    rec("keyboard " + name, stops=len(seq), order=[s["tag"] + ("#" + s["id"] if s["id"] else "") + ":" + s["text"] for s in seq], no_visible_focus=nofocus, under_44px=small)


def reset_view(page):
    """Back to the input: stop the reading if it still runs, then 'Ställ en ny fråga'."""
    try:
        if page.is_visible("#stop"):
            page.click("#stop")
        page.wait_for_selector("#again", state="visible", timeout=8000)
        page.click("#again")
        page.wait_for_selector("#txt", state="visible", timeout=5000)
    except Exception as e:
        rec("reset_view failed", err=repr(e)[:120], visible=[i for i in ("#txt", "#stop", "#again", "#disc") if page.is_visible(i)])


def load_metrics(ctx_factory, name, throttle=None):
    ctx = ctx_factory()
    page = ctx.new_page()
    sizes, errors, failed = [], [], []
    page.on("response", lambda r: sizes.append((r.url.split("?")[0][-60:], r.status, int(r.headers.get("content-length") or 0), r.headers.get("content-encoding", ""))))
    page.on("console", lambda m: errors.append(m.text[:140]) if m.type == "error" else None)
    page.on("requestfailed", lambda r: failed.append(r.url[-80:]))
    if throttle:
        cdp = ctx.new_cdp_session(page)
        cdp.send("Network.enable")
        cdp.send("Network.emulateNetworkConditions", {"offline": False, "latency": throttle[0], "downloadThroughput": throttle[1] * 1024 / 8, "uploadThroughput": throttle[1] * 1024 / 8 / 2})
    t0 = time.time()
    page.goto(URL, wait_until="load", timeout=60000)
    wall = round((time.time() - t0) * 1000)
    nav = page.evaluate("""() => { const n = performance.getEntriesByType('navigation')[0]; const p = performance.getEntriesByType('paint');
        const tr = performance.getEntriesByType('resource').reduce((s, r) => s + (r.transferSize || 0), 0) + (n.transferSize || 0);
        return {dcl: Math.round(n.domContentLoadedEventEnd), load: Math.round(n.loadEventEnd), fcp: Math.round((p.find(x => x.name === 'first-contentful-paint') || {}).startTime || 0),
                transfer_kb: Math.round(tr / 1024), requests: performance.getEntriesByType('resource').length + 1}; }""")
    rec("load " + name, wall_ms=wall, **nav, console_errors=errors, failed=failed, resources=[(s[0], s[1], s[2] // 1024) for s in sizes][:14])
    return ctx, page


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    with sync_playwright() as pw:
        engines = [("chromium", pw.chromium)]
        try:
            b = pw.webkit.launch()
            b.close()
            engines.append(("webkit", pw.webkit))
        except Exception:
            rec("webkit", status="not installed (needs `playwright install webkit`, a download)")
        if len(sys.argv) > 1:  # e.g. `demo_site.py webkit` runs only that engine
            engines = [e for e in engines if e[0] in sys.argv[1:]]
        for ename, eng in engines:
            browser = eng.launch(args=["--use-fake-ui-for-media-stream", "--use-fake-device-for-media-stream"] if ename == "chromium" else [])
            iphone = pw.devices["iPhone 13"]
            mk_m = lambda scheme="light": browser.new_context(**iphone, color_scheme=scheme, locale="sv-SE", permissions=["microphone"] if ename == "chromium" else [])
            mk_d = lambda scheme="light": browser.new_context(viewport={"width": 1280, "height": 800}, color_scheme=scheme, locale="sv-SE", permissions=["microphone"] if ename == "chromium" else [])

            # ---- load time and weight
            c, p = load_metrics(mk_d, ename + "-desktop-unthrottled")
            c.close()
            c, p = load_metrics(mk_m, ename + "-mobile-unthrottled")
            c.close()
            if ename == "chromium":
                c, p = load_metrics(mk_m, ename + "-mobile-fast4g(9Mbps,170ms)", throttle=(170, 9000))
                c.close()

            # ---- mobile: the real flow, one visitor
            ctx = mk_m("light")
            page = ctx.new_page()
            reqs = []
            page.on("request", lambda r: reqs.append((r.url.split("/functions/v1/")[-1][:30], r.method)) if "/functions/v1/" in r.url else None)
            page.goto(URL, wait_until="load")
            shot(page, f"{ename}-mobile-light-idle")
            rec("page", title=page.title(), lang=page.evaluate("document.documentElement.lang"), h1=page.inner_text("h1"),
                scroll_w_ok=page.evaluate("document.documentElement.scrollWidth <= innerWidth + 1"), viewport_meta=page.evaluate("(document.querySelector('meta[name=viewport]')||{}).content"))
            contrast(page, ename + "-mobile-light-idle")
            texts = []
            for i, q in enumerate(["vad är fotosyntes", "orsaker till första världskriget", "vad betyder low-key", "hur många ben har en spindel", "vem var Gustav Vasa"]):
                t0 = time.time()
                if i == 0:
                    page.click(".chip:has-text('Orsaker till första världskriget')")
                    q = "(chip) Orsaker till första världskriget"
                else:
                    page.fill("#txt", q)
                    page.press("#txt", "Enter")
                try:
                    page.wait_for_function("document.querySelector('#a') && document.querySelector('#a').innerText.trim().length > 8", timeout=20000)
                    first = round((time.time() - t0) * 1000)
                except Exception:
                    first = None
                page.wait_for_timeout(2500)
                txt = page.inner_text("#a").strip()
                again = page.is_visible("#again")
                rec(f"ask {i + 1} {q}", first_text_ms=first, chars=len(txt), answer=txt[:200], note=(page.inner_text("#note") if page.is_visible("#note") else ""), left=page.inner_text("#left"), again_visible=again)
                if i == 0:
                    shot(page, f"{ename}-mobile-light-answer")
                reset_view(page)
            rec("network calls so far", calls=reqs)
            # 6th question: local counter says the day is full -> what does the page show
            if page.is_visible("#txt"):
                page.fill("#txt", "en sjätte fråga")
                page.press("#txt", "Enter")
            page.wait_for_timeout(2500)
            body_now = page.inner_text("body")
            rec("6th question (client counter)", visible_text_has_limit=("5 demofrågor" in body_now or "demofrågor" in body_now), snippet=[l for l in body_now.splitlines() if "demofr" in l.lower() or "imorgon" in l.lower()][:3])
            shot(page, f"{ename}-mobile-light-limit-client")
            # remove only the local day counter so the SERVER decides (same visitor token)
            page.evaluate("Object.keys(localStorage).filter(k => k.startsWith('demo_used_')).forEach(k => localStorage.removeItem(k))")
            page.reload(wait_until="load")
            page.wait_for_timeout(1500)
            try:
                page.fill("#txt", "och en till")
                page.press("#txt", "Enter")
                page.wait_for_timeout(5000)
                lim = page.inner_text("body")
                rec("server visitor cap (local counter removed)", snippet=[l for l in lim.splitlines() if "demofr" in l.lower() or "imorgon" in l.lower() or "Ladda ner" in l][:4])
                shot(page, f"{ename}-mobile-light-limit-server")
            except Exception as e:
                rec("server visitor cap", err=repr(e)[:200])

            # ---- waitlist (same page)
            page.goto(URL + "#vantelista", wait_until="load")
            em = f"oscar-qa-site-{STAMP}@example.com"
            def wl(email, consent, label, hp=None):
                page.fill("#email", email)
                page.set_checked("#consent", consent)
                if hp:
                    page.evaluate("v => document.querySelector('#website').value = v", hp)
                page.click("#waitbtn")
                page.wait_for_timeout(2500)
                rec("waitlist " + label, email_msg=page.inner_text("#emailmsg"), consent_msg=page.inner_text("#consentmsg"), form_msg=page.inner_text("#waitmsg"))
            wl("inte-en-epost", True, "invalid email")
            wl(em, False, "no consent")
            shot(page, f"{ename}-mobile-light-waitlist-errors")
            wl(em, True, "valid")
            shot(page, f"{ename}-mobile-light-waitlist-ok")
            wl(em, True, "duplicate")
            wl(em.upper().replace("EXAMPLE.COM", "example.com"), True, "duplicate upper-case")
            rec("honeypot visible to users", visible=page.is_visible("#website"), aria_hidden=page.get_attribute(".hp", "aria-hidden"))
            ctx.close()

            # ---- desktop dark and light: visuals, contrast, keyboard
            for scheme in ("light", "dark"):
                ctx = mk_d(scheme)
                page = ctx.new_page()
                page.goto(URL, wait_until="load")
                shot(page, f"{ename}-desktop-{scheme}-idle")
                contrast(page, f"{ename}-desktop-{scheme}-idle")
                focus_walk(page, f"{ename}-desktop-{scheme}")
                if scheme == "dark":
                    page.fill("#txt", "vad är en primtal")
                    page.press("#txt", "Enter")
                    page.wait_for_timeout(7000)
                    shot(page, f"{ename}-desktop-dark-answer")
                    contrast(page, f"{ename}-desktop-dark-answer")
                ctx.close()
            # mobile dark idle
            ctx = mk_m("dark")
            page = ctx.new_page()
            page.goto(URL, wait_until="load")
            shot(page, f"{ename}-mobile-dark-idle")
            contrast(page, f"{ename}-mobile-dark-idle")
            ctx.close()

            # ---- keyboard: use the page only with the keyboard (desktop)
            ctx = mk_d("light")
            page = ctx.new_page()
            page.goto(URL, wait_until="load")
            page.focus("#txt")
            page.keyboard.type("hur lång är ekvatorn")
            page.keyboard.press("Enter")
            try:
                page.wait_for_function("document.querySelector('#a').innerText.trim().length > 8", timeout=20000)
                rec("keyboard-only ask", ok=True, answer=page.inner_text("#a")[:120], focus_after=page.evaluate("document.activeElement.id || document.activeElement.tagName"))
            except Exception as e:
                rec("keyboard-only ask", ok=False, err=repr(e)[:150])
            ctx.close()

            # ---- STT token cap through the UI (chromium only, fresh visitor), spaced for the 6/min token limit
            if ename == "chromium":
                ctx = mk_d("light")
                page = ctx.new_page()
                calls = []
                page.on("response", lambda r: calls.append((r.status, r.url.split("/functions/v1/")[-1][:30])) if "stt-token" in r.url else None)
                page.goto(URL, wait_until="load")
                for i in range(9):
                    try:
                        box = page.locator("#disc").bounding_box()
                        page.mouse.move(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
                        page.mouse.down()
                        page.wait_for_timeout(1800)
                        page.mouse.up()
                        page.wait_for_timeout(1500)
                    except Exception as e:
                        rec("hold", i=i, err=repr(e)[:100])
                    st = [c for c in calls if c[0] != 200]
                    if i >= 6 or st:
                        rec(f"stt hold {i + 1}", token_calls=len(calls), non200=st[-2:], page_note=[l for l in page.inner_text("body").splitlines() if "röst" in l.lower() or "demofr" in l.lower() or "mikrofon" in l.lower()][:3])
                    page.wait_for_timeout(9000)
                shot(page, "chromium-desktop-stt-cap")
                ctx.close()
            browser.close()
    out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M") + ("-demo-site-" + "-".join(sys.argv[1:]) if len(sys.argv) > 1 else "-demo-site") + ".json")
    out.write_text(json.dumps(log, ensure_ascii=False, indent=1), encoding="utf-8")
    print("saved", out)


main()
