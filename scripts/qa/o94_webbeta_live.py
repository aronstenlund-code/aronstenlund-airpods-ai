"""O94 (D249, Deangelo 2026-11-21 11:58): webbetan live, Oscar (moln).
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o94_webbeta_live.py
Testtrafik: GitHub-nätet räknas som test (K105) och anropen har x-earmind-test, så ljudet är tyst (0 ElevenLabs).
Inga webbsök. Claude: två små prov (3 frågor), cirka 0,05 USD.

Del 1 (webbläsare, Playwright/Chromium mot https://earmind.vercel.app/beta): sidan laddas, CORS-fel i konsolen med och
utan ?test=oscar-qa, krediterna som visas, Säg i AirPods (skriv, Spela, status), Nytt prov för ett nytt konto (nej).
Del 2 (HTTP med Origin: https://earmind.vercel.app): CORS-preflight för huvudena webben skickar, inloggning, 1 500 utan
välkomst, rösterna (D252), Säg (save start:true), prov med lang/språk, 402-texten på sv/en.
Del 3 (sist, tar nätets platser för dygnet): nya konton från webben per nät, det sjätte ska få 429 too_many_accounts."""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE))
import qa_testaccount as T  # noqa: E402
T.install()
import json, re, subprocess, time, urllib.error, urllib.request, uuid  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
WEB = "https://earmind.vercel.app"
OK = []


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:2500], flush=True)


# ---------------- Del 1: webbläsaren ----------------
def browser_part():
    try:
        from playwright.sync_api import sync_playwright  # noqa: PLC0415
    except ImportError:
        subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "playwright==1.48.0"], check=True)
        from playwright.sync_api import sync_playwright  # noqa: PLC0415
    subprocess.run([sys.executable, "-m", "playwright", "install", "--with-deps", "chromium"], check=False, capture_output=True)
    out = {}
    with sync_playwright() as p:
        b = p.chromium.launch()
        for label, q in (("med ?test=oscar-qa", "?test=oscar-qa"), ("utan ?test", "")):
            ctx = b.new_context(locale="sv-SE")
            page = ctx.new_page()
            cons, failed, calls = [], [], []
            page.on("console", lambda m: cons.append(f"{m.type}: {m.text[:200]}") if m.type in ("error", "warning") else None)
            page.on("requestfailed", lambda r: failed.append(f"{r.method} {r.url[:90]} {r.failure}"))
            page.on("response", lambda r: calls.append(f"{r.status} {r.request.method} {r.url.split('?')[0][-40:]}") if "supabase.co" in r.url else None)
            st = page.goto(WEB + "/beta" + q, wait_until="networkidle", timeout=60000)
            page.wait_for_timeout(3000)

            def txt(tid):
                el = page.query_selector(f"[data-testid={tid}]")
                return el.inner_text().strip()[:200] if el else None
            row = {"http": st.status if st else None, "titel": page.title(), "credits": txt("credits")}
            # Säg i AirPods
            say = page.query_selector("[data-testid=say-field]")
            if say:
                say.fill("Kom ihåg att ta med gympakläder på tisdag och lämna in uppsatsen på fredag.")
                btn = page.query_selector("[data-testid=play]")
                if btn:
                    btn.click()
                    page.wait_for_timeout(8000)
                    row["status efter Spela"] = txt("status")
                    stop = page.query_selector("[data-testid=stop]")
                    if stop:
                        stop.click()
            row["credits efter"] = txt("credits")
            # Nytt prov: ett nytt konto ska få nej (krediterna räcker inte till 3 frågor)
            nq = page.query_selector("[data-testid=new-quiz]")
            if nq:
                nq.click()
                page.wait_for_timeout(1500)
                qt = page.query_selector("[data-testid=quiz-text]")
                if qt:
                    qt.fill("Fotosyntesen sker i växternas blad. Med solljus gör växten socker av vatten och koldioxid. Syre släpps ut.")
                    qc = page.query_selector("[data-testid=quiz-create]")
                    if qc:
                        qc.click()
                        page.wait_for_timeout(6000)
                row["nytt prov, sidans text"] = page.inner_text("body")[:600]
            row["konsol (fel/varning)"] = cons[:12]
            row["misslyckade anrop"] = failed[:12]
            row["anrop till servern"] = calls[:25]
            row["cors-fel"] = sum("CORS" in c or "Access-Control" in c for c in cons)
            out[label] = row
            ctx.close()
        b.close()
    return out


try:
    br = browser_part()
except Exception as e:  # report and go on with the HTTP part
    br = {"fel": repr(e)[:400]}
for label, row in br.items():
    if not isinstance(row, dict):
        check(f"Webbläsaren: {label}", False, row)
        continue
    if label == "med ?test=oscar-qa":
        check("Webbläsaren med ?test=oscar-qa: sidan laddas och servern nås utan CORS-fel (testhuvudet släpps igenom)",
              row.get("http") == 200 and row.get("cors-fel") == 0 and not row.get("misslyckade anrop"), row)
    else:
        check("Webbläsaren utan ?test: sidan laddas, krediter visas, Säg spelar, inga CORS-fel",
              row.get("http") == 200 and row.get("cors-fel") == 0 and bool(row.get("credits")), row)


# ---------------- Del 2: HTTP med webbens Origin ----------------
def call(method, path, body=None, tok=None, extra=None, test=True):
    h = T.headers(tok, test, {"origin": WEB, **(extra or {})})
    r = urllib.request.Request(T.URL + path, data=json.dumps(body).encode() if body is not None else None, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=180) as x:
            raw = x.read()
            return x.status, {k.lower(): v for k, v in x.headers.items()}, (json.loads(raw) if raw[:1] in (b"{", b"[") else raw[:200].decode(errors="replace"))
    except urllib.error.HTTPError as e:
        raw = e.read() or b""
        try:
            j = json.loads(raw)
        except ValueError:
            j = raw[:200].decode(errors="replace")
        return e.code, {k.lower(): v for k, v in e.headers.items()}, j


def preflight(path, headers, origin=WEB):
    r = urllib.request.Request(T.URL + path, method="OPTIONS", headers={"origin": origin, "access-control-request-method": "POST",
                                                                         "access-control-request-headers": headers})
    try:
        with urllib.request.urlopen(r, timeout=30) as x:
            return x.status, {k.lower(): v for k, v in x.headers.items()}
    except urllib.error.HTTPError as e:
        return e.code, {k.lower(): v for k, v in e.headers.items()}


WEB_HEADERS = "authorization,apikey,content-type,x-earmind-lang,x-earmind-test"
pf = {}
for fn in ("drill", "exam", "voices", "answer", "tts", "account"):
    s, h = preflight("/functions/v1/" + fn, WEB_HEADERS)
    allowed = [x.strip() for x in (h.get("access-control-allow-headers") or "").split(",")]
    pf[fn] = {"status": s, "origin": h.get("access-control-allow-origin"), "saknas": [x for x in WEB_HEADERS.split(",") if x not in allowed]}
check("CORS: preflight från earmind.vercel.app släpps in på alla funktioner", all(v["status"] in (200, 204) and v["origin"] == WEB for v in pf.values()), pf)
check("CORS: alla huvuden webben skickar finns i Access-Control-Allow-Headers (också x-earmind-test, ?test=…)",
      all(not v["saknas"] for v in pf.values()), pf)
s_bad, h_bad = preflight("/functions/v1/drill", "authorization", origin="https://evil.example")
s_auth, h_auth = preflight("/auth/v1/signup", "apikey,content-type,x-client-info")
check("CORS: annan origin nekas; inloggningens preflight (Supabase Auth) släpper in webben",
      s_bad == 403 and s_auth in (200, 204) and h_auth.get("access-control-allow-origin") in ("*", WEB),
      {"annan origin": s_bad, "auth/v1/signup": [s_auth, h_auth.get("access-control-allow-origin")]})

# anonymous sign-in with the web's Origin
r = urllib.request.Request(T.URL + "/auth/v1/signup", data=b"{}", method="POST", headers=T.headers(None, True, {"origin": WEB}))
with urllib.request.urlopen(r, timeout=30) as x:
    A = json.load(x)["access_token"]
s, _, q = call("POST", "/functions/v1/drill", {"action": "quota"}, A)
check("Webbkonto: 1 500 i månaden, ingen välkomst (gift 0), inget köpt",
      s == 200 and q.get("limit") == 1500 and q.get("monthly_free") == 1500 and not (q.get("gift") or {}).get("welcome") and not q.get("purchased"),
      {k: q.get(k) for k in ("limit", "used", "remaining", "monthly_free", "purchased", "gift", "exam", "suggest")})
s, _, v = call("GET", "/functions/v1/voices", None, A)
cat = v.get("catalog") or [] if isinstance(v, dict) else []
names = [c.get("name") for c in cat]
low = [str(n).lower() for n in names]
check("Rösterna (D252): ingen Marlon; PS3 character, Niki, Chris, Paul, Alyssa Laine finns; review-rösterna (Ajay, kinesisk brytning) syns inte för ett vanligt konto",
      s == 200 and "marlon" not in low and "ps3 character" in low and all(any(n.startswith(x) for n in low) for x in ("niki", "chris", "paul", "alyssa"))
      and not any(c.get("review") for c in cat) and not any(n.startswith("ajay") for n in low),
      {"antal": len(cat), "namn": names, "språk": sorted({str(c.get("language")) for c in cat}), "default": (v.get("default_voice") or {}).get("name") if isinstance(v, dict) else None})

# Säg i AirPods from the web: save with start:true, fake audio, credits drawn
say = "Ring mormor på söndag och fråga om hon vill följa med på bio, och köp mjölk på vägen hem."  # not the browser's text (that audio is then free, D144)
s, _, j = call("POST", "/functions/v1/drill", {"action": "save", "start": True, "lang": "sv", "drill": {"kind": "text", "title": "O94 (QA)", "said": True, "client_id": str(uuid.uuid4())},
                                               "items": [{"kind": "para", "text": say}]}, A, {"x-earmind-lang": "sv"})
d = (j.get("drill") or {}) if isinstance(j, dict) else {}
s2, _, q2 = call("POST", "/functions/v1/drill", {"action": "quota"}, A)
check("Säg i AirPods via webben: save med start:true ger 200, ljudet startat (tyst i test), krediter = tecken",
      s == 200 and d.get("audio_started") and (q2.get("used") or 0) - (q.get("used") or 0) == len(say),
      {"status": s, "audio": (j.get("audio") or {}) if isinstance(j, dict) else j, "drogs": (q2.get("used") or 0) - (q.get("used") or 0), "tecken": len(say)})

# exam from the web: language follows the text (K114), lang only for messages/answers; 3 questions each
SV = ("Fotosyntesen sker i växternas gröna blad. Med hjälp av solljus gör växten socker av vatten och koldioxid, och syre släpps ut. "
      "Sockret används som energi när växten växer. Utan ljus stannar fotosyntesen.")
EN = ("Photosynthesis happens in the green leaves of plants. Using sunlight, the plant makes sugar from water and carbon dioxide, "
      "and oxygen is released. The sugar is used as energy when the plant grows. Without light, photosynthesis stops.")
SVW = re.compile(r"\b(och|är|vad|hur|varför|vilken|vilka|växten|av|som)\b", re.I)
ENW = re.compile(r"\b(the|what|how|why|which|does|is|of|plant)\b", re.I)
lang_rows = {}
for name, text, lang in (("svensk text, lang en", SV, "en"), ("engelsk text, lang sv", EN, "sv")):
    s, _, pl = call("POST", "/functions/v1/exam", {"action": "drill", "answers": False, "questions": 3, "subject": "Biologi", "pages": [], "text": text, "lang": lang}, A,
                    {"x-earmind-lang": lang})
    qs = [i.get("question") for i in (pl.get("items") or [])] if isinstance(pl, dict) else []
    joined = " ".join(qs)
    lang_rows[name] = {"status": s, "frågor": qs, "sv-ord": len(SVW.findall(joined)), "en-ord": len(ENW.findall(joined)), "fel": (pl.get("error") if isinstance(pl, dict) else pl)}
check("Prov via webben: frågorna följer textens språk (svensk text svenska frågor, engelsk text engelska)",
      lang_rows["svensk text, lang en"]["status"] == 200 and lang_rows["engelsk text, lang sv"]["status"] == 200
      and lang_rows["svensk text, lang en"]["sv-ord"] > lang_rows["svensk text, lang en"]["en-ord"]
      and lang_rows["engelsk text, lang sv"]["en-ord"] > lang_rows["engelsk text, lang sv"]["sv-ord"], lang_rows)
# the user's way (user-path): 12 questions, 402 with fits, message in the asked language
msgs = {}
time.sleep(65)  # the exam limit per minute (the two exams above), so the 402 is not a 429
for lang in ("sv", "en"):
    s, _, e = call("POST", "/functions/v1/exam", {"action": "drill", "answers": False, "questions": 12, "subject": "Biologi", "pages": [], "text": SV, "lang": lang}, A,
                   {"x-earmind-test": "oscar-qa user-path", "x-earmind-lang": lang, "accept-language": lang})
    msgs[lang] = {"status": s, "fits": e.get("fits") if isinstance(e, dict) else None, "text": ((e.get("error") or {}).get("message") if isinstance(e, dict) else e)}
check("Nytt prov för ett nytt webbkonto: 402 före Claude, texten på svenska med sv och på engelska med en",
      msgs["sv"]["status"] == msgs["en"]["status"] == 402 and "krediter" in (msgs["sv"]["text"] or "") and "credits" in (msgs["en"]["text"] or ""), msgs)
call("POST", "/functions/v1/account/delete", {"confirm": True}, A)

# ---------------- Del 3: nya konton per nät och dygn (sist) ----------------
admitted, denied = 0, None
for n in range(8):
    r = urllib.request.Request(T.URL + "/auth/v1/signup", data=b"{}", method="POST", headers=T.headers(None, True, {"origin": WEB}))
    with urllib.request.urlopen(r, timeout=30) as x:
        tok = json.load(x)["access_token"]
    s, h, j = call("POST", "/functions/v1/drill", {"action": "quota"}, tok, {"accept-language": "sv-SE"})
    if s == 429:
        denied = {"efter nya konton": n, "kod": (j.get("error") or {}).get("code") if isinstance(j, dict) else j, "text": (j.get("error") or {}).get("message") if isinstance(j, dict) else None,
                  "retry-after": h.get("retry-after")}
        # the app sends no Origin: the same account without it is not stopped
        r2 = urllib.request.Request(T.URL + "/functions/v1/drill", data=json.dumps({"action": "quota"}).encode(), method="POST", headers=T.headers(tok, True))
        try:
            with urllib.request.urlopen(r2, timeout=30) as x:
                denied["samma konto utan Origin (appen)"] = x.status
        except urllib.error.HTTPError as e:
            denied["samma konto utan Origin (appen)"] = e.code
        break
    admitted += 1
check("Missbruksskydd: högst 5 konton per nät och dygn från webben (webbläsarens och del 2:s konton räknas också); nästa får 429 too_many_accounts på svenska; appen (utan Origin) påverkas inte",
      denied is not None and denied.get("kod") == "too_many_accounts" and admitted <= 4 and "konton" in (denied.get("text") or "") and denied.get("samma konto utan Origin (appen)") == 200,
      {"släppta i del 3": admitted, "nekad": denied})

print(f"\n=== O94 {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
