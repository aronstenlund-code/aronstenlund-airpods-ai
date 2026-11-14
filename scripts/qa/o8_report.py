"""O8 tables from the two runs. python -I scripts/qa/o8_report.py"""
import sys as _d180s, pathlib as _d180p; _d180s.path.insert(0, str(_d180p.Path(__file__).resolve().parent)); import qa_testaccount; qa_testaccount.install()  # D180: bara testkonton, aldrig riktiga ElevenLabs
import json, pathlib, sys
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
rows = []
for f in ("2026-11-09-1812-o8.json", "2026-11-09-1819-fragor-o8.json"):
    rows += json.loads((ROOT / "reports/qa/data" / f).read_text(encoding="utf-8"))["rows"]
def pct(v, p):
    v = sorted(x for x in v if x is not None)
    return v[min(len(v) - 1, int(round(p * (len(v) - 1))))] if v else None
def s(ms):
    return "–" if ms is None else f"{ms / 1000:.1f}"
groups = [("Provläge: ämnesord", lambda r: r["mode"] == "prov" and r["kind"] == "term"), ("Provläge: provfrågor", lambda r: r["kind"] == "exam"),
          ("Provläge: följdfrågor", lambda r: r["kind"] == "followup"), ("Provläge: textuppgifter (tänkande)", lambda r: r["kind"] == "word"),
          ("Provläge: derivata x6 (O5-hänget)", lambda r: r["kind"] == "hang-repro"), ("**Provläge, alla**", lambda r: r["mode"] == "prov"),
          ("**Frågor (Haiku)**", lambda r: r["mode"] == "fragor")]
print("| Grupp | n | Första text p50 / p90 / max (s) | Första ljud p50 / p90 / max (s) | Hela svaret p50 / p90 (s) | > 5 s till ljud | > 30 s | Kostnad per fråga (USD) |\n|---|--:|--:|--:|--:|--:|--:|--:|")
for name, f in groups:
    rs = [r for r in rows if f(r)]
    ft, fa, dn = [r["first_text_ms"] for r in rs], [r["first_audio_ms"] for r in rs], [r["done_ms"] for r in rs]
    over5 = sum(1 for r in rs if (r["first_audio_ms"] or 10**9) > 5000)
    over30 = sum(1 for r in rs if (r["done_ms"] or 10**9) > 30000)
    c = sum(r["cost"] for r in rs) / max(1, len(rs))
    print(f"| {name} | {len(rs)} | {s(pct(ft,.5))} / {s(pct(ft,.9))} / {s(max(x for x in ft if x is not None))} | {s(pct(fa,.5))} / {s(pct(fa,.9))} / {s(max(x for x in fa if x is not None))} | "
          f"{s(pct(dn,.5))} / {s(pct(dn,.9))} | {over5} | {over30} | {c:.4f} |")
tts = [r["tts_first_byte_ms"] for r in rows if r["tts_first_byte_ms"]]
print(f"\n/tts first byte for the first sentence: p50 {s(pct(tts,.5))} s, p90 {s(pct(tts,.9))} s, max {s(max(tts))} s (n={len(tts)}); tts chars total {sum(r['tts_chars'] for r in rows)}")
print("\nSlowest 8 to first audio:")
for r in sorted(rows, key=lambda r: -(r["first_audio_ms"] or 10**9))[:8]:
    print(f"- {r['mode']} {r['kind']}: \"{r['q'][:80]}\" first text {s(r['first_text_ms'])} s, first audio {s(r['first_audio_ms'])} s, done {s(r['done_ms'])} s, {r['model']}, err {r['err']}, first sentence: {r['first_sentence'][:120]!r}")
print("\nErrors / not answered:", [(r["kind"], r["q"][:40], r["status"], r["err"], r["answered"]) for r in rows if r["err"] or r["status"] != 200 or not r["text"]])
prov = [r["cost"] for r in rows if r["mode"] == "prov"]; fr = [r["cost"] for r in rows if r["mode"] == "fragor"]
cp, cf = sum(prov) / len(prov), sum(fr) / len(fr)
print(f"\nCost per question: Provläge {cp:.4f}, Frågor {cf:.5f}. Per hour (30 questions): Provläge {30*cp:.3f}, Frågor {30*cf:.4f}. 100 USD/month = {100/(30*cp):.0f} Provläge hours or {100/(30*cf):.0f} Frågor hours.")
print("Tokens Provläge mean in/out/cache_read:", round(sum(r["in_tok"] or 0 for r in rows if r["mode"]=="prov")/len(prov)), round(sum(r["out_tok"] or 0 for r in rows if r["mode"]=="prov")/len(prov)), round(sum(r["cache_read"] or 0 for r in rows if r["mode"]=="prov")/len(prov)))
