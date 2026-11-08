#!/usr/bin/env python3
"""D88: the whole chain without a phone. Speech is made with ElevenLabs TTS (the backend's /tts and allowed voices),
put through four listening conditions, transcribed by Scribe exactly like the app (realtime socket from /stt-token,
commit_strategy vad with Provläge's values, keyterms from a study profile) with and without keyterms, and by batch
Scribe for comparison. The transcript then goes to /answer in Provläge with the profile and is graded with the D87
rubric, next to the same case as plain text.

  python3 scripts/audio-eval.py --pilot            # 15 cases
  python3 scripts/audio-eval.py                    # 60 cases
  options: --voices 4 --out DIR --audio-dir DIR --judge sonnet --model haiku

Audio is written to --audio-dir (an Actions artifact), never to git. Needs: pip install numpy scipy websockets."""
import argparse, asyncio, base64, datetime, io, json, os, re, sys, time, urllib.parse, urllib.request, wave
import numpy as np
from scipy.signal import butter, resample_poly, sosfilt
import websockets

HOST = "xjczbzfkmbjdebwlccki.supabase.co"
URL = f"https://{HOST}"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 16000
# Provläge (D80/D87): pause 1.2 s, Scribe commits 0.4 s before -> 0.8 s; threshold 0.3 (ScribeTuning.forMode(.prov))
VAD = {"vad_silence_threshold_secs": "0.80", "vad_threshold": "0.30", "min_speech_duration_ms": "100", "min_silence_duration_ms": "100"}
GAP_S = 2.2  # silence between utterances in one stream (longer than the pause: each case is its own turn)
BABBLE_LINES = [
    "Har du sett var jag lade min jacka i morse?", "Vi skulle kunna åka till stan efter skolan i stället.",
    "Jag tror att bussen är sen igen idag.", "Kan du skicka laddaren när du ändå står där?",
    "Det var den bästa matchen jag har sett på länge.", "Min lillebror fyller år på lördag och vi ska baka.",
    "Hon sa att träningen är inställd på grund av regnet.", "Jag har inte hunnit äta lunch än, är du hungrig?",
    "Läraren glömde sin kaffekopp i klassrummet igen.", "Vi ses vid entrén klockan halv fyra.",
]
SWEDISH_FEMALE = {"anna", "sara", "sanna", "emma", "ella", "maja", "elin", "linnea", "klara", "ida", "hanna", "julia", "sofia", "alice", "astrid", "ebba", "freja", "lisa", "karin", "eva"}


def http(method, path, body=None, tok=None, raw=False, timeout=60):
    h = {"apikey": KEY, "content-type": "application/json"}
    if tok:
        h["authorization"] = "Bearer " + tok
    for attempt in range(4):
        req = urllib.request.Request(URL + path, method=method, headers=h,
                                     data=json.dumps(body).encode() if body is not None else None)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                data = r.read()
                return data if raw else json.loads(data or b"{}")
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 3:
                time.sleep(min(90, int(e.headers.get("retry-after") or 20)))
                continue
            raise RuntimeError(f"{method} {path}: HTTP {e.code} {e.read()[:200]!r}")


def signup():
    return http("POST", "/auth/v1/signup", {})["access_token"]


# ---------------- audio ----------------
def tts(tok, text, voice_id):
    pcm = http("POST", "/functions/v1/tts", {"text": text, "voice_id": voice_id, "output_format": "pcm_24000", "language": "sv"}, tok, raw=True, timeout=90)
    x = np.frombuffer(pcm, dtype="<i2").astype(np.float32) / 32768.0
    return resample_poly(x, 2, 3).astype(np.float32)  # 24 kHz -> 16 kHz


def rms(x):
    return float(np.sqrt(np.mean(np.square(x)) + 1e-12))


def mix(speech, babble, snr_db, offset):
    b = np.resize(np.roll(babble, -offset), speech.shape)
    gain = rms(speech) / (rms(b) * (10 ** (snr_db / 20)))
    y = speech + gain * b
    return y / max(1.0, float(np.max(np.abs(y))) / 0.98)


AIRPODS = butter(4, [100, 7000], btype="bandpass", fs=SR, output="sos")


def airpods(x, seed):
    """An AirPods-like mic: 16 kHz wideband HFP band (about 100-7000 Hz), a little noise floor and level change."""
    rng = np.random.default_rng(seed)
    y = sosfilt(AIRPODS, x).astype(np.float32) * 0.8
    y += rng.normal(0, 10 ** (-50 / 20), y.shape).astype(np.float32)
    return np.clip(y, -1, 1)


def to_pcm16(x):
    return (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()


def wav_bytes(x):
    bio = io.BytesIO()
    with wave.open(bio, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(to_pcm16(x))
    return bio.getvalue()


# ---------------- Scribe realtime, like the app ----------------
async def scribe_stream(tok, clips, keyterms):
    """One socket per (voice, condition, keyterms). Clips are sent in real time with GAP_S of silence between them;
    every committed transcript is assigned to the clip that was being sent (or had just ended) when it arrived."""
    t = http("GET", "/functions/v1/stt-token", tok=tok)
    q = {"model_id": t["model_id"], "token": t["token"], "language_code": "swe", "audio_format": "pcm_16000", "commit_strategy": "vad", **VAD}
    parts = [f"{k}={urllib.parse.quote(str(v))}" for k, v in q.items()]
    parts += [f"keyterms={urllib.parse.quote(k)}" for k in keyterms[:20]]
    if t.get("extra_query"):
        parts.append(t["extra_query"])
    url = t["ws_url"] + "?" + "&".join(parts)
    commits = []
    gap = np.zeros(int(GAP_S * SR), dtype=np.float32)
    timeline = []  # (start_s, end_s) of each clip in the stream
    stream = [gap[: SR // 2]]
    pos = len(stream[0]) / SR
    for c in clips:
        timeline.append((pos, pos + len(c) / SR))
        stream += [c, gap]
        pos += (len(c) + len(gap)) / SR
    audio = np.concatenate(stream)
    chunk = SR // 10  # 100 ms
    async with websockets.connect(url, max_size=None, open_timeout=30) as ws:
        t0 = time.monotonic()

        async def reader():
            try:
                async for msg in ws:
                    m = json.loads(msg)
                    kind = m.get("message_type") or m.get("type")
                    if kind in ("committed_transcript", "committed_transcript_with_timestamps"):
                        commits.append((time.monotonic() - t0, (m.get("text") or "").strip()))
                    elif kind and "error" in kind:
                        commits.append((time.monotonic() - t0, f"[ERROR {m}]"))
            except websockets.ConnectionClosed:
                pass
        rd = asyncio.create_task(reader())
        for i in range(0, len(audio), chunk):
            part = audio[i:i + chunk]
            last = i + chunk >= len(audio)
            await ws.send(json.dumps({"message_type": "input_audio_chunk", "audio_base_64": base64.b64encode(to_pcm16(part)).decode(),
                                      "commit": last, "sample_rate": SR}))
            # real time: Scribe's VAD sees the same pauses as from a microphone
            await asyncio.sleep(max(0, (i + chunk) / SR - (time.monotonic() - t0)))
        await asyncio.sleep(3)
        await ws.close()
        await rd
    out = [[] for _ in clips]
    for t_s, text in commits:
        if not text:
            continue
        # a commit arrives shortly after the clip it belongs to ended (VAD pause + network)
        idx = max(0, min(len(clips) - 1, max((k for k, (s, e) in enumerate(timeline) if s <= t_s), default=0)))
        if t_s < timeline[idx][1] - 0.2 and idx > 0:
            idx -= 1  # arrived before this clip ended: it closes the previous one
        out[idx].append(text)
    return out


# ---------------- scoring ----------------
def norm(s):
    s = s.lower().replace("-", " ")
    s = re.sub(r"[^a-zåäöéü0-9 ]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def wer(ref, hyp):
    r, h = norm(ref).split(), norm(hyp).split()
    d = list(range(len(h) + 1))
    for i in range(1, len(r) + 1):
        prev, d[0] = d[0], i
        for j in range(1, len(h) + 1):
            cur = d[j]
            d[j] = min(d[j] + 1, d[j - 1] + 1, prev + (r[i - 1] != h[j - 1]))
            prev = cur
    return d[len(h)] / max(1, len(r))


def term_ok(case, hyp):
    """Was the subject word heard right? For bare terms the whole term, else the last content word of the case."""
    ref = norm(case["say"]).replace(" ", "")
    hy = norm(hyp).replace(" ", "")
    if case["kind"] in ("term", "short"):
        return ref in hy
    words = [w for w in norm(case["say"]).split() if len(w) > 3 and w not in {"skillnaden", "mellan", "varför", "efter", "behöver"}]
    return all(w in norm(hyp).split() or w in hy for w in words[-1:]) if words else True


def chain(tok, case, text, model, judge, cache):
    key = (case["id"], norm(text))
    if key in cache:
        return cache[key]
    body = {"action": "answer", "model": model, "request": {"fragment": text or "…", "mode": "tutor", "language": "sv", "persona": "tutor",
                                                         "persona_setup": case["profile"], "context": {"recent_qa": case["context"][-3:]}}}
    raw = http("POST", "/functions/v1/provlage-eval", body, tok, raw=True, timeout=90).decode("utf-8", "replace")
    answer = "".join(json.loads(m)["text"] for m in re.findall(r"^event: delta\ndata: (.*)$", raw, re.M))
    g = http("POST", "/functions/v1/provlage-eval", {"action": "grade", "judge": judge, "answer": answer,
                                                      "case": {**case, "q": case["say"]}}, tok, timeout=120)
    cost = float((g.get("usage") or {}).get("est_cost_usd") or 0)
    m = re.search(r'"est_cost_usd":([\d.e-]+)', raw)
    cost += float(m.group(1)) if m else 0
    cache[key] = (g["first_answer_suffices"], answer, cost)
    return cache[key]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pilot", action="store_true")
    ap.add_argument("--voices", type=int, default=4)
    ap.add_argument("--model", default="haiku")
    ap.add_argument("--judge", default="sonnet")
    ap.add_argument("--out", default=os.path.join(ROOT, "reports", "eval"))
    ap.add_argument("--audio-dir", default=os.path.join(ROOT, "audio-out"))
    a = ap.parse_args()
    cases = json.load(open(os.path.join(ROOT, "scripts", "audio-bank.json"), encoding="utf-8"))
    if a.pilot:
        cases = [c for c in cases if c["pilot"]]
    os.makedirs(a.audio_dir, exist_ok=True)
    toks = [signup() for _ in range(4)]
    tok = toks[0]
    voices = http("GET", "/functions/v1/voices", tok=tok)["voices"]
    fem = [v for v in voices if v["name"].split()[0].lower() in SWEDISH_FEMALE]
    male = [v for v in voices if v not in fem]
    chosen = []
    while len(chosen) < a.voices and (fem or male):
        for pool in (fem, male):
            if pool and len(chosen) < a.voices:
                chosen.append(pool.pop(0))
    print("voices:", [v["name"] for v in chosen], file=sys.stderr)
    chars = 0
    # keyterms from a study profile, like the app (D84: /study-profile terms, at most 20)
    terms_by_subject = {}
    for subj in sorted({c["subject"] for c in cases}):
        grade = next(c["grade"] for c in cases if c["subject"] == subj)
        p = http("POST", "/functions/v1/study-profile", {"text": f"jag går i {grade} och har prov i {subj.lower()}"}, toks[1], timeout=60)
        terms_by_subject[subj] = [subj] + p.get("terms", [])[:19]
    # speech: every case in every chosen voice (TTS caps: 1 500 characters per minute per user -> rotate users)
    speech = {}
    for vi, v in enumerate(chosen):
        for ci, c in enumerate(cases):
            speech[(v["name"], c["id"])] = tts(toks[(vi * len(cases) + ci) % len(toks)], c["say"], v["id"])
            chars += len(c["say"])
            time.sleep(0.3)
    babble_parts = []
    for i, line in enumerate(BABBLE_LINES):
        bv = voices[(i % max(1, len(voices)))]
        babble_parts.append(tts(toks[i % len(toks)], line, bv["id"]))
        chars += len(line)
    babble = np.concatenate(babble_parts)
    # babble: two overlapping talkers
    babble = babble + np.roll(babble, len(babble) // 3)
    conditions = {
        "tyst": lambda x, k: x,
        "prat 10 dB": lambda x, k: mix(x, babble, 10, k * 7919),
        "prat 5 dB": lambda x, k: mix(x, babble, 5, k * 7919),
        "airpods 16 kHz": lambda x, k: airpods(x, k),
    }
    clips = {}
    for cond, f in conditions.items():
        for k, (vn, cid) in enumerate(speech):
            y = f(speech[(vn, cid)], k)
            clips[(cond, vn, cid)] = y
            open(os.path.join(a.audio_dir, f"{cid}-{vn}-{cond.replace(' ', '_')}.wav"), "wb").write(wav_bytes(y))
    # Scribe realtime: one socket per voice x condition x keyterms; keyterms follow the subject of each case,
    # so the stream is split per subject group when keyterms are on (the app's keyterms are per exam)
    results = {}
    async def run_streams():
        jobs = []
        for cond in conditions:
            for v in chosen:
                for kt in (False, True):
                    if kt:
                        for subj in sorted(terms_by_subject):
                            ids = [c["id"] for c in cases if c["subject"] == subj]
                            jobs.append((cond, v["name"], kt, ids, terms_by_subject[subj]))
                    else:
                        jobs.append((cond, v["name"], kt, [c["id"] for c in cases], []))
        sem = asyncio.Semaphore(5)
        async def one(j, n):
            cond, vn, kt, ids, terms = j
            async with sem:
                for attempt in range(3):
                    try:
                        got = await scribe_stream(toks[n % len(toks)], [clips[(cond, vn, i)] for i in ids], terms)
                        break
                    except Exception as e:
                        print("scribe retry", cond, vn, kt, e, file=sys.stderr)
                        await asyncio.sleep(15)
                else:
                    got = [["[FAILED]"] for _ in ids]
                for i, texts in zip(ids, got):
                    results[(cond, vn, kt, i)] = texts
        await asyncio.gather(*(one(j, n) for n, j in enumerate(jobs)))
    asyncio.run(run_streams())
    # batch Scribe (comparison), quiet and 5 dB only, first voice of each gender
    batch = {}
    for cond in ("tyst", "prat 5 dB"):
        for v in chosen[:2]:
            for c in cases:
                r = http("POST", "/functions/v1/provlage-eval", {"action": "transcribe", "audio_base64": base64.b64encode(wav_bytes(clips[(cond, v["name"], c["id"])])).decode()},
                         toks[2], timeout=120)
                batch[(cond, v["name"], c["id"])] = r.get("text", "")
    # chain: transcript -> /answer (Provläge, profile) -> D87 grade; text baseline once per case
    cache, cost = {}, 0.0
    text_ok = {}
    for c in cases:
        ok, ans, cst = chain(toks[3], c, c["say"], a.model, a.judge, cache)
        text_ok[c["id"]] = ok
        cost += cst
    rows = []
    for (cond, vn, kt, cid), texts in results.items():
        c = next(x for x in cases if x["id"] == cid)
        hyp = " ".join(texts)
        row = {"cond": cond, "voice": vn, "keyterms": kt, "id": cid, "kind": c["kind"], "say": c["say"], "heard": hyp,
               "commits": len(texts), "wer": round(wer(c["say"], hyp), 3), "term_ok": term_ok(c, hyp),
               "clipped": len(texts) > 1, "missing": len(texts) == 0, "batch": batch.get((cond, vn, cid))}
        if kt:  # the chain is graded for the keyterm path (what the app does)
            before = len(cache)
            ok, ans, cst = chain(toks[3], c, hyp, a.model, a.judge, cache)
            cost += cst if len(cache) > before else 0
            row.update(chain_ok=ok, text_ok=text_ok[cid], answer=ans[:300])
        rows.append(row)
    # summary per condition
    def agg(rs):
        n = len(rs)
        return {"n": n, "wer": round(sum(r["wer"] for r in rs) / max(1, n), 3), "term_ok_pct": round(100 * sum(r["term_ok"] for r in rs) / max(1, n), 1),
                "clipped_pct": round(100 * sum(r["clipped"] for r in rs) / max(1, n), 1), "missing_pct": round(100 * sum(r["missing"] for r in rs) / max(1, n), 1)}
    table = []
    for cond in conditions:
        for kt in (False, True):
            rs = [r for r in rows if r["cond"] == cond and r["keyterms"] == kt]
            line = {"cond": cond, "keyterms": kt, **agg(rs)}
            if kt:
                line["chain_ok_pct"] = round(100 * sum(r["chain_ok"] for r in rs) / max(1, len(rs)), 1)
                line["text_ok_pct"] = round(100 * sum(r["text_ok"] for r in rs) / max(1, len(rs)), 1)
            table.append(line)
    bt = []
    for cond in ("tyst", "prat 5 dB"):
        rs = [r for r in rows if r["cond"] == cond and r["batch"] is not None and not r["keyterms"]]
        bt.append({"cond": cond, "n": len(rs), "batch_wer": round(sum(wer(r["say"], r["batch"]) for r in rs) / max(1, len(rs)), 3),
                   "realtime_wer": round(sum(r["wer"] for r in rs) / max(1, len(rs)), 3)})
    worst = sorted([r for r in rows if r["keyterms"]], key=lambda r: (r.get("chain_ok", 1) - r.get("text_ok", 1), -r["wer"]))[:10]
    summary = {"date": datetime.date.today().isoformat(), "cases": len(cases), "voices": [v["name"] for v in chosen], "tts_chars": chars,
               "audio_seconds": round(sum(len(x) for x in clips.values()) / SR, 1), "table": table, "batch": bt, "llm_cost_usd": round(cost, 4)}
    os.makedirs(a.out, exist_ok=True)
    base = os.path.join(a.out, f"audio-{summary['date']}{'-pilot' if a.pilot else ''}")
    json.dump({"summary": summary, "rows": rows}, open(base + ".json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    L = [f"# Audio test {summary['date']}{' (pilot)' if a.pilot else ''}", "",
         f"{len(cases)} cases × {len(chosen)} voices ({', '.join(summary['voices'])}) × 4 conditions; TTS {chars} characters; {summary['audio_seconds']} s of audio per path; LLM cost {summary['llm_cost_usd']} USD.", "",
         "| Condition | Keyterms | WER | Subject word right | Clipped (2+ commits) | Nothing heard | First answer enough (audio / text) |", "|---|---|---:|---:|---:|---:|---:|"]
    for t in table:
        L.append(f"| {t['cond']} | {'yes' if t['keyterms'] else 'no'} | {t['wer']} | {t['term_ok_pct']} % | {t['clipped_pct']} % | {t['missing_pct']} % | "
                 + (f"{t['chain_ok_pct']} % / {t['text_ok_pct']} %" if t['keyterms'] else "–") + " |")
    L += ["", "| Batch vs realtime (no keyterms) | n | batch WER | realtime WER |", "|---|---:|---:|---:|"]
    L += [f"| {b['cond']} | {b['n']} | {b['batch_wer']} | {b['realtime_wer']} |" for b in bt]
    L += ["", "## The 10 worst (keyterms on)", ""]
    for r in worst:
        L.append(f"- **{r['id']}** {r['cond']}, {r['voice']}: said \"{r['say']}\" → heard \"{r['heard']}\" (WER {r['wer']}, commits {r['commits']}); first answer enough {r.get('chain_ok')} (text {r.get('text_ok')})")
    open(base + ".md", "w", encoding="utf-8").write("\n".join(L) + "\n")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    sys.exit(main())
