"""K104 (D233, Kevin moln 2026-11-18): Haiku against Sonnet on searched answers.
Every question once per model, picked with the test header `x-earmind-test: kevin-k104 model-haiku|model-sonnet`
(the server changes only the call that has web tools). Right or wrong against a key, time to the first word and to
`searching`, the model and the number of searches from `done`. Test accounts (qa_testaccount), 0 ElevenLabs
(/answer is text). One round only: the web cap is shared by everyone (150 searched answers a day).
Run in Actions (kevin-live.yml): python -X utf8 scripts/k104-models.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, re, statistics, time, urllib.error, urllib.request  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
URL, KEY = T.URL, T.KEY

# (id, question, any of these in the spoken answer = right); Oscar's searched cases first, then my own with a fixed key
CASES = [
    ("fakta-05", "vilken är världens längsta flod", ["nilen"]),
    ("fakta-09", "hur många ledamöter har riksdagen", ["trehundrafyrtionio"]),
    ("k9-neg-5", "vad händer med klimatet i framtiden", ["grader"]),
    ("praktiskt-03", "hur byter man däck", ["domkraft"]),
    ("text-01", "sjung en snapsvisa", ["den som inte helan tar han heller inte halvan får", "hej tomtegubbar slå i glasen"]),
    ("text-02", "sjung helan går", ["den som inte helan tar han heller inte halvan får"]),
    ("text-03", "citera Strindberg om kärlek", ["strindberg"]),
    ("k104-01", "vem var Sveriges andra statsminister", ["posse"]),
    ("k104-02", "vem var Sveriges första statsminister", ["de geer"]),
    ("k104-03", "vilket är Sveriges högsta berg", ["kebnekaise"]),
    ("k104-04", "vilken är Sveriges största sjö", ["vänern"]),
    ("k104-05", "vilken är världens högsta byggnad", ["burj khalifa"]),
    ("k104-06", "vilket är världens folkrikaste land", ["indien"]),
    ("k104-07", "vilken är Europas längsta flod", ["volga"]),
    ("k104-08", "vilken är världens största ö", ["grönland"]),
    ("k104-09", "vilket är världens minsta land", ["vatikan"]),
    ("k104-10", "vilken är Sveriges näst största stad", ["göteborg"]),
    ("k104-11", "vilket är Sveriges äldsta universitet", ["uppsala"]),
    ("k104-12", "vem vann melodifestivalen 2024", ["marcus"]),
    ("k104-13", "sjung hej tomtegubbar", ["hej tomtegubbar slå i glasen"]),
    ("k104-14", "vilken är Sveriges längsta flod", ["klarälven", "göta älv"]),
    ("k104-15", "vilket är världens djupaste hav", ["stilla havet"]),
    ("k104-16", "vem var USA:s första president", ["washington"]),
    ("k104-17", "vilken är Sveriges största ö", ["gotland"]),
]
BAD = ["jag kan inte", "det står inte i källorna", "kan inte hitta"]
USERS = 6


def post(path, body, tok, extra=None):
    h = {"apikey": KEY, "content-type": "application/json", **(extra or {})}
    if tok:
        h["Authorization"] = "Bearer " + tok
    return urllib.request.urlopen(urllib.request.Request(URL + path, data=json.dumps(body).encode(), headers=h), timeout=90)


def signup():
    return json.load(post("/auth/v1/signup", {}, None))["access_token"]


def norm(t):
    return re.sub(r"\s+", " ", re.sub(r"[^\w\s]", " ", t.lower())).strip()


def ask(tok, q, model):
    t0 = time.time()
    res = dict(text="", ttft=None, searching=None, done={}, error=None)
    body = {"fragment": q, "mode": "text", "language": "sv", "context": {"recent_qa": []}}
    try:
        with post("/functions/v1/answer", body, tok, {"x-earmind-test": f"kevin-k104 model-{model}"}) as r:
            ev = None
            for line in r:
                line = line.decode().rstrip("\n")
                if line.startswith("event: "):
                    ev = line[7:]
                elif line.startswith("data: "):
                    d = json.loads(line[6:])
                    ms = int((time.time() - t0) * 1000)
                    if ev == "delta":
                        res["ttft"] = res["ttft"] or ms
                        res["text"] += d.get("text", "")
                    elif ev == "searching":
                        res["searching"] = res["searching"] or ms
                    elif ev == "done":
                        res["done"] = d
                    elif ev == "error":
                        res["error"] = d
    except urllib.error.HTTPError as e:
        res["error"] = {"http": e.code}
    except Exception as e:  # network trouble
        res["error"] = {"exc": str(e)[:80]}
    return res


toks = [signup() for _ in range(USERS)]
rows = []
k = 0
for cid, q, key in CASES:
    for model in ("sonnet", "haiku"):
        r = ask(toks[k % USERS], q, model)
        k += 1
        spoken = norm(r["text"].split("källa:")[0])
        right = any(norm(x) in spoken for x in key) and not any(b in spoken for b in BAD)
        u = r["done"].get("usage") or {}
        row = {"id": cid, "model": model, "served": u.get("model"), "web": u.get("web_searches"), "right": right,
               "ttft": r["ttft"], "searching": r["searching"], "cost": u.get("est_cost_usd"),
               "error": r["error"], "svar": r["text"][:200]}
        rows.append(row)
        print(json.dumps(row, ensure_ascii=False), flush=True)
        time.sleep(2)


def summary(label, sel):
    out = {}
    for m in ("sonnet", "haiku"):
        xs = [r for r in sel if r["model"] == m]
        t = [r["ttft"] for r in xs if r["ttft"]]
        out[m] = {"n": len(xs), "right": sum(r["right"] for r in xs),
                  "ttft_median": statistics.median(t) if t else None, "ttft_max": max(t) if t else None,
                  "cost": round(sum((r["cost"] or 0) for r in xs), 4)}
    print(f"=== {label}", json.dumps(out, ensure_ascii=False))


summary("alla", rows)
both = {cid for cid in {r["id"] for r in rows} if all((r["web"] or 0) > 0 for r in rows if r["id"] == cid)}
summary(f"sökta med båda modellerna ({len(both)} frågor)", [r for r in rows if r["id"] in both])
print("=== olika rätt/fel:", [(cid, {r["model"]: r["right"] for r in rows if r["id"] == cid}) for cid in sorted({r["id"] for r in rows})
                               if len({r["right"] for r in rows if r["id"] == cid}) > 1])
print("=== serverad modell stämmer:", all(r["served"] is None or m in (r["served"] or "") for r in rows for m in [r["model"]] if (r["web"] or 0) > 0))
