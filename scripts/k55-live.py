#!/usr/bin/env python3
"""K55 live measurement of R1 and the real cost, the way the app does it (one invented exam from Oscar's bank, 10
photos + PDF text): Skapa frågor (drill answers:false) -> answers (drill_answers) -> Starta prov (/drill save) ->
poll /drill status until the first question's audio is playable and until all audio is done.
Prints the time of each step, the Claude cost and what ElevenLabs actually charged (credits, from character-cost)
next to the characters. About 12 000 ElevenLabs characters for 20 questions (voice A).
  python -X utf8 scripts/k55-live.py [--id bio-ak8-fotosyntes] [--voice A]"""
import argparse, base64, datetime, json, pathlib, sys, time, urllib.error, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design


def token():
    req = urllib.request.Request(URL + "/auth/v1/signup", data=b"{}", method="POST", headers={"apikey": KEY, "content-type": "application/json"})
    return json.load(urllib.request.urlopen(req))["access_token"]


def call(fn, body, tok, timeout=180):
    req = urllib.request.Request(f"{URL}/functions/v1/{fn}", data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", default="bio-ak8-fotosyntes")
    ap.add_argument("--voice", default="A")
    ap.add_argument("--questions", type=int, default=15, help="15 = the monthly limit (D155); 20 would be refused with 402")
    a = ap.parse_args()
    e = next(x for x in json.load(open(ROOT / "scripts/qa/repetition_bank/exams.json", encoding="utf-8")) if x["id"] == a.id)
    folder = ROOT / "scripts/qa/repetition_bank/files" / a.id
    pages = [{"media_type": "image/jpeg", "data": base64.b64encode(p.read_bytes()).decode()} for p in sorted(folder.glob("p*.jpg"))]
    pdf = "\n\n".join(e["material"]["pages"][i] for f in e["material"]["formats"] if f["format"] == "pdf" for i in f["pages"])
    tok = token()
    out = {"exam": a.id, "photos": len(pages), "voice": a.voice}
    t0 = time.time()
    st, q = call("exam", {"action": "drill", "pages": pages, "text": pdf, "answers": False, "questions": a.questions}, tok)
    out["questions_s"] = round(time.time() - t0, 1)
    st, ans = call("exam", {"action": "drill_answers", "items": q["items"], "notes": q["notes"], "subject": q["summary"]["subject"], "grade": q["summary"]["grade"]}, tok)
    out["answers_s"] = round(time.time() - t0, 1)
    out["claude_usd"] = round((q["usage"]["est_cost_usd"] or 0) + (ans["usage"]["est_cost_usd"] or 0), 4)
    items = [{"question": i["question"], "short": i["short"], "long": i["long"]} for i in ans["items"] if i.get("short")]
    # Starta prov
    t1 = time.time()
    st, d = call("drill", {"action": "save", "drill": {"title": f"K55 mätning ({a.id}, påhittat)", "voice_model": a.voice}, "items": items}, tok)
    out["new_chars"] = d.get("new_chars")
    if "drill" not in d:
        print("save refused", st, d)
        return 1
    did = d["drill"]["id"]
    first = None
    while time.time() - t1 < 600:
        st, v = call("drill", {"action": "status", "id": did}, tok)
        i0 = v["items"][0]["audio"]
        if first is None and i0["question"]["status"] == "done":
            first = round(time.time() - t1, 1)
        if v["audio"]["done"] + v["audio"]["failed"] >= v["audio"]["total"]:
            break
        time.sleep(1.5)
    out["first_question_audio_s_after_start"] = first
    out["all_audio_s_after_start"] = round(time.time() - t1, 1)
    out["audio"] = {k: v["audio"].get(k) for k in ("done", "total", "failed", "chars", "credits", "credits_chars", "est_usd", "bytes", "model")}
    if v["audio"].get("credits") and v["audio"].get("credits_chars"):
        out["audio"]["credits_per_char"] = round(v["audio"]["credits"] / v["audio"]["credits_chars"], 3)
    out["questions"] = len(items)
    call("drill", {"action": "delete", "id": did}, tok)
    p = ROOT / "reports/eval" / f"k55-live-{datetime.date.today().isoformat()}.json"
    p.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(out, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
