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
# K104 omgång 2 (2026-11-19, D234, testtaket): frågor som alltid har webbverktyg (texter, "vem vann … 2024/2025", "just nu",
# instruktioner), lokalt kontrollerat; 14 i natt (28 sökta anrop, nattens eval behöver cirka 21 av 50), fler i morgon
NIGHT1 = [
    ("text-02", "sjung helan går", ["den som inte helan tar han heller inte halvan får"]),
    ("text-03", "citera Strindberg om kärlek", ["strindberg"]),
    ("t-tomte", "sjung hej tomtegubbar", ["hej tomtegubbar slå i glasen"]),
    ("t-dugamla", "sjung du gamla du fria", ["du gamla du fria du fjällhöga nord"]),
    ("w-mello24", "vem vann melodifestivalen 2024", ["marcus"]),
    ("w-kung", "vem är Sveriges kung just nu", ["gustaf"]),
    ("w-fn", "vem är FN:s generalsekreterare just nu", ["guterres"]),
    ("praktiskt-03", "hur byter man däck", ["domkraft"]),
    ("w-nobel-lit23", "vem vann nobelpriset i litteratur 2023", ["fosse"]),
    ("w-superbowl25", "vem vann Super Bowl 2025", ["eagles"]),
    ("w-esc25", "vem vann Eurovision 2025", ["österrike", "jj"]),
    ("w-nobel-fys24", "vem vann nobelpriset i fysik 2024", ["hopfield", "hinton"]),
    ("w-mello25", "vem vann melodifestivalen 2025", ["kaj"]),
    ("w-esc24", "vem vann Eurovision 2024", ["nemo", "schweiz"]),
]
NIGHT2 = [
    ("w-nobel-kem23", "vem vann nobelpriset i kemi 2023", ["bawendi", "brus", "jekimov", "yekimov"]),
]
_SET = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--set=")), "1")
CASES = NIGHT1 if _SET == "1" else NIGHT2
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
               "web_cap_test": r["done"].get("web_cap_test", False),
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
srch = [(r["searching"], r["ttft"]) for r in rows if r["searching"] and r["ttft"]]
print("=== searching före första ordet:", sum(1 for a, b in srch if a < b), "av", len(srch), "| median ms före:",
      statistics.median([b - a for a, b in srch]) if srch else None, "| web_cap_test:", sum(1 for r in rows if r["web_cap_test"]))
both = {cid for cid in {r["id"] for r in rows} if all((r["web"] or 0) > 0 for r in rows if r["id"] == cid)}
summary(f"sökta med båda modellerna ({len(both)} frågor)", [r for r in rows if r["id"] in both])
print("=== olika rätt/fel:", [(cid, {r["model"]: r["right"] for r in rows if r["id"] == cid}) for cid in sorted({r["id"] for r in rows})
                               if len({r["right"] for r in rows if r["id"] == cid}) > 1])
print("=== serverad modell stämmer:", all(r["served"] is None or m in (r["served"] or "") for r in rows for m in [r["model"]] if (r["web"] or 0) > 0))
