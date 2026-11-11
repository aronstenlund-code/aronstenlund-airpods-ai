#!/usr/bin/env python3
"""Kevin, stående omgång 5 (Toby T5b c1): in Auto a question with its own (misheard) subject words must be repaired,
not replaced by the previous answer's topic. Each case has a recent_qa about another topic. Prints the reconstructed
question and the start of the answer. Raw data -> reports/eval/<stamp>-k-standing5-recon-<tag>.json.
  TAG=before python3 -X utf8 -I scripts/k-standing5-recon-live.py"""
import datetime, json, os, pathlib, time, urllib.request, zoneinfo
U = "https://xjczbzfkmbjdebwlccki.supabase.co"; K = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
CASES = [  # (fragment, recent q, recent a, words the reconstruction must contain (any), words it must not contain)
    ("Vilka är de största? Bargern i världen.", "Vilka är planeterna i solsystemet?", "Planeterna i solsystemet är Merkurius, Venus, Jorden, Mars, Jupiter, Saturnus, Uranus och Neptunus.", ["berg"], ["planet"]),
    ("Hur långa är de? Floderna i Afrika.", "Vilka är de största öknarna?", "De största öknarna är Antarktis, Arktis och Sahara.", ["flod", "nil"], ["öken", "öknar"]),
    ("Vilken är den äldsta? Stan i Sverige.", "Vilka är de största sjöarna i Sverige?", "De största sjöarna är Vänern, Vättern och Mälaren.", ["stad", "stan"], ["sjö"]),
    ("Hur många finns det? Benen i kroppen.", "Hur många planeter finns det?", "Det finns åtta planeter i solsystemet.", ["ben", "skelett"], ["planet"]),
    ("Vilka är de största?", "Vilka är de största öknarna?", "De största öknarna är Antarktis, Arktis och Sahara.", ["ökn", "öken"], []),  # a real follow-up: fill in
    ("Och den minsta då?", "Vilken är den största planeten?", "Jupiter är den största planeten.", ["planet", "merkurius"], []),
]


def post(path, body, tok=None):
    h = {"apikey": K, "content-type": "application/json", **({"authorization": "Bearer " + tok} if tok else {})}
    with urllib.request.urlopen(urllib.request.Request(U + path, data=json.dumps(body).encode(), headers=h), timeout=60) as r:
        return r.read().decode()


tok = json.loads(post("/auth/v1/signup", {}))["access_token"]
rows, ok = [], 0
for frag, q, a, must, mustnot in CASES:
    t = post("/functions/v1/answer", {"fragment": frag, "mode": "auto", "language": "sv",
                                      "context": {"transcript": frag, "recent_qa": [{"q": q, "a": a}]}}, tok)
    meta, said = {}, ""
    for f in t.split("\n\n"):
        if f.startswith("event: meta"): meta = json.loads(f.split("data: ", 1)[1])
        if f.startswith("event: delta"): said += json.loads(f.split("data: ", 1)[1]).get("text", "")
    rq = (meta.get("reconstructed_question") or "").lower()
    hay = rq + " " + said.lower()
    good = any(m in hay for m in must) and not any(n in rq for n in mustnot)
    ok += good
    rows.append({"fragment": frag, "recon": meta.get("reconstructed_question"), "said": said, "ok": good})
    print("OK " if good else "BAD", repr(frag), "->", meta.get("reconstructed_question"), "|", said[:90], flush=True)
    time.sleep(1)
print(f"{ok}/{len(CASES)}")
stamp = datetime.datetime.now(zoneinfo.ZoneInfo("Europe/Stockholm")).strftime("%Y-%m-%d-%H%M")
out = pathlib.Path(__file__).resolve().parents[1] / "reports" / "eval" / f"{stamp}-k-standing5-recon-{os.environ.get('TAG', 'run')}.json"
out.write_text(json.dumps({"ok": ok, "n": len(CASES), "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
print(out)
