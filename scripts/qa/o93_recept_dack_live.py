"""O93 (Deangelo 2026-11-20 17:50): Kevins rättning av recept och däck i webbprompten (O92), live, Oscar (moln).
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o93_recept_dack_live.py
Testkonto (x-earmind-test), /answer är text: 0 ElevenLabs. Webb: 2 enheter av testtaket. Claude cirka 0,02 USD.
Kollar: högst 80 ord, hel mening sist, källa kvar; ingen mening två gånger; ingen sammanfattning först i instruktionen och
inget "jag håller mig till de steg som …"; receptet når tillagningen (stek/grädda/koka)."""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE))
import qa_testaccount as T  # noqa: E402
T.install()
import importlib.util, json, re  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
spec = importlib.util.spec_from_file_location("live_eval", HERE.parent / "live-eval.py")
LE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(LE)
OK = []


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:2500], flush=True)


def sentences(t):
    return [x.strip().lower() for x in re.split(r"(?<=[.!?])\s+", t) if x.strip()]


be = LE.Backend()
u = be.user(0)
for q, kind in (("hur byter man däck", "steps"), ("recept på köttbullar", "recipe")):
    r = be.ask(u, {"fragment": q, "mode": "text", "language": "sv", "context": {"recent_qa": []}})
    d = r["done"] or {}
    text = r["text"].strip()
    spoken = re.sub(r"\s*Källa: [^.]*\.\s*$", "", LE.split_source(text)[0]) if d.get("source") else LE.split_source(text)[0]
    ss = sentences(spoken)
    words = len(spoken.split())
    # a repeated sentence: the same first six words twice
    heads = [" ".join(x.split()[:6]) for x in ss]
    repeat = sorted({h for h in heads if heads.count(h) > 1})
    meta = re.search(r"jag håller mig till|enligt de steg som|som .{0,30} beskriver", spoken, re.I)
    first = ss[0] if ss else ""
    summary_first = bool(re.match(r"(du byter|så här byter|för att byta|ett däckbyte)", first))
    cooks = bool(re.search(r"\b(stek|steker|stekning|bryn|grädda|koka|tillaga|i stekpannan|i pannan)", spoken, re.I))
    base = bool(r["text"]) and words <= 80 and spoken.rstrip()[-1:] in ".!?" and bool(d.get("source")) and not d.get("web_cap_test")
    if kind == "steps":
        ok = base and not repeat and not meta and not summary_first
        name = "O93 däck: ≤ 80 ord, källa, börjar med första steget, ingen upprepad mening, inget källprat"
    else:
        ok = base and not repeat and not meta and cooks
        name = "O93 köttbullar: ≤ 80 ord, källa, når tillagningen (stek), ingen upprepad mening"
    check(name, ok, {"ord": words, "source": d.get("source"), "web_searches": (d.get("usage") or {}).get("web_searches"),
                     "upprepad": repeat, "källprat": meta.group(0) if meta else None, "första meningen": first[:160],
                     "sammanfattning först": summary_first, "tillagning": cooks if kind == "recipe" else None,
                     "web_cap_test": d.get("web_cap_test"), "ttft_ms": r["ttft_ms"], "fel": r["error"], "text": text[:1500]})

print(f"\n=== O93 {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
