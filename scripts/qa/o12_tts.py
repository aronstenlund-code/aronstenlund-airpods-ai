#!/usr/bin/env python3
"""Oscar QA, O12: compare the TTS models (and voices) through the live /tts, like the app (pcm_24000, sv).
  O6_LIB=<folder with scipy+websockets> python -I scripts/qa/o12_tts.py --audio-dir <scratch> [--voices-only]
For every text x model: time to first byte and total (p50/p90), x-tts-model header, duration; clarity = Scribe v2
Realtime (the app's VAD values, no keyterms) word and character error against the text; artefacts = pauses over
400 ms beyond the sentence ends, a cut ending (energy in the last 30 ms), inserted/repeated words in Scribe's text.
Audio stays in --audio-dir (scratch, never git). Budget: <= 20 000 weighted ElevenLabs characters (multilingual x2).
Writes reports/qa/data/<stamp>-o12.json."""
import argparse, asyncio, datetime as dt, importlib.util, json, os, pathlib, random, re, sys, time, urllib.error, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o6", ROOT / "scripts/qa/o6_audio.py")
O6 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(O6)
np, E = O6.np, O6.E
from scipy.signal import resample_poly

MODELS = ["eleven_v4_turbo", "eleven_flash_v2_5", "eleven_multilingual_v2"]
WEIGHT = {"eleven_v4_turbo": 1, "eleven_flash_v2_5": 1, "eleven_multilingual_v2": 2}
VOICES = {"Adam": "x0u3EW21dbrORJzOq1m9", "Saga": "tPrL2xYfkQnwJhHMMdRM", "Max": "JhAQDwsLijg4qbxGNQGH"}
CHAR_CAP = 20000

# 20 real Provläge answers (reports/eval/provlage-2026-11-09-sonnet-k2-full.json), first one or two sentences, read by
# hand; numbers are already words (D46). Kinds: fakta, tal/årtal, namn, engelska ord, formel, en lång förklaring.
TEXTS = [
    ("pl-001", "fakta", "Fotosyntesen är växternas sätt att göra sin egen mat, socker, av koldioxid och vatten med hjälp av ljus. Det sker i bladens gröna delar, där ämnet klorofyll fångar upp solljuset."),
    ("pl-009", "fakta", "För att göra fotosyntes behöver växten tre saker: ljus, vatten och koldioxid. Ljuset fångas upp av klorofyll, det gröna ämnet i bladens gröna delar."),
    ("pl-017", "fakta", "Proteinsyntes är processen där cellen bygger proteiner utifrån informationen i generna. Den sker i två steg."),
    ("pl-045", "formel", "Ohms lag beskriver hur spänning, ström och resistans hänger ihop i en krets. Spänningen U är lika med resistansen R gånger strömmen I."),
    ("pl-049", "formel", "Rörelseenergi är den energi ett föremål har på grund av att det rör sig. Den beräknas som E k är lika med en halv gånger m gånger v i kvadrat, där m är massan i kilogram och v är hastigheten i meter per sekund."),
    ("pl-053", "fakta", "Elektrisk resistans är ett mått på hur mycket en komponent eller en ledning motverkar att elektrisk ström går igenom. Den mäts i ohm."),
    ("pl-061", "årtal", "Franska revolutionen var en omvälvning i Frankrike som började sjuttonhundraåttionio och som ändade kungens envälde och ståndssamhället."),
    ("pl-065", "namn", "Upplysningen var en idéströmning på sjuttonhundratalet som hävdade att förnuft, vetenskap och fria studier skulle ersätta vidskepelse, tradition och kyrkans och kungens auktoritet. Tänkare som Voltaire, Montesquieu och Rousseau kritiserade envälde och religiös intolerans."),
    ("pl-069", "årtal", "Renässansen var en kulturepok i Europa från ungefär trettonhundratalet till femtonhundratalet som började i Italien. Ordet betyder återfödelse, eftersom man ville väcka antikens ideal till liv igen."),
    ("pl-081", "fakta", "Högre styrränta gör det dyrare att låna pengar, eftersom bankerna höjer sina utlåningsräntor. Hushåll och företag lånar och konsumerar då mindre, så efterfrågan i ekonomin minskar."),
    ("pl-089", "fakta", "Plattektonik är teorin om att jordskorpan är uppdelad i stora plattor som sakta rör sig ovanpå den heta, sega manteln. Plattorna flyttar sig bara några centimeter om året, ungefär lika fort som dina naglar växer."),
    ("pl-113", "engelska", "Oregelbundna verb är verb som inte följer den vanliga regeln för dåtid, att man lägger till \"ed\". I stället ändras de på ett eget sätt som man måste lära sig utantill."),
    ("pl-117", "engelska", "Third conditional är if plus past perfect och would have plus particip, för något som skulle ha hänt men aldrig hände. Det handlar alltså om det förflutna och går inte att ändra längre."),
    ("pl-121", "tal", "Procent betyder hundradel, alltså ett tal delat med hundra. Tjugofem procent är därför tjugofem hundradelar, alltså noll komma två fem eller en fjärdedel."),
    ("pl-133", "tal", "Lös x i kvadrat plus sex x minus sexton är lika med noll. Här är p lika med sex och q lika med minus sexton."),
    ("pl-153", "årtal", "Kalla kriget var en spänning mellan USA och Sovjetunionen från nittonhundrafyrtiofem till nittonhundranittioett, där de aldrig stred direkt mot varandra. USA stod för demokrati och kapitalism, Sovjetunionen för kommunism och enpartistat."),
    ("pl-161", "årtal", "Medeltiden är tiden mellan antiken och nya tiden, ungefär från år femhundra till femtonhundra. I Sverige brukar man räkna den från omkring tusen femtio till femtonhundratjugo."),
    ("pl-177", "engelska", "Whose är ett relativt pronomen som visar ägande, alltså vars på svenska."),
    ("pl-189", "tal", "Derivatan av tre x i kvadrat plus två x minus fem är sex x plus två. Man deriverar term för term med potensregeln: x upphöjt till n blir n gånger x upphöjt till n minus ett."),
    ("pl-077", "lång", "Mänskliga rättigheter är de rättigheter som alla människor har, bara för att de är människor, oavsett var de bor, vad de tror på eller vilket kön de har. De skrevs ner i FN:s allmänna förklaring om de mänskliga rättigheterna nittonhundrafyrtioåtta, efter andra världskrigets fasor. Rättigheterna gäller alla lika, de kan inte tas ifrån någon och de hör ihop, så en stat får inte välja bort några. Exempel är rätten till liv, yttrandefrihet, att inte bli torterad, rätt till utbildning och att inte bli diskriminerad."),
]
VOICE_TEXTS = ["pl-001", "pl-045", "pl-061", "pl-065", "pl-113", "pl-121", "pl-153", "pl-161", "pl-189", "pl-081"]

# ---------------------------------------------------------------- text normalisation for error rates
ONES = ["noll", "ett", "två", "tre", "fyra", "fem", "sex", "sju", "åtta", "nio", "tio", "elva", "tolv", "tretton", "fjorton", "femton",
        "sexton", "sjutton", "arton", "nitton"]
TENS = {2: "tjugo", 3: "trettio", 4: "fyrtio", 5: "femtio", 6: "sextio", 7: "sjuttio", 8: "åttio", 9: "nittio"}


def sv(n):
    if n < 20:
        return ONES[n]
    if n < 100:
        return TENS[n // 10] + (ONES[n % 10] if n % 10 else "")
    if n < 1000:
        return ("" if n // 100 == 1 else ONES[n // 100]) + "hundra" + (sv(n % 100) if n % 100 else "")
    if 1100 <= n < 2000:  # years: "sjuttonhundraåttionio"
        return ONES[n // 100] + "hundra" + (sv(n % 100) if n % 100 else "")
    if n < 1_000_000:
        return ("" if n // 1000 == 1 else sv(n // 1000)) + "tusen" + (sv(n % 1000) if n % 1000 else "")
    return str(n)


def norm(s):
    s = s.lower().replace("en halv", "enhalv")
    s = re.sub(r"(\d+),(\d+)", lambda m: sv(int(m.group(1))) + " komma " + " ".join(ONES[int(c)] for c in m.group(2)), s)
    s = re.sub(r"\d+", lambda m: sv(int(m.group(0))), s)
    s = re.sub(r"[^\wåäöéü ]+", " ", s)
    s = s.replace("en ", "ett ") if False else s
    return s.split()


def lev(a, b):
    d = list(range(len(b) + 1))
    ops = None
    for i in range(1, len(a) + 1):
        prev, d[0] = d[0], i
        for j in range(1, len(b) + 1):
            cur = d[j]
            d[j] = min(d[j] + 1, d[j - 1] + 1, prev + (a[i - 1] != b[j - 1]))
            prev = cur
    return d[len(b)]


def rates(ref, hyp):
    r, h = norm(ref), norm(hyp)
    wer = lev(r, h) / max(1, len(r))
    rc, hc = "".join(r), "".join(h)  # compound-insensitive: "tusen femtio" == "tusenfemtio"
    cer = lev(list(rc), list(hc)) / max(1, len(rc))
    reps = sum(1 for i in range(1, len(h)) if h[i] == h[i - 1] and not (i < len(r) and r.count(h[i]) > 1))
    return round(wer, 3), round(cer, 3), reps, len(h) - len(r)


# ---------------------------------------------------------------- audio analysis (24 kHz int16 pcm)
def analyse(x, text, sr=24000):
    fr = int(sr * 0.02)
    n = len(x) // fr
    if n < 5:
        return {"dur_s": len(x) / sr}
    e = np.sqrt(np.mean(x[: n * fr].reshape(n, fr) ** 2, axis=1)) + 1e-9
    db = 20 * np.log10(e / e.max())
    voiced = np.where(db > -35)[0]
    first, last = voiced[0], voiced[-1]
    pauses, run = [], 0
    for k in range(first, last + 1):
        if db[k] <= -35:
            run += 1
        else:
            if run * 20 >= 400:
                pauses.append(run * 20)
            run = 0
    ends = len(re.findall(r"[.!?:](?=\s)", text.strip()))  # sentence ends inside the text (the last one is the end)
    tail_db = float(np.max(db[-2:]))  # last 40 ms: still loud = cut off
    return {"dur_s": round(len(x) / sr, 2), "pauses_400": pauses, "pauses_over_ends": max(0, len(pauses) - ends), "max_pause_ms": max(pauses or [0]),
            "trail_ms": int((n - 1 - last) * 20), "lead_ms": int(first * 20), "tail_db": round(tail_db, 1), "cut_end": tail_db > -25}


def tts(tok, text, model, voice):
    body = {"text": text, "language": "sv", "output_format": "pcm_24000", "model": model, "voice_id": voice}
    req = urllib.request.Request(E.URL + "/functions/v1/tts", method="POST", data=json.dumps(body).encode(),
                                 headers={"apikey": E.KEY, "content-type": "application/json", "Authorization": "Bearer " + tok})
    t0 = time.perf_counter()
    try:
        r = urllib.request.urlopen(req, timeout=60)
    except urllib.error.HTTPError as e:
        return {"status": e.code, "err": e.read()[:300].decode("utf-8", "replace")}, None
    first = r.read(1)
    fb = (time.perf_counter() - t0) * 1000
    data = first + r.read()
    tot = (time.perf_counter() - t0) * 1000
    h = {k.lower(): v for k, v in r.headers.items()}
    x = np.frombuffer(data[: len(data) // 2 * 2], dtype="<i2").astype(np.float32) / 32768.0
    return {"status": r.status, "first_byte_ms": round(fb), "total_ms": round(tot), "x_tts_model": h.get("x-tts-model"),
            "bytes": len(data)}, x


def pct(v, p):
    v = sorted(v)
    return v[min(len(v) - 1, int(round(p * (len(v) - 1))))] if v else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audio-dir", required=True)
    ap.add_argument("--voices-only", action="store_true")
    ap.add_argument("--voice-model", default="eleven_v4_turbo")
    a = ap.parse_args()
    os.makedirs(a.audio_dir, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
    texts = {tid: (kind, t) for tid, kind, t in TEXTS}
    jobs = []
    if not a.voices_only:
        jobs += [(tid, m, "Adam") for tid in texts for m in MODELS]
    jobs += [(tid, a.voice_model, v) for tid in VOICE_TEXTS for v in ("Saga", "Max")]
    random.seed(12)
    random.shuffle(jobs)  # interleave models so network drift hits all of them alike
    need = sum(len(texts[t][1]) * WEIGHT[m] for t, m, v in jobs)
    print("weighted chars needed", need, flush=True)
    if need > CHAR_CAP:
        sys.exit("over the character cap")
    tok = E.signup()
    rows, chars = [], 0
    for i, (tid, m, v) in enumerate(jobs):
        kind, text = texts[tid]
        meta, x = tts(tok, text, m, VOICES[v])
        chars += len(text) * WEIGHT[m]
        row = {"id": tid, "kind": kind, "model": m, "voice": v, **meta}
        if x is not None and len(x):
            np.save(os.path.join(a.audio_dir, f"{tid}-{m}-{v}.npy"), x)
            row.update(analyse(x, text))
            x16 = resample_poly(x, 2, 3).astype(np.float32)
            pad = np.zeros(int(16000 * 0.5), dtype=np.float32)
            commits, partials, errors = asyncio.run(O6.scribe(tok, np.concatenate([pad, x16, pad, pad]), []))
            hyp = " ".join(c[1] for c in commits if c[1])
            row["scribe"] = hyp
            row["scribe_errors"] = errors[:2]
            row["wer"], row["cer"], row["repeats"], row["len_diff"] = rates(text, hyp)
        rows.append(row)
        print(i, tid, m[7:], v, row.get("status"), row.get("first_byte_ms"), row.get("x_tts_model"), "wer", row.get("wer"), "cer", row.get("cer"),
              "pauses+", row.get("pauses_over_ends"), "cut", row.get("cut_end"), "|", (row.get("scribe") or row.get("err") or "")[:90], flush=True)
        time.sleep(1.0)
    summ = {}
    for key in sorted({(r["model"], r["voice"]) for r in rows}):
        rs = [r for r in rows if (r["model"], r["voice"]) == key and r.get("status") == 200]
        fb = [r["first_byte_ms"] for r in rs]
        summ[f"{key[0]}/{key[1]}"] = {
            "n": len(rs), "first_byte_p50": pct(fb, .5), "first_byte_p90": pct(fb, .9), "total_p50": pct([r["total_ms"] for r in rs], .5),
            "wer_mean": round(sum(r.get("wer", 1) for r in rs) / max(1, len(rs)), 3), "cer_mean": round(sum(r.get("cer", 1) for r in rs) / max(1, len(rs)), 3),
            "pauses_over_ends": sum(r.get("pauses_over_ends", 0) for r in rs), "cut_end": sum(bool(r.get("cut_end")) for r in rs),
            "repeats": sum(r.get("repeats", 0) for r in rs), "fallback_header": sum(r.get("x_tts_model") not in (None, key[0]) for r in rs),
            "sec_per_char": round(sum(r.get("dur_s", 0) for r in rs) / max(1, sum(len(texts[r["id"]][1]) for r in rs)), 4)}
    out = ROOT / "reports/qa/data" / f"{stamp}-o12{'-voices' if a.voices_only else ''}.json"
    out.write_text(json.dumps({"stamp": stamp, "weighted_chars": chars, "scribe_audio_s": round(O6.spent["rt_audio_s"], 1), "summary": summ, "rows": rows},
                              ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(summ, ensure_ascii=False, indent=1))
    print("chars", chars, "->", out)


if __name__ == "__main__":
    main()
