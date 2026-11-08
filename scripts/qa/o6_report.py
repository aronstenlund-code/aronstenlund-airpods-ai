#!/usr/bin/env python3
"""Oscar QA, O6: tables from reports/qa/data/<stamp>-o6-*.json (written by o6_audio.py).
  python -I scripts/qa/o6_report.py reports/qa/data/<file>.json > reports/qa/data/<file>-tables.md"""
import json, statistics, sys, collections

sys.stdout.reconfigure(encoding="utf-8")
d = json.load(open(sys.argv[1], encoding="utf-8"))
rows, S = d["rows"], d["summary"]
CONDS = ["tyst", "prat 10 dB", "prat 5 dB", "airpods 16 kHz", "hfp 8 kHz", "prat 20 dB burst", "prat 10 dB burst", "prat 5 dB burst"]
MODES = [("nokt", "no keyterms"), ("kt", "right keyterms"), ("wrongkt", "wrong keyterms")]


def pct(x, n):
    return f"{100 * x / n:.0f} %" if n else "–"


def pctl(v, p):
    v = sorted(v)
    return f"{v[min(len(v) - 1, int(p * len(v)))]:.1f}" if v else "–"


def line(rs):
    n = len(rs)
    ch = [r for r in rs if r.get("chain_ok") is not None]
    return (f"{n} | {statistics.mean(r['wer'] for r in rs):.2f} | {pct(sum(r['exact'] for r in rs), n)} | {pct(sum(r['term_ok'] for r in rs), n)} | "
            f"{pct(sum(r['clipped'] for r in rs), n)} | {pct(sum(r['missing'] for r in rs), n)} | {pct(sum(r['stray'] > 0 for r in rs), n)} | "
            f"{pctl([r['lag_s'] for r in rs if r['lag_s'] is not None], .5)} / {pctl([r['lag_s'] for r in rs if r['lag_s'] is not None], .9)} | "
            f"{pctl([r['first_text_s'] for r in rs if r['first_text_s'] is not None], .5)} | "
            f"{pct(sum(r['chain_ok'] for r in ch), len(ch))} / {pct(sum(r['text_ok'] for r in ch), len(ch))}")


print(f"# O6 tables {S['stamp']} ({'pilot' if S['pilot'] else 'full'}): {S['cases']} cases, voices {', '.join(S['voices'])}, model {S['model']}, judge {S['judge']}\n")
print(f"TTS {S['tts_chars']} characters, realtime Scribe {S['realtime_scribe_s']} s, batch Scribe {S['batch_scribe_s']} s, LLM {S['llm_usd']} USD, {S['distinct_chain']} distinct answers graded, {S['streams']} Scribe sessions.\n")
HEAD = "| n | WER | exact | subject word | clipped | nothing | stray commit | commit lag s p50/p90 | first text s p50 | first answer enough (heard / text) |\n|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|"
for mode, label in MODES:
    print(f"## {label}\n")
    print("| Condition " + HEAD)
    for cond in CONDS:
        rs = [r for r in rows if r["mode"] == mode and r["cond"] == cond]
        if rs:
            print(f"| {cond} | " + line(rs) + " |")
    print()
print("## By kind (keyterms right, all conditions) / (quiet only)\n\n| Kind | all: n | WER | subject word | first answer enough | quiet: WER | subject word |\n|---|--:|--:|--:|--:|--:|--:|")
for k in ["term", "short", "half", "followup", "exam"]:
    rs = [r for r in rows if r["mode"] == "kt" and r["kind"] == k]
    q = [r for r in rs if r["cond"] == "tyst"]
    if rs:
        ch = [r for r in rs if r.get("chain_ok") is not None]
        print(f"| {k} | {len(rs)} | {statistics.mean(r['wer'] for r in rs):.2f} | {pct(sum(r['term_ok'] for r in rs), len(rs))} | {pct(sum(r['chain_ok'] for r in ch), len(ch))} (text {pct(sum(r['text_ok'] for r in ch), len(ch))}) | "
              f"{(statistics.mean(r['wer'] for r in q) if q else float('nan')):.2f} | {pct(sum(r['term_ok'] for r in q), len(q))} |")
print("\n## By voice (no keyterms, all conditions)\n\n| Voice | n | WER | subject word | clipped |\n|---|--:|--:|--:|--:|")
for v in S["voices"]:
    rs = [r for r in rows if r["mode"] == "nokt" and r["voice"] == v]
    if rs:
        print(f"| {v} | {len(rs)} | {statistics.mean(r['wer'] for r in rs):.2f} | {pct(sum(r['term_ok'] for r in rs), len(rs))} | {pct(sum(r['clipped'] for r in rs), len(rs))} |")
print("\n## Batch vs realtime (no keyterms)\n\n| Condition | n | batch WER | realtime WER | batch exact | realtime exact |\n|---|--:|--:|--:|--:|--:|")
for cond in ("tyst", "prat 5 dB"):
    rs = [r for r in rows if r["mode"] == "nokt" and r["cond"] == cond and r.get("batch") is not None]
    if rs:
        print(f"| {cond} | {len(rs)} | {statistics.mean(r['batch_wer'] for r in rs):.2f} | {statistics.mean(r['wer'] for r in rs):.2f} | "
              f"{pct(sum(r['batch_wer'] == 0 for r in rs), len(rs))} | {pct(sum(r['exact'] for r in rs), len(rs))} |")
loss = [r for r in rows if r.get("chain_ok") == 0 and r.get("text_ok") == 1]
gain = [r for r in rows if r.get("chain_ok") == 1 and r.get("text_ok") == 0]
print(f"\n## Chain loss\n\nGraded rows: {sum(r.get('chain_ok') is not None for r in rows)}; heard-text answer worse than the plain-text answer (text ok, heard not): {len(loss)}; better: {len(gain)}.\n")
# a case that fails as plain text too is not a hearing loss
print("Rows by cause when the heard answer failed: ", collections.Counter(("text also failed" if r.get("text_ok") == 0 else "hearing") for r in rows if r.get("chain_ok") == 0))
print("\n## 10 worst (hearing loss first, then WER)\n")
worst = sorted([r for r in rows if r["mode"] in ("nokt", "kt")], key=lambda r: ((r.get("chain_ok") == 0 and r.get("text_ok") == 1) * -1, -r["wer"], -r["commits"]))[:10]
for r in worst:
    print(f"- {r['id']} {r['mode']} · {r['cond']} · {r['voice']}: said \"{r['say']}\" → heard \"{r['heard']}\" (WER {r['wer']}, commits {r['commits']}, "
          f"answer enough {r.get('chain_ok')}, plain text {r.get('text_ok')}); answer: {r.get('answer', '')[:160]!r}")

# window and segment view: what arrives before the next question starts, and whether the subject word was heard at all
import importlib.util, os
spec = importlib.util.spec_from_file_location("k", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio-eval.py"))
if os.environ.get("O6_LIB"):
    sys.path.insert(0, os.environ["O6_LIB"])
E = importlib.util.module_from_spec(spec); spec.loader.exec_module(E)
seg = collections.defaultdict(list)
key = lambda r: (r["mode"], r["voice"], r["cond"], r["subject"] if r["mode"] != "nokt" else "*")
for r in rows:
    seg[key(r)] += r["commit_texts"]
print("\n## Window and segment view\n\n'In window' = commits that arrive from the start of the question until the next question starts. "
      "'Anywhere' = the subject word is somewhere in that condition's transcript (heard, but maybe late or merged).\n")
print("| Mode | Condition | n | words of the question in window | subject word in window | subject word anywhere | nothing in window | > 3 extra words in window |\n|---|---|--:|--:|--:|--:|--:|--:|")
for mode, label in MODES:
    for cond in CONDS:
        rs = [r for r in rows if r["mode"] == mode and r["cond"] == cond and "win_recall" in r]
        if not rs:
            continue
        n = len(rs)
        tw = sum(E.term_ok({"say": r["say"], "kind": r["kind"]}, r["win_text"]) for r in rs)
        ta = sum(E.term_ok({"say": r["say"], "kind": r["kind"]}, " ".join(seg[key(r)])) for r in rs)
        print(f"| {label} | {cond} | {n} | {statistics.mean(r['win_recall'] for r in rs):.2f} | {pct(tw, n)} | {pct(ta, n)} | "
              f"{pct(sum(not r['win_text'] for r in rs), n)} | {pct(sum(r['win_extra'] > 3 for r in rs), n)} |")
