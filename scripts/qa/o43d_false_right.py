#!/usr/bin/env python3
"""Oscar QA, O43d: can A62 + K40 give a FALSE "Rätt"? In classroom babble Scribe sometimes reads the keyterm list aloud
in order (O43 efter: 5/40), and with A62 the right answer is FIRST in that list. Two conditions on the 20 geography
questions, with the A62 keyterms (answer + alternatives first) and quiz_key, like the app after A62:
  silence = the student says nothing, only babble;   wrong = the student says a WRONG answer (another case's cached
  clip, e.g. "Vänern" to the Nile question; 0 new ElevenLabs characters).
Pass = Lumen never says "Rätt" (or "Rätt i så fall"). Optional --no-a62 for the same without the answer in keyterms.
  O6_LIB=<scipy+websockets> python -I scripts/qa/o43d_false_right.py [--cond silence,wrong] [--babble-only-wrong]
  -> reports/qa/data/<stamp>-o43d.json"""
import argparse, asyncio, datetime as dt, importlib.util, json, pathlib, sys, time

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.argv, _argv = sys.argv[:1], sys.argv
sp = importlib.util.spec_from_file_location("o43", ROOT / "scripts/qa/o43_short_answers.py")
M = importlib.util.module_from_spec(sp)
sp.loader.exec_module(M)
sys.argv = _argv
np = M.np
# wrong answer = the cached clip of another geography case (a real place, plausible but wrong)
WRONG = {"g01": "g14", "g02": "g09", "g03": "g05", "g04": "g06", "g05": "g04", "g06": "g05", "g07": "g10", "g08": "g07",
         "g09": "g02", "g10": "g01", "g11": "g14", "g12": "g11", "g13": "g17", "g14": "g11", "g15": "g12", "g16": "g17",
         "g17": "g16", "g18": "g15", "g19": "g13", "g20": "g19"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cond", default="silence,wrong")
    ap.add_argument("--noise", default="babble", help="babble or quiet (for wrong)")
    ap.add_argument("--no-a62", action="store_true")
    a = ap.parse_args()
    stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M%S")
    out = M.ROOT / "reports/qa/data" / f"{stamp}-o43d{'-noa62' if a.no_a62 else ''}-{a.noise}.json"
    tok, n, rows, chars, secs = M.O.signup(), 0, [], [0], 0.0
    t, _ = M.exam_terms(tok, "geo")
    e = M.EXAMS["geo"]
    base = M.sanitize([e["subject"]] + [p.strip() for part in M.re.split(r"[,;\n]", e["topics"]) for p in part.split(" och ") if p.strip()] + t)
    cases = [c for c in M.CASES if c[1] == "geo"]
    byid = {c[0]: c for c in M.CASES}
    for k, (cid, exam, q, right, say, acc) in enumerate(cases):
        for cond in a.cond.split(","):
            if n >= 30:
                tok, n = M.O.signup(), 0
            if cond == "silence":
                speech = np.zeros(int(16000 * 0.8), dtype=np.float32)
                # babble at the level it has under a normal answer (SNR 10 dB of a typical clip)
                ref = M.tts(tok, cid, say, chars)
                pad = np.zeros(len(ref) + 4800 + 8000, dtype=np.float32)
                b = M.babble_track()
                off = (k * 7919) % (len(b) - len(pad) - 1)
                audio = (b[off:off + len(pad)] * (np.sqrt(np.mean(ref ** 2)) / (10 ** (10 / 20)))).astype(np.float32)
                said = "(inget, bara sorl)"
            else:
                wid = WRONG[cid]
                wc = byid[wid]
                speech = M.tts(tok, wid, wc[4], chars)
                audio = M.with_babble(speech, k, 10.0) if a.noise == "babble" else np.concatenate(
                    [np.zeros(1600, dtype=np.float32), speech, np.zeros(8000, dtype=np.float32)])
                said = wc[3]
            kt = base if a.no_a62 else M.sanitize([right] + M.ALTS[cid] + base)
            r = asyncio.run(M.K.probe(tok, audio, kt))
            secs += len(audio) / 16000
            heard = " ".join(c or "" for c in r["commits"]).strip()
            qk = {"answer": right, "alternatives": M.ALTS[cid]}
            res = M.answer(tok, exam, q, heard, None if a.no_a62 else qk) if heard else {"status": None, "said": "", "note": "nothing heard"}
            n += 1
            v = M.verdict(res.get("said", ""))
            rl = res.get("said", "").lower()
            false_right = (v == "right" or rl.startswith(right.lower() + " är rätt") or "stämmer" in rl[:40]) and not rl.startswith("inte riktigt")
            rows.append({"id": cid, "cond": cond, "noise": a.noise, "right": right, "student_said": said, "heard": heard, "reply": res.get("said", ""),
                         "verdict": v, "false_right": false_right, "quiz_sound": ((res.get("done") or {}).get("quiz_sound")), "keyterms_first": kt[:5]})
            print(cid, cond, "FALSE RIGHT" if false_right else "ok", "| said:", said, "| heard:", heard[:60], "| reply:", res.get("said", "")[:70].replace("\n", " "), flush=True)
            out.write_text(json.dumps({"stamp": stamp, "a62": not a.no_a62, "rows": rows, "elevenlabs_chars_new": chars[0], "scribe_seconds": round(secs, 1)},
                                      ensure_ascii=False, indent=1), encoding="utf-8")
            time.sleep(10.5)
    s = {c: {"n": sum(r["cond"] == c for r in rows), "false_right": sum(r["false_right"] for r in rows if r["cond"] == c),
             "heard_nothing": sum(not r["heard"] for r in rows if r["cond"] == c)} for c in a.cond.split(",")}
    d = json.loads(out.read_text(encoding="utf-8")); d["summary"] = s
    out.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(s), "ElevenLabs", chars[0], "Scribe s", round(secs, 1), "->", out)


if __name__ == "__main__":
    main()
