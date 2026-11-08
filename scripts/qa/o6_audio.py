#!/usr/bin/env python3
"""Oscar QA, O6 (D88): hearing without a phone. Speech from the backend's /tts (ElevenLabs), five listening conditions,
transcribed by Scribe v2 Realtime exactly like the app (stt-token socket, Provläge's VAD values, keyterms), then
transcript -> /answer (Provläge, profile) -> D87 rubric, next to the same case as plain text.

Differences from Kevin's scripts/audio-eval.py (reviewed first, see the report):
  * background chatter runs through the whole stream, also in the pauses (Kevin mixes it into the clips only, so the
    VAD never meets chatter in a pause);
  * a commit that arrives while a clip is playing belongs to THAT clip (Kevin attributes it to the previous one);
  * keyterms off / right subject / WRONG subject (does a keyterm list bias what is heard when the student changes subject?);
  * chain graded for every transcript variant, not only keyterms on;
  * extra condition: 8 kHz Bluetooth hands-free (narrowband), because R10 says that is what AirPods may give;
  * commit lag and first-text lag are measured; the Silero SpeechGate in front of Scribe (D78) is NOT simulated.

  python -I scripts/qa/o6_audio.py --pilot
Needs numpy + scipy + websockets: set O6_LIB to a folder holding scipy and websockets (pip install --target).
Audio goes to --audio-dir (a scratch folder, never git; *.wav is also in .gitignore).
"""
import argparse, asyncio, base64, collections, datetime, hashlib, importlib.util, json, os, re, sys, time, urllib.parse

sys.stdout.reconfigure(encoding="utf-8")
if os.environ.get("O6_LIB"):
    sys.path.insert(0, os.environ["O6_LIB"])
import numpy as np
import websockets
from scipy.signal import butter, resample_poly, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
spec = importlib.util.spec_from_file_location("kevin_audio", os.path.join(ROOT, "scripts", "audio-eval.py"))
E = importlib.util.module_from_spec(spec)
spec.loader.exec_module(E)  # only definitions; main() is guarded
SR = E.SR
GAP_S = 2.2
LEAD_S = 0.5
SEG_GAP_S = 3.0

# pilot: four 'exams' (subject groups) with a mix of kinds and some hard-to-hear terms
PILOT_IDS = ["au-09", "au-14", "au-31", "au-39",  # Åk 9 Biologi: follow-up, short, term, half sentence
             "au-15", "au-23", "au-33", "au-49",  # Åk 9 Fysik: short, "ohms lag", term, follow-up with numbers
             "au-05", "au-08", "au-25", "au-50",  # Åk 8 Historia: term, half sentence, term, follow-up
             "au-17", "au-43", "au-57"]           # Åk 9 Matematik: "pythagoras", follow-up, "kvadratrot"
CONDS = ["tyst", "prat 10 dB", "prat 5 dB", "airpods 16 kHz", "hfp 8 kHz"]
WRONG_CONDS = ["tyst", "prat 5 dB"]
# --burst: chatter in bursts with pauses (more like a room) at three levels; the plain "prat" conditions run unbroken talk
BURST_CONDS = ["prat 20 dB burst", "prat 10 dB burst", "prat 5 dB burst"]

BABBLE_A = E.BABBLE_LINES
BABBLE_B = [
    "Jag glömde skicka in uppgiften i går kväll, så nu måste jag ursäkta mig.", "Ska vi sitta tillsammans på lunchen eller är du upptagen?",
    "Det luktar som att någon har bränt popcorn i hela korridoren.", "Nej men verkligen, hon sa precis samma sak förra veckan också.",
    "Kan någon hålla upp dörren, jag har händerna fulla med böcker.", "Vi borde fråga om vi får ha fotbollen inne i salen i morgon.",
    "Har du hört att det kommer ett nytt spel på fredag, alla pratar om det.", "Jag tog fel buss i morse och kom tjugo minuter för sent.",
    "Mamma sa att jag får sova över hos dig om vi är tysta.", "Titta, det börjar regna precis när rasten är slut.",
]

spent = {"llm": 0.0, "tts_chars": 0, "rt_audio_s": 0.0, "batch_audio_s": 0.0}


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, file=sys.stderr, flush=True)


# ---------------------------------------------------------------- audio
def tts_cached(tok, text, voice, cache_dir):
    os.makedirs(cache_dir, exist_ok=True)
    p = os.path.join(cache_dir, f"{voice['name']}-{hashlib.sha1(text.encode()).hexdigest()[:12]}.npy")
    if os.path.exists(p):
        return np.load(p)
    x = E.tts(tok, text, voice["id"])
    spent["tts_chars"] += len(text)
    np.save(p, x)
    time.sleep(0.25)
    return x


def unit(x):
    return x / (E.rms(x) + 1e-9)


def hfp8(x, seed):
    """Narrowband hands-free (CVSD-like): 8 kHz sampling, 300-3400 Hz, a little noise."""
    rng = np.random.default_rng(seed)
    y = resample_poly(x, 1, 2)
    y = sosfilt(butter(4, [300, 3400], btype="bandpass", fs=8000, output="sos"), y)
    y = resample_poly(y, 2, 1).astype(np.float32)[: len(x)]
    y = np.pad(y, (0, len(x) - len(y)))
    y += rng.normal(0, 10 ** (-48 / 20), y.shape).astype(np.float32)
    return np.clip(y * 0.8, -1, 1)


def apply_condition(cond, seg, mask, babble, k):
    if cond == "tyst":
        return seg
    if cond.startswith("prat"):
        snr = 20 if "20" in cond else 10 if "10" in cond else 5
        bb = babble["burst"] if "burst" in cond else babble["cont"]
        b = np.resize(np.roll(bb, -(k * 7919)), seg.shape)
        ref = 1.0 if "burst" in cond else E.rms(b)  # burst babble is normalised to unit RMS over its active parts
        gain = E.rms(seg[mask]) / (ref * (10 ** (snr / 20)))  # SNR measured over the speech only
        y = seg + gain * b
        return (y / max(1.0, float(np.max(np.abs(y))) / 0.98)).astype(np.float32)
    if cond == "airpods 16 kHz":
        return E.airpods(seg, k)
    if cond == "hfp 8 kHz":
        return hfp8(seg, k)
    raise ValueError(cond)


def build_segment(cond, items, babble, k):
    """items = [(cid, clip)] -> (audio, mask, timeline [(cid, start_s, end_s)] relative to the segment start)."""
    parts, mask, timeline, pos = [], [], [], 0.0
    lead = np.zeros(int(LEAD_S * SR), dtype=np.float32)
    parts.append(lead); mask.append(np.zeros(len(lead), bool)); pos += LEAD_S
    gap = np.zeros(int(GAP_S * SR), dtype=np.float32)
    for cid, clip in items:
        timeline.append((cid, pos, pos + len(clip) / SR))
        parts += [clip, gap]
        mask += [np.ones(len(clip), bool), np.zeros(len(gap), bool)]
        pos += (len(clip) + len(gap)) / SR
    seg, m = np.concatenate(parts), np.concatenate(mask)
    return apply_condition(cond, seg, m, babble, k).astype(np.float32), timeline


# ---------------------------------------------------------------- Scribe realtime
async def scribe(tok, audio, keyterms):
    t = E.http("GET", "/functions/v1/stt-token", tok=tok)
    q = {"model_id": t["model_id"], "token": t["token"], "language_code": "swe", "audio_format": "pcm_16000", "commit_strategy": "vad", **E.VAD}
    parts = [f"{k}={urllib.parse.quote(str(v))}" for k, v in q.items()]
    keyterms = [k for k in keyterms if len(k) <= 20]  # Scribe closes the session on a longer one (see the report)
    parts += [f"keyterms={urllib.parse.quote(k)}" for k in keyterms[:20]]
    if t.get("extra_query"):
        parts.append(t["extra_query"])
    url = t["ws_url"] + "?" + "&".join(parts)
    commits, partials, errors, closing = [], [], [], []
    chunk = SR // 10
    async with websockets.connect(url, max_size=None, open_timeout=30) as ws:
        t0 = time.monotonic()

        async def reader():
            try:
                async for msg in ws:
                    m = json.loads(msg)
                    kind = m.get("message_type") or m.get("type") or ""
                    now = time.monotonic() - t0
                    if kind.startswith("committed_transcript"):
                        commits.append((now, (m.get("text") or "").strip()))
                    elif kind == "partial_transcript":
                        if (m.get("text") or "").strip():
                            partials.append((now, m["text"].strip()))
                    elif "error" in kind or kind not in ("session_started",):
                        errors.append((round(now, 1), kind, str(m)[:300]))
            except websockets.ConnectionClosed as ce:
                if not closing:  # our own close at the end is no error
                    errors.append((round(time.monotonic() - t0, 1), "closed", repr(ce)[:200]))
        rd = asyncio.create_task(reader())
        try:
            for i in range(0, len(audio), chunk):
                last = i + chunk >= len(audio)
                await ws.send(json.dumps({"message_type": "input_audio_chunk", "audio_base_64": base64.b64encode(E.to_pcm16(audio[i:i + chunk])).decode(),
                                          "commit": last, "sample_rate": SR}))
                await asyncio.sleep(max(0, (i + chunk) / SR - (time.monotonic() - t0)))
        except websockets.ConnectionClosed:
            errors.append((round(time.monotonic() - t0, 1), "send_failed_at_s", round(i / SR, 1)))
        await asyncio.sleep(3)
        closing.append(1)
        try:
            await ws.close()
        except Exception:
            pass
        await rd
    spent["rt_audio_s"] += len(audio) / SR
    if errors:
        log("scribe messages", errors[:4])
    return commits, partials, errors


def attribute(timeline, commits, partials):
    """Per clip: its commits, the lag of the last commit after the clip ended, first text lag after the clip started.
    A commit/partial belongs to the last clip that had started when it arrived."""
    starts = [s for _, s, _ in timeline]
    out = {cid: {"commits": [], "partials": [], "end": e, "start": s} for cid, s, e in timeline}
    def owner(t):
        k = max((i for i, s in enumerate(starts) if s <= t), default=None)
        return None if k is None else timeline[k][0]
    for t, txt in commits:
        o = owner(t)
        if o and txt:
            out[o]["commits"].append((t, txt))
    for t, txt in partials:
        o = owner(t)
        if o:
            out[o]["partials"].append((t, txt))
    return out


# ---------------------------------------------------------------- scoring
def stray(ref, hyp_commits):
    """Commits with no word in common with what was said (chatter heard as speech, or a hallucination)."""
    r = set(E.norm(ref).split())
    return sum(1 for _, t in hyp_commits if not (set(E.norm(t).split()) & r))


def grade_chain(toks, cache, cases_by_id, cid, text, model, judge, cap):
    c = cases_by_id[cid]
    key = (cid, E.norm(text))
    if key in cache:
        return cache[key][0], cache[key][1], False
    if spent["llm"] >= cap:
        return None, "", False
    try:
        ok, ans, cost = E.chain(toks[len(cache) % len(toks)], c, text, model, judge, cache)
    except Exception as ex:
        log("chain failed", cid, repr(ex)[:160])
        return None, "", False
    spent["llm"] += cost
    return ok, ans, True


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pilot", action="store_true")
    ap.add_argument("--voices", type=int, default=3)
    ap.add_argument("--model", default="haiku")
    ap.add_argument("--judge", default="sonnet")
    ap.add_argument("--max-llm-usd", type=float, default=0.8)
    ap.add_argument("--audio-dir", required=True)
    ap.add_argument("--out", default=os.path.join(ROOT, "reports", "qa", "data"))
    ap.add_argument("--concurrency", type=int, default=4)
    ap.add_argument("--burst", action="store_true", help="chatter in bursts at 20/10/5 dB instead of the plain conditions")
    a = ap.parse_args()
    cases = json.load(open(os.path.join(ROOT, "scripts", "audio-bank.json"), encoding="utf-8"))
    if a.pilot:
        by = {c["id"]: c for c in cases}
        cases = [by[i] for i in PILOT_IDS]
    cbi = {c["id"]: c for c in cases}
    toks = [E.signup() for _ in range(4)]
    voices = E.http("GET", "/functions/v1/voices", tok=toks[0])["voices"][: a.voices]
    log("voices", [v["name"] for v in voices], "cases", len(cases))
    cache_dir = os.path.join(a.audio_dir, "tts")

    # keyterms per subject, like the app (/study-profile terms, at most 20)
    groups = collections.OrderedDict()
    for c in cases:
        groups.setdefault(c["subject"], []).append(c["id"])
    terms = {}
    tfile = os.path.join(a.audio_dir, "terms.json")  # /study-profile answers vary between calls: keep them for a re-run
    if os.path.exists(tfile):
        terms = json.load(open(tfile, encoding="utf-8"))
    for subj, ids in groups.items():
        if subj in terms:
            continue
        p = E.http("POST", "/functions/v1/study-profile", {"text": f"jag går i {cbi[ids[0]]['grade']} och har prov i {subj.lower()}"}, toks[1], timeout=60)
        terms[subj] = ([subj] + p.get("terms", []))[:20]
        time.sleep(1.5)
    json.dump(terms, open(tfile, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    subj_list = list(groups)
    wrong_terms = {s: terms[subj_list[(i + 1) % len(subj_list)]] for i, s in enumerate(subj_list)}

    # speech + chatter (all by the backend's TTS)
    speech = {(v["name"], c["id"]): tts_cached(toks[(i + j) % 4], c["say"], v, cache_dir) for i, v in enumerate(voices) for j, c in enumerate(cases)}
    def talker(lines, shift):
        return [tts_cached(toks[i % 4], ln, voices[(i + shift) % len(voices)], cache_dir) for i, ln in enumerate(lines)]
    la, lb = talker(BABBLE_A, 0), talker(BABBLE_B, 1)
    ta, tb = np.concatenate(la), np.concatenate(lb)
    n = max(len(ta), len(tb))
    cont = (unit(np.resize(ta, n)) + unit(np.resize(tb, n))).astype(np.float32)

    def burst(lines, lo, hi, offset, seed):
        rng = np.random.default_rng(seed)
        out = [np.zeros(int(offset * SR), dtype=np.float32)]
        while sum(len(x) for x in out) / SR < 150:
            for ln in lines:
                out += [ln, np.zeros(int(rng.uniform(lo, hi) * SR), dtype=np.float32)]
        return np.concatenate(out)
    ba, bb_ = burst(la, 0.6, 2.0, 0.0, 1), burst(lb, 0.8, 3.0, 1.3, 2)
    m = min(len(ba), len(bb_))
    bur = ba[:m] + bb_[:m]
    act = bur[np.abs(bur) > 0.02]
    bur = (bur / E.rms(act)).astype(np.float32)
    babble = {"cont": cont, "burst": bur}
    log("tts chars", spent["tts_chars"], "babble s", round(len(cont) / SR, 1), "burst s", round(len(bur) / SR, 1))

    # streams
    jobs = []  # (mode, voice, key, segments=[(cond, [cids])], keyterms)
    conds = BURST_CONDS if a.burst else CONDS
    for v in voices:
        for cond in conds:
            jobs.append(("nokt", v["name"], cond, [(cond, [c["id"] for c in cases])], []))
        for subj, ids in groups.items():
            jobs.append(("kt", v["name"], subj, [(cd, ids) for cd in conds], terms[subj]))
            if not a.burst:
                jobs.append(("wrongkt", v["name"], subj, [(cd, ids) for cd in WRONG_CONDS], wrong_terms[subj]))
    log("streams", len(jobs))
    rows, streams_audio = [], {}
    results, failed, rawc = {}, {}, {}
    sfile = os.path.join(a.audio_dir, "streams-burst.json" if a.burst else "streams.json")  # raw Scribe results, saved after every session; delete to measure again
    saved = json.load(open(sfile, encoding="utf-8")) if os.path.exists(sfile) else {}

    async def run_all():
        sem = asyncio.Semaphore(a.concurrency)
        async def one(n, job):
            mode, vn, key, segs, kts = job
            await asyncio.sleep(n * 2.5)  # stay under the token-mint limit (6 per minute per user)
            parts, timeline, pos = [], [], 0.0
            for si, (cond, ids) in enumerate(segs):
                seg, tl = build_segment(cond, [(i, speech[(vn, i)]) for i in ids], babble, n * 13 + si)
                for cid, s, e in tl:
                    timeline.append(((cond, cid), pos + s, pos + e))
                parts += [seg, np.zeros(int(SEG_GAP_S * SR), dtype=np.float32)]
                pos += len(seg) / SR + SEG_GAP_S
            audio = np.concatenate(parts)
            streams_audio[(mode, vn, key)] = (audio, timeline)
            skey = f"{mode}|{vn}|{key}"
            if skey in saved:
                commits, partials, errors = saved[skey]["commits"], saved[skey]["partials"], saved[skey]["errors"]
            else:
                async with sem:
                    for attempt in range(3):
                        try:
                            commits, partials, errors = await scribe(toks[n % 4], audio, kts)
                            if any(e[1] in ("closed", "send_failed_at_s") for e in errors) and attempt < 2:
                                log("scribe early close, retry", mode, vn, key, errors[:2], "terms:", kts)
                                await asyncio.sleep(15)
                                continue
                            break
                        except Exception as ex:
                            log("scribe retry", mode, vn, key, repr(ex)[:150])
                            errors = [(0, "exception", repr(ex)[:200])]
                            commits, partials = [], []
                            await asyncio.sleep(20)
                saved[skey] = {"commits": commits, "partials": partials, "errors": errors, "terms": kts}
                json.dump(saved, open(sfile, "w", encoding="utf-8"), ensure_ascii=False)
            failed[(mode, vn, key)] = bool(errors) and any(e[1] in ("closed", "send_failed_at_s", "exception") for e in errors) and not commits
            results[(mode, vn, key)] = attribute(timeline, commits, partials)
            rawc[(mode, vn, key)] = commits
            log("done", mode, vn, key, len(commits), "commits", "FAILED" if failed[(mode, vn, key)] else "")
        await asyncio.gather(*(one(n, j) for n, j in enumerate(jobs)))
    asyncio.run(run_all())

    # rows
    for (mode, vn, key), per in results.items():
        audio, tl = streams_audio[(mode, vn, key)]
        lastkey = tl[-1][0] if tl else None
        for (cond, cid), d in per.items():
            c = cbi[cid]
            commits = d["commits"]
            hyp = " ".join(t for _, t in commits)
            lag = None if (cond, cid) == lastkey or not commits else round(commits[-1][0] - d["end"], 2)
            first = round(min(t for t, _ in (d["partials"] + commits)) - d["start"], 2) if (d["partials"] or commits) else None
            # window view: commits that arrive from the start of this clip until the next clip starts (what the app would act on)
            keys = [k for k, _, _ in tl]
            ni = keys.index((cond, cid)) + 1
            wend = (tl[ni][1] + 0.3) if ni < len(tl) else d["end"] + 4.0
            wt = " ".join(x for t, x in rawc[(mode, vn, key)] if d["start"] <= t <= wend and x)
            tw, hw = set(E.norm(c["say"]).split()), E.norm(wt).split()
            win_recall = round(sum(1 for w in tw if w in hw) / max(1, len(tw)), 2)
            win_extra = sum(1 for w in hw if w not in tw)
            if "burst" in cond:
                hyp = wt
            rows.append({"mode": mode, "cond": cond, "voice": vn, "id": cid, "kind": c["kind"], "subject": c["subject"], "say": c["say"], "heard": hyp,
                         "commits": len(commits), "commit_texts": [t for _, t in commits], "wer": round(E.wer(c["say"], hyp), 3),
                         "exact": E.norm(c["say"]) == E.norm(hyp), "term_ok": E.term_ok(c, hyp), "clipped": len(commits) > 1, "missing": len(commits) == 0,
                         "stray": stray(c["say"], commits), "lag_s": lag, "first_text_s": first, "stream_failed": failed[(mode, vn, key)],
                         "win_text": wt, "win_recall": win_recall, "win_extra": win_extra})

    # batch Scribe, quiet and 5 dB, first two voices, no keyterms (the nokt streams hold the same audio)
    batch_skipped = 0
    for vn in [v["name"] for v in voices[:2]]:
        for cond in (() if a.burst else ("tyst", "prat 5 dB")):
            audio, tl = streams_audio[("nokt", vn, cond)]
            for (cd, cid), s, e in tl:
                clip = audio[max(0, int((s - 0.3) * SR)): int((e + 0.8) * SR)]
                b64 = base64.b64encode(E.wav_bytes(clip)).decode()
                if len(b64) > 60000:  # the endpoint reads at most 64 KB of body (Kevin: it promises 2 MB, see report): cannot be sent
                    batch_skipped += 1
                    continue
                spent["batch_audio_s"] += len(clip) / SR
                try:
                    r = E.http("POST", "/functions/v1/provlage-eval", {"action": "transcribe", "audio_base64": b64}, toks[2], timeout=120)
                except Exception as ex:
                    log("batch failed", repr(ex)[:160])
                    continue
                for row in rows:
                    if row["mode"] == "nokt" and row["voice"] == vn and row["cond"] == cond and row["id"] == cid:
                        row["batch"] = r.get("text", "")
                        row["batch_wer"] = round(E.wer(row["say"], row["batch"]), 3)
            time.sleep(1)

    # chain: text baseline, then every distinct transcript
    cache, text_res = {}, {}
    for c in cases:
        ok, ans, _ = grade_chain(toks, cache, cbi, c["id"], c["say"], a.model, a.judge, a.max_llm_usd)
        text_res[c["id"]] = (ok, ans)
    for row in rows:
        ok, ans, _ = grade_chain(toks, cache, cbi, row["id"], row["heard"] or "…", a.model, a.judge, a.max_llm_usd)
        row.update(chain_ok=ok, text_ok=text_res[row["id"]][0], answer=ans[:300])
        if len(cache) % 25 == 0:
            log("chain", len(cache), "distinct, llm USD", round(spent["llm"], 3))

    stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M")
    name = f"{stamp}-o6-{'pilot' if a.pilot else 'full'}{'-burst' if a.burst else ''}"
    os.makedirs(a.out, exist_ok=True)
    summary = {"stamp": stamp, "pilot": a.pilot, "cases": len(cases), "voices": [v["name"] for v in voices], "model": a.model, "judge": a.judge,
               "tts_chars": spent["tts_chars"], "realtime_scribe_s": round(spent["rt_audio_s"], 1), "batch_scribe_s": round(spent["batch_audio_s"], 1), "batch_clips_too_big": batch_skipped,
               "burst": a.burst, "failed_streams": [k for k, v in failed.items() if v], "terms": terms,
               "llm_usd": round(spent["llm"], 4), "distinct_chain": len(cache), "streams": len(jobs)}
    json.dump({"summary": summary, "rows": rows}, open(os.path.join(a.out, name + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    for (mode, vn, key), (audio, _) in streams_audio.items():
        if mode == "nokt" and vn == voices[0]["name"]:
            open(os.path.join(a.audio_dir, f"stream-{vn}-{key.replace(' ', '_')}.wav"), "wb").write(E.wav_bytes(audio))
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
