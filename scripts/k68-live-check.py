"""K68 live check (Kevin, 2026-11-14): Toby's T25 w43 and similar transcripts in Standardläge (mode auto), 5 times each.
Test account and test header (D180: /answer never calls ElevenLabs; the header is there anyway)."""
import json, os, sys, time, urllib.request
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
CASES = ["Hur länge har hallar funnits?", "Vad betyder inflation?", "Varför är himlen blå?", "hur länge har han funnits", "Jag tror det regnar i morgon."]

def ask(tok, frag):
    body = {"fragment": frag, "mode": "auto", "language": "sv", "persona": "tutor", "context": {"recent_qa": []}}
    req = urllib.request.Request(qa.URL + "/functions/v1/answer", data=json.dumps(body).encode(), method="POST", headers=qa.headers(tok))
    out, ev, done = "", None, None
    with urllib.request.urlopen(req, timeout=90) as r:
        for line in r:
            line = line.decode("utf8", "replace").rstrip("\r\n")
            if line.startswith("event: "): ev = line[7:]
            elif line.startswith("data: "):
                try: d = json.loads(line[6:])
                except Exception: continue
                if ev == "delta" and d.get("text"): out += d["text"]
                if ev == "done": done = d
    return out, (done or {}).get("answered"), (done or {}).get("usage", {}).get("model")

tok = qa.signup()[0]
res = {}
for c in CASES:
    res[c] = []
    for _ in range(5 if c == CASES[0] else 2):
        a, answered, model = ask(tok, c)
        res[c].append({"answered": answered, "model": model, "answer": a[:90]})
        time.sleep(2)
    print(c, [x["answered"] for x in res[c]], res[c][0]["answer"][:70])
