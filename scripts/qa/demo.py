#!/usr/bin/env python3
"""Oscar QA: public demo (D62/D64) and Kevin's D72/D73 card behaviour, against the live backend.

  python -I scripts/qa/demo.py [--skip-ip-cap] [--dry-run]

What it does NOT do on purpose: the global demo caps (600 questions, 60000 TTS characters, 400 STT tokens a day)
are never tested, because they would shut the demo for real visitors; the TTS per-visitor cap (2000 characters)
is not exhausted either, since it costs real ElevenLabs credits. Costs are computed from tokens (high side).
Writes reports/qa/data/<stamp>-demo.json.
"""
import argparse, datetime as dt, json, pathlib, sys, time, urllib.error, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
ORIGIN = "https://aronstenlund-code.github.io"
PRICES = {"claude-haiku-5-5": (0.10, 0.50), "claude-sonnet-5-5": (2.0, 10.0)}
spent = 0.0
log = []


def call(method, path, body=None, token=None, headers=None, timeout=90, stream=False):
    h = {"apikey": KEY}
    if body is not None:
        h["content-type"] = "application/json"
    if token:
        h["Authorization"] = "Bearer " + token
    h.update(headers or {})
    req = urllib.request.Request(URL + path, data=None if body is None else json.dumps(body).encode(), headers=h, method=method)
    t0 = time.perf_counter()
    out = {"status": None, "headers": {}, "body": b"", "ms": None, "first_ms": None}
    try:
        r = urllib.request.urlopen(req, timeout=timeout)
    except urllib.error.HTTPError as e:
        r = e
    except Exception as e:
        out["error"] = repr(e)
        return out
    out["status"] = r.status if hasattr(r, "status") else r.code
    out["headers"] = {k.lower(): v for k, v in r.headers.items()}
    first = r.read(1)
    out["first_ms"] = round((time.perf_counter() - t0) * 1000)
    out["body"] = first + r.read()
    out["ms"] = round((time.perf_counter() - t0) * 1000)
    return out


def jbody(o):
    try:
        return json.loads(o["body"].decode("utf-8"))
    except Exception:
        return None


def sse(o):
    ev, res = None, {"text": "", "suggestions": None, "preview": None, "done": None, "meta": None, "error": None}
    for line in o["body"].decode("utf-8", "replace").splitlines():
        if line.startswith("event: "):
            ev = line[7:]
        elif line.startswith("data: "):
            try:
                d = json.loads(line[6:])
            except Exception:
                continue
            if ev == "delta":
                res["text"] += d.get("text", "")
            elif ev == "suggestions":
                res["suggestions"] = d
            elif ev == "suggestion_preview":
                res["preview"] = d.get("text")
            elif ev in ("done", "meta", "error"):
                res[ev] = d
    return res


def cost(done):
    global spent
    u = (done or {}).get("usage") or {}
    pi, po = PRICES.get(u.get("model"), PRICES["claude-sonnet-5-5"])
    tot, rd = u.get("input_tokens") or 0, u.get("cache_read_tokens") or 0
    c = (max(0, tot - rd) * 1.25 + rd * 0.1) * pi / 1e6 + (u.get("output_tokens") or 0) * po / 1e6 + (u.get("web_searches") or 0) * 0.01
    c = max(c, u.get("est_cost_usd") or 0)
    spent += c
    return c


def signup():
    o = call("POST", "/auth/v1/signup", {})
    return jbody(o)["access_token"]


def ask(token, body, origin=None):
    time.sleep(3.2)  # normal rate limit is 20/min
    o = call("POST", "/functions/v1/answer", body, token, {"Origin": origin} if origin else None)
    r = sse(o) if o["status"] == 200 else {}
    r["status"], r["ms"], r["first_ms"] = o["status"], o["ms"], o["first_ms"]
    if o["status"] != 200:
        r["err"] = jbody(o)
        r["retry_after"] = o["headers"].get("retry-after")
    else:
        r["cost"] = cost(r["done"])
    return r


def rec(name, **kw):
    log.append({"test": name, **kw})
    print(name, json.dumps(kw, ensure_ascii=False, default=str)[:600], flush=True)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-ip-cap", action="store_true")
    a = ap.parse_args()
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")

    # ---- CORS -------------------------------------------------------------
    for path in ("/functions/v1/answer", "/functions/v1/tts", "/functions/v1/stt-token", "/functions/v1/waitlist"):
        for org in (ORIGIN, "http://localhost:5173", "https://evil.example"):
            o = call("OPTIONS", path, None, None, {"Origin": org, "Access-Control-Request-Method": "POST",
                                                   "Access-Control-Request-Headers": "authorization,apikey,content-type"})
            h = o["headers"]
            rec("cors_preflight", path=path, origin=org, status=o["status"], allow_origin=h.get("access-control-allow-origin"),
                allow_headers=h.get("access-control-allow-headers"), vary=h.get("vary"))
    # ---- auth required ----------------------------------------------------
    o = call("POST", "/functions/v1/answer", {"fragment": "hej", "mode": "text", "source": "demo"})
    rec("answer_no_token", status=o["status"])

    # ---- visitor A: demo rules + visitor cap ----------------------------------
    tokA = signup()
    base = {"mode": "text", "language": "sv", "source": "demo", "context": {}}
    qs = [("fact", "vem skrev Röda rummet"),
          ("long", "förklara hur fotosyntesen fungerar steg för steg"),
          ("web", "sök på nätet vem som är riksbankschef"),
          ("memory", "kom ihåg att jag heter Oscar och är allergisk mot nötter"),
          ("ordinal", "vilken var den tredje kungen av ätten Bernadotte")]
    for name, q in qs:
        r = ask(tokA, dict(base, fragment=q), origin=ORIGIN)
        d = r.get("done") or {}
        u = d.get("usage") or {}
        rec("demo_answer_" + name, q=q, status=r["status"], text=r.get("text"), chars=len(r.get("text") or ""), model=u.get("model"),
            web=u.get("web_searches"), summary=d.get("summary"), memory_add=d.get("memory_add"), first_ms=r["first_ms"], cost=r.get("cost"), err=r.get("err"))
    # forbidden modes (do they count against the visitor? checked via the next calls)
    forb = [("tutor", {"mode": "tutor"}), ("auto", {"mode": "auto"}),
            ("persona_interview", {"persona": "interview", "persona_setup": "x"}),
            ("persona_social_flirt", {"persona": "social", "social": {"style": "flirt", "trigger": "opener", "transcript": []}, "adult_confirmed": True}),
            ("persona_social_social", {"persona": "social", "social": {"style": "social", "trigger": "opener", "transcript": []}}),
            ("length_long", {"length": "long"}), ("model_field", {"model": "claude-sonnet-5-5"})]
    for name, extra in forb:
        r = ask(tokA, dict(base, fragment="hej", **extra))
        rec("demo_forbidden_" + name, status=r["status"], err=r.get("err"), text=(r.get("text") or "")[:80])
    # fill and exceed the visitor cap
    n = len(qs)
    for i in range(6):
        r = ask(tokA, dict(base, fragment="vad är huvudstaden i Italien"))
        n += 1
        if r["status"] != 200:
            rec("demo_visitor_cap", at_question=n, status=r["status"], retry_after=r.get("retry_after"), err=r.get("err"))
            break
        rec("demo_extra_answer", n=n, status=200, text=r.get("text"))
    # does a different endpoint still work for the capped visitor? (separate counters)
    o = call("GET", "/functions/v1/stt-token?source=demo", None, tokA)
    rec("stt_after_question_cap", status=o["status"], body=(o["body"][:120]).decode("utf-8", "replace"))

    # ---- TTS --------------------------------------------------------------
    tokT = signup()
    o = call("POST", "/functions/v1/tts", {"text": "Berlinmuren föll den nionde november nittonhundraåttionio.", "source": "demo"}, tokT, {"Origin": ORIGIN})
    rec("tts_demo_ok", status=o["status"], type=o["headers"].get("content-type"), bytes=len(o["body"]), first_ms=o["first_ms"],
        acao=o["headers"].get("access-control-allow-origin"))
    o = call("POST", "/functions/v1/tts", {"text": "ja. " * 120, "source": "demo"}, tokT)
    rec("tts_demo_too_long_480", status=o["status"], body=o["body"][:200].decode("utf-8", "replace"))
    o = call("POST", "/functions/v1/tts", {"text": "Hej.", "source": "demo", "voice_id": "x", "model_id": "eleven_multilingual_v2",
                                          "output_format": "pcm_24000", "voice_settings": {"stability": 0.1}}, tokT)
    rec("tts_demo_ignores_voice_params", status=o["status"], type=o["headers"].get("content-type"), body=o["body"][:160].decode("utf-8", "replace") if o["status"] != 200 else f"{len(o['body'])} bytes")

    # ---- STT tokens: visitor cap 8 -------------------------------------------
    tokS = signup()
    got = 0
    for i in range(10):
        time.sleep(1.0)
        o = call("GET", "/functions/v1/stt-token?source=demo", None, tokS, {"Origin": ORIGIN})
        b = jbody(o) or {}
        rec("stt_token", n=i + 1, status=o["status"], keys=list(b.keys())[:4], retry_after=o["headers"].get("retry-after"),
            err=(b.get("error") if o["status"] != 200 else None))
        if o["status"] == 200:
            got += 1
        else:
            break

    # ---- network cap (20 questions / IP / day) ----------------------------------
    if not a.skip_ip_cap:
        counted = n  # questions asked from this network so far (the 429 for the visitor may or may not count)
        done_ip = False
        for v in range(1, 7):
            tok = signup()
            for k in range(5):
                r = ask(tok, dict(base, fragment=f"vad är {v + k} gånger 3"))
                counted += 1
                if r["status"] != 200:
                    rec("demo_ip_or_visitor_429", visitor=v, k=k + 1, counted_calls_from_network=counted, status=r["status"],
                        code=((r.get("err") or {}).get("error") or {}).get("code"), retry_after=r.get("retry_after"), err=r.get("err"))
                    if ((r.get("err") or {}).get("error") or {}).get("code") == "demo_limit_ip":
                        done_ip = True
                    break
            if done_ip:
                break

    # ---- waitlist -----------------------------------------------------------
    ts = int(time.time())
    em = f"oscar-qa-{ts}@example.com"
    wl = [("valid", {"email": em, "consent": True, "consent_version": "2026-11-06", "source": "demo", "website": ""}),
          ("duplicate", {"email": em, "consent": True, "consent_version": "2026-11-06", "source": "demo", "website": ""}),
          ("duplicate_case", {"email": em.upper(), "consent": True, "consent_version": "2026-11-06", "source": "demo", "website": ""}),
          ("no_consent", {"email": f"oscar-qa-nc-{ts}@example.com", "consent": False, "consent_version": "2026-11-06", "source": "demo", "website": ""}),
          ("consent_missing", {"email": f"oscar-qa-nm-{ts}@example.com", "source": "demo", "website": ""}),
          ("invalid_email", {"email": "inte-en-epost", "consent": True, "consent_version": "2026-11-06", "source": "demo", "website": ""}),
          ("honeypot", {"email": f"oscar-qa-hp-{ts}@example.com", "consent": True, "consent_version": "2026-11-06", "source": "demo", "website": "http://spam.example"})]
    for name, b in wl:
        time.sleep(1.2)
        o = call("POST", "/functions/v1/waitlist", b, None, {"Origin": ORIGIN})
        rec("waitlist_" + name, status=o["status"], body=o["body"][:200].decode("utf-8", "replace"), acao=o["headers"].get("access-control-allow-origin"),
            retry_after=o["headers"].get("retry-after"))
    for i in range(4):  # rate limit: 5/hour per network; earlier calls count (unknown whether failures do)
        time.sleep(1.2)
        o = call("POST", "/functions/v1/waitlist", {"email": f"oscar-qa-r{i}-{ts}@example.com", "consent": True, "consent_version": "2026-11-06", "source": "demo", "website": ""})
        rec("waitlist_rate", i=i + 1, status=o["status"], body=o["body"][:160].decode("utf-8", "replace"), retry_after=o["headers"].get("retry-after"))
        if o["status"] == 429:
            break

    # ---- D72/D73: one suggestion, count requests, interview ---------------------
    tok = signup()
    sc = {
        "stall": [{"speaker": "user", "text": "Gillar du jobbet?"}, {"speaker": "other", "text": "Det är väl okej."}, {"speaker": "user", "text": "Vad jobbar du med mest?"}, {"speaker": "other", "text": "Excel mest."}],
        "pizza": [{"speaker": "other", "text": "Vi beställde pizza och glömde att beställa till mig."}],
        "gruppen": [{"speaker": "other", "text": "Jag tappade bort mina nycklar tre gånger i veckan."}, {"speaker": "other", "text": "Han hittar alltid dem i kylen."}],
        "nej": [{"speaker": "user", "text": "Får jag ditt nummer?"}, {"speaker": "other", "text": "Nej tack, jag vill inte ge ut det."}],
    }

    def social(style, trans, trigger="other_spoke", calibrate=None, calibration=None):
        s = {"style": style, "trigger": trigger, "transcript": trans}
        if calibrate:
            s["calibrate"] = calibrate
        if calibration:
            s["calibration"] = calibration
        b = {"fragment": "", "mode": "tutor", "language": "sv", "persona": "social", "social": s, "context": {}}
        if style == "flirt":
            b["adult_confirmed"] = True
        return b

    def show(name, r, **kw):
        d = r.get("done") or {}
        sg = r.get("suggestions")
        rec(name, status=r["status"], n=len(sg) if sg else None, suggestions=sg, preview=r.get("preview"), preview_ms=None, first_ms=r["first_ms"], total_ms=r["ms"],
            calibration=d.get("calibration"), cost=r.get("cost"), err=r.get("err"), **kw)

    for style in ("social", "flirt"):
        for k, t in sc.items():
            show(f"d72_one_{style}_{k}", ask(tok, social(style, t, "stall" if k == "stall" else "other_spoke")), style=style)
    for style, cal, exp in (("flirt", "ge mig tre pickup lines", 3), ("social", "ge mig tre skämt", 3), ("social", "visa fler", 3),
                            ("social", "nästa", 1), ("flirt", "ge mig en till", 1), ("social", "ge mig tio skämt", 5),
                            ("social", "fler skämt", None), ("social", "lite mindre kaxig", None)):
        show(f"d72_count_{style}_{cal.replace(' ', '_')}", ask(tok, social(style, sc["gruppen"], calibrate=cal)), expected=exp, style=style)
    show("d72_calibration_stored_used", ask(tok, social("social", sc["pizza"], calibration="Gillar torr humor, undvik ordvitsar.")), style="social")

    iv = {"fragment": "", "mode": "tutor", "language": "sv", "persona": "interview",
          "persona_setup": "Sommarjobb som butiksbiträde i en matbutik", "context": {}}
    hist = []
    for name, q, turn in (("q1", "berätta om dig själv", "question"), ("q2", "varför vill du jobba här", "question"),
                          ("q3", "hur hanterar du en arg kund", "question"), ("q4", "vad är din största svaghet", "question"),
                          ("feedback", "ge mig feedback", "user_answer"), ("klar", "klar", "question")):
        b = dict(iv, fragment=q, turn=turn)
        b["mode"] = "tutor"
        if hist:
            b["context"] = {"recent_qa": hist[-6:]}
        r = ask(tok, b)
        d = r.get("done") or {}
        rec("d72_interview_" + name, q=q, turn=turn, status=r["status"], text=r.get("text"), chars=len(r.get("text") or ""),
            sentences=(r.get("text") or "").count(". ") + 1, summary=d.get("summary"), first_ms=r["first_ms"], cost=r.get("cost"), err=r.get("err"))
        hist.append({"q": q, "a": r.get("text") or ""})

    out = pathlib.Path(ROOT / "reports" / "qa" / "data" / f"{stamp}-demo.json")
    out.write_text(json.dumps({"stamp": stamp, "spent_usd": round(spent, 5), "log": log}, ensure_ascii=False, indent=1, default=str), encoding="utf-8")
    print(f"done spent=${spent:.4f} -> {out}")


if __name__ == "__main__":
    main()
