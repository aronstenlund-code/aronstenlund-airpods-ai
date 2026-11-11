#!/usr/bin/env python3
"""K37 (D126) live: "Mina svar" against the deployed /answer. Every utterance in backend/testdata/k37-saved-answers.json
is sent in Provläge (mode tutor) with the 15 saved answers; a saved answer comes back as done.saved_answer. The stream
is cut after the first delta (a normal answer is not needed, it only costs). Then three /my-answers calls (suggest,
proofread, compress). Raw data -> reports/eval/<stamp>-k37-saved-live.json.
  python3 scripts/k37-saved-live.py"""
import datetime, json, pathlib, time, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
U = "https://xjczbzfkmbjdebwlccki.supabase.co"
K = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
BANK = json.loads((ROOT / "backend/testdata/k37-saved-answers.json").read_text(encoding="utf-8"))


def token() -> str:
    r = urllib.request.Request(f"{U}/auth/v1/signup", data=b"{}", headers={"apikey": K, "content-type": "application/json"})
    return json.loads(urllib.request.urlopen(r, timeout=30).read())["access_token"]


def answer(tok: str, fragment: str) -> dict:
    body = {"fragment": fragment, "mode": "tutor", "language": "sv", "persona": "tutor", "saved_answers": BANK["saved"],
            "personaSetup": "Ämne: Biologi och historia. Årskurs 8.", "context": {"transcript": fragment, "recent_qa": []}}
    req = urllib.request.Request(f"{U}/functions/v1/answer", data=json.dumps(body).encode(), headers={
        "apikey": K, "authorization": "Bearer " + tok, "content-type": "application/json"})
    t0 = time.time()
    out = {"saved": None, "via": None, "first": "", "ms": None, "status": None}
    with urllib.request.urlopen(req, timeout=60) as r:
        out["status"] = r.status
        ev, deltas = None, 0
        for raw in r:
            line = raw.decode("utf-8").rstrip("\n")
            if line.startswith("event: "):
                ev = line[7:]
            elif line.startswith("data: "):
                d = json.loads(line[6:])
                if ev == "delta":
                    deltas += 1
                    if deltas == 1:
                        out["first"] = d.get("text", "")[:160]
                        out["ms"] = round((time.time() - t0) * 1000)
                    else:
                        break  # a saved answer is one delta then done: this is a normal answer, stop paying for it
                elif ev == "done":
                    sa = d.get("saved_answer")
                    out["saved"] = sa and sa["id"]
                    out["via"] = sa and sa["via"]
                    break
    return out


def my(tok: str, body: dict) -> dict:
    req = urllib.request.Request(f"{U}/functions/v1/my-answers", data=json.dumps(body).encode(), headers={
        "apikey": K, "authorization": "Bearer " + tok, "content-type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=90) as r:
        j = json.loads(r.read())
    j["ms"] = round((time.time() - t0) * 1000)
    return j


def main():
    rows, tok, n = [], token(), 0
    for h in BANK["heard"]:
        if n and n % 30 == 0:
            tok = token()  # new sessions are capped per hour
        n += 1
        try:
            r = answer(tok, h["t"])
        except Exception as e:  # noqa: BLE001
            r = {"error": str(e)[:200]}
        ok = r.get("saved") == h["expect"]
        rows.append({**h, **r, "ok": ok})
        print(("OK  " if ok else "FAIL"), h["kind"], repr(h["t"]), "->", r.get("saved"), r.get("via"), r.get("ms"), flush=True)
        time.sleep(1.2)
    pos = [r for r in rows if r["expect"]]
    neg = [r for r in rows if not r["expect"]]
    summary = {
        "hits": f"{sum(r['ok'] for r in pos)}/{len(pos)}",
        "false_hits": f"{sum(1 for r in neg if r.get('saved'))}/{len(neg)}",
        "wrong_id": sum(1 for r in pos if r.get("saved") and r["saved"] != r["expect"]),
        "via_code": sum(1 for r in rows if r.get("via") == "code"),
        "via_check": sum(1 for r in rows if r.get("via") == "check"),
        "ms_saved_median": sorted(r["ms"] for r in rows if r.get("saved") and r.get("ms"))[len([r for r in rows if r.get("saved") and r.get("ms")]) // 2] if any(r.get("saved") for r in rows) else None,
    }
    tok = token()
    extra = {
        "suggest": my(tok, {"action": "suggest", "q": "vad är skilnaden mellan fotosyntes och cellandning", "subject": "Biologi", "grade": "Åk 8"}),
        "proofread": my(tok, {"action": "proofread", "q": "när började förta världskriget", "a": "Förta världskriget började 1914 när skotten i sarajevo avlossades."}),
        "compress": my(tok, {"action": "compress", "subject": "Biologi", "transcript": (
            "okej så alla lyssna nu, eh, cellandning, det är alltså det som händer i varje cell i kroppen, i mitokondrierna. "
            "Cellen tar glukos, alltså socker, och syre, och bryter ner det, och då frigörs energi som cellen kan använda. "
            "Och det som blir över är koldioxid och vatten, som vi andas ut. Ja, Elsa, du kan gå på toa. "
            "Så man kan säga att det är fotosyntesen baklänges. Det här kommer på provet på fredag.")}),
    }
    print(json.dumps(summary, ensure_ascii=False))
    for k, v in extra.items():
        print(k, json.dumps(v, ensure_ascii=False)[:600])
    stamp = datetime.datetime.now(__import__("zoneinfo").ZoneInfo("Europe/Stockholm")).strftime("%Y-%m-%d-%H%M")
    out = ROOT / "reports/eval" / f"{stamp}-k37-saved-live.json"
    out.write_text(json.dumps({"summary": summary, "rows": rows, "my_answers": extra}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(out)


if __name__ == "__main__":
    main()
