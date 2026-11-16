"""O73 del 2: hållout-test av K83 (D206, frågorna täcker hela materialet). Oscar (moln), 2026-11-17. Kör i Actions:
  python -I -X utf8 scripts/qa/o73_coverage_live.py
Material som inte fanns i Kevins mätning: hopsatta holdout-texter (H/H2/H3/H4 i repetition_bank) och en annan
Wikipedia-artikel via fetch-url. /exam drill (answers: false, 12 frågor), testkonto, 2 körningar per material.
Täckningen mäts med MIN egen metod, inte serverns: egna lika delar (stycke/meningsslut, samma antal som D206) och
placering med TF-IDF-cosinus på fråga + kort svar (inte serverns ordöverlapp). Jämförs med serverns usage.coverage.
0 ElevenLabs. Claude cirka 0,05 USD."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import json, math, re, time, collections  # noqa: E402

sys = _s
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(_p.Path(__file__).resolve().parent / "repetition_bank"))
from materials_holdout import H  # noqa: E402
from materials_holdout2 import H2  # noqa: E402
from materials_holdout3 import H3  # noqa: E402
from materials_holdout4 import H4  # noqa: E402
M = {**H, **H2, **H3, **H4}
text = lambda eid: "\n\n".join(M[eid]["pages"])  # noqa: E731
COMPOSITES = [
    ("SO: medeltid + riksdagen + privatekonomi", "Samhällskunskap", ["ho-hi-medeltid", "h3-sh-riksdagen", "ho-sh-privatekonomi"]),
    ("NO: Newton + syror + atomer + biologi", "Fysik", ["ho-fy1-newton", "o57-ke-syror", "h3-ke-atomer", "h3-bi-anteckningar"]),
    ("Blandat: buddhism + argumentera + träning + näring", "Religionskunskap", ["h2-re-buddhism", "h2-sv-argumentera", "o57-idh-traning", "h2-hkk-naring"]),
    ("Engelska: climate + lighthouse", "Engelska", ["h3-en-climate", "h4-en-lighthouse"]),
    ("Lång: 8 NO/SO-texter", "Samhällskunskap", ["ho-hi-medeltid", "ho-fy1-newton", "h3-sh-riksdagen", "o57-ke-syror", "ho-sh-privatekonomi", "h3-ke-atomer", "h2-hkk-naring", "h3-bi-anteckningar"]),
]
STOP = set("och att det som en är på för med av till den de i om har inte kan så när var ett vad hur varför vilka vilken man sig sin sina eller också från ut upp alla mer andra efter vid över under då nu där här bara hade blir blev vara ska skulle the and of to a in is that for on are as with by it this be or what why how which".split())


def toks(s):
    return [w[:6] for w in re.findall(r"[a-zåäöéü]+", s.lower()) if len(w) > 2 and w not in STOP]


def parts_of(t, k):
    """Mina egna lika delar: snitt vid närmaste stycke- eller meningsslut kring i*len/k."""
    if k <= 1:
        return [t]
    cuts, n = [0], len(t)
    for i in range(1, k):
        target = round(i * n / k)
        cands = [m.end() for m in re.finditer(r"\n\s*\n|[.!?]\s", t)]
        best = min(cands, key=lambda c: abs(c - target)) if cands else target
        cuts.append(max(best, cuts[-1] + 1))
    cuts.append(n)
    return [t[a:b] for a, b in zip(cuts, cuts[1:]) if t[a:b].strip()]


def place(items, parts):
    docs = [collections.Counter(toks(p)) for p in parts]
    df = collections.Counter(w for d in docs for w in d)
    idf = {w: math.log((1 + len(docs)) / (1 + c)) + 1 for w, c in df.items()}
    vec = lambda c: {w: n * idf.get(w, 1.0) for w, n in c.items()}  # noqa: E731
    pv = [vec(d) for d in docs]
    out = []
    for it in items:
        q = vec(collections.Counter(toks(it["question"] + " " + (it.get("short") or ""))))
        def cos(a, b):
            num = sum(a[w] * b.get(w, 0) for w in a)
            da, db = math.sqrt(sum(x * x for x in a.values())), math.sqrt(sum(x * x for x in b.values()))
            return num / (da * db) if da and db else 0
        sc = [cos(q, p) for p in pv]
        out.append(max(range(len(sc)), key=lambda i: sc[i]))
    return out


def run(name, subject, material):
    tok = T.signup(True)[0]
    st, _h, raw = T.call("POST", "/functions/v1/exam", {"action": "drill", "text": material, "answers": False, "questions": 12, "subject": subject}, tok, timeout=180)
    j = json.loads(raw or b"{}")
    if st != 200:
        print(f"FEL  {name}: {st} {j.get('error')}", flush=True)
        return None
    items = j.get("items") or []
    cov = (j.get("usage") or {}).get("coverage")
    k = max(2, min(6, len(items), round(len(material) / 1200))) if len(material) >= 1200 else 1
    parts = parts_of(material, k)
    pl = place(items, parts)
    per = [pl.count(i) for i in range(len(parts))]
    covered = sum(1 for x in per if x)
    print(f"{'ok   ' if covered == len(parts) else 'obs  '}{name}: {len(material)} tecken, {len(items)} frågor, mina delar {len(parts)}, "
          f"täckta {covered}/{len(parts)}, frågor per del {per} | servern {cov} | {round((j.get('usage') or {}).get('est_cost_usd') or 0, 4)} USD", flush=True)
    for i, n in enumerate(per):
        if not n:
            print(f"     del {i + 1} utan fråga (enligt mig): {parts[i][:120]!r}", flush=True)
    return {"name": name, "chars": len(material), "questions": [i["question"] for i in items], "my_parts": len(parts), "my_covered": covered,
            "per_part": per, "server": cov, "cost": (j.get("usage") or {}).get("est_cost_usd")}


res, cost = [], 0.0
for name, subject, ids in COMPOSITES:
    material = "\n\n".join(text(e) for e in ids)
    for r in range(2):
        x = run(f"{name} #{r + 1}", subject, material)
        if x:
            res.append(x)
            cost += x["cost"] or 0
# en annan Wikipedia-artikel via fetch-url (inte Kevins "Fotosyntes")
tok = T.signup(True)[0]
st, _h, raw = T.call("POST", "/functions/v1/fetch-url", {"url": "https://sv.wikipedia.org/wiki/Franska_revolutionen"}, tok, timeout=60)
w = json.loads(raw or b"{}")
if st == 200 and w.get("text"):
    for r in range(2):
        x = run(f"Wikipedia Franska revolutionen #{r + 1}", "Historia", w["text"][:15000])
        if x:
            res.append(x)
            cost += x["cost"] or 0
else:
    print("fetch-url för Wikipedia misslyckades:", st, w.get("error"), flush=True)
mine = sum(r["my_covered"] for r in res), sum(r["my_parts"] for r in res)
srv = sum((r["server"] or {}).get("after", 0) for r in res), sum((r["server"] or {}).get("parts", 0) for r in res)
print(f"\n=== O73 del 2: min mätning {mine[0]}/{mine[1]} delar täckta, serverns {srv[0]}/{srv[1]}, {len(res)} genereringar, Claude {cost:.3f} USD")
pathlib = _p
out = pathlib.Path(__file__).resolve().parents[2] / "reports/qa/data" / (time.strftime("%Y-%m-%d-%H%M%S") + "-o73-coverage.json")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(res, ensure_ascii=False, indent=1), encoding="utf-8")
