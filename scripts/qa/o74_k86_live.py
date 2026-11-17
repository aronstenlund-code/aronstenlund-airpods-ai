"""O74: omtest av K86 (D207: spridning efter längd, högst hälften från en del, eget tak 1 fråga per 600 tecken).
Oscar (moln), 2026-11-17. Kör i Actions (oscar-live.yml) efter K86. Testkonto, 0 ElevenLabs, Claude cirka 0,05 USD.
Nytt hopsatt material: tre ämnen med olika längd (kort, mellan, lång), plus 10/1/1-fallet från O73 (Blandat) och det
långa materialet med 8 texter. 2 körningar var, 12 frågor begärda (och 20 för takkontrollen på det korta).
Kontroller per generering:
  spridning: med 3+ delar högst hälften av frågorna i en del (min egen placering, TF-IDF på fråga + kort svar)
  tak: min(begärt, floor(tecken/600)) <= antal <= begärt (D207: målet är max av modellens och kodens tak)
  utfyllnad: varje fråga har minst ett innehållsord ur materialet; inga dubbletter (samma ordmängd)"""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import collections, json, math, re, time  # noqa: E402

sys = _s
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(_p.Path(__file__).resolve().parent / "repetition_bank"))
from materials_holdout import H  # noqa: E402
from materials_holdout2 import H2  # noqa: E402
from materials_holdout3 import H3  # noqa: E402
from materials_holdout4 import H4  # noqa: E402
M = {**H, **H2, **H3, **H4}
text = lambda eid: "\n\n".join(M[eid]["pages"])  # noqa: E731
# tre ämnen, olika längd: kort (matte ~700), mellan (historia ~1300), lång (två SO-texter ~1900)
NEW = "\n\n".join([text("h3-ma-pythagoras"), text("ho-hi-medeltid"), text("h3-sh-riksdagen") + "\n\n" + text("ho-sh-privatekonomi")])
CASES = [
    ("Nytt: matte (kort) + historia (mellan) + SO (lång)", "Samhällskunskap", NEW, 12),
    ("Blandat (10/1/1-fallet i O73)", "Religionskunskap", "\n\n".join(text(e) for e in ["h2-re-buddhism", "h2-sv-argumentera", "o57-idh-traning", "h2-hkk-naring"]), 12),
    ("Lång: 8 NO/SO-texter", "Samhällskunskap", "\n\n".join(text(e) for e in ["ho-hi-medeltid", "ho-fy1-newton", "h3-sh-riksdagen", "o57-ke-syror", "ho-sh-privatekonomi", "h3-ke-atomer", "h2-hkk-naring", "h3-bi-anteckningar"]), 12),
    ("Tak: kort text, 20 begärda", "Matematik", text("h3-ma-pythagoras"), 20),
]
STOP = set("och att det som en är på för med av till den de i om har inte kan så när var ett vad hur varför vilka vilken man sig sin sina eller också från ut upp alla mer andra efter vid över under då nu där här bara hade blir blev vara ska skulle the and of to a in is that for on are as with by it this be or what why how which".split())


def toks(s):
    return [w[:6] for w in re.findall(r"[a-zåäöéü]+", s.lower()) if len(w) > 2 and w not in STOP]


def parts_of(t, k):
    if k <= 1:
        return [t]
    cuts, n = [0], len(t)
    cands = [m.end() for m in re.finditer(r"\n\s*\n|[.!?]\s", t)]
    for i in range(1, k):
        target = round(i * n / k)
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

    def cos(a, b):
        num = sum(a[w] * b.get(w, 0) for w in a)
        da, db = math.sqrt(sum(x * x for x in a.values())), math.sqrt(sum(x * x for x in b.values()))
        return num / (da * db) if da and db else 0
    return [max(range(len(pv)), key=lambda i: cos(vec(collections.Counter(toks(it["question"] + " " + (it.get("short") or "")))), pv[i])) for it in items]


fails, total, cost = 0, 0, 0.0
for name, subject, material, asked in CASES:
    for r in range(2):
        tok = T.signup(True)[0]
        st, _h, raw = T.call("POST", "/functions/v1/exam", {"action": "drill", "text": material, "answers": False, "questions": asked, "subject": subject}, tok, timeout=180)
        j = json.loads(raw or b"{}")
        if st != 200:
            print(f"FEL  {name} #{r + 1}: {st} {j.get('error')}", flush=True)
            fails += 1
            continue
        items = j.get("items") or []
        u = j.get("usage") or {}
        cost += float(u.get("est_cost_usd") or 0)
        cap = min(asked, len(material) // 600)  # D207: kodens tak; målet är max(modellens, kodens), högst det begärda
        k = max(2, min(6, len(items), round(len(material) / 1200))) if len(material) >= 1200 else 1
        parts = parts_of(material, k)
        per = [place(items, parts).count(i) for i in range(len(parts))] if items else []
        mat = set(toks(material))
        filler = [i["question"] for i in items if not (set(toks(i["question"] + " " + (i.get("short") or ""))) & mat)]
        keys = [frozenset(toks(i["question"])) for i in items]
        dups = len(keys) - len(set(keys))
        near = [(items[a]["question"], items[b]["question"]) for a in range(len(keys)) for b in range(a + 1, len(keys))
                if keys[a] and keys[b] and len(keys[a] & keys[b]) / min(len(keys[a]), len(keys[b])) >= 0.75]
        spread_ok = len(parts) < 3 or not items or max(per) <= len(items) / 2
        cap_ok = cap <= len(items) <= asked
        ok = spread_ok and cap_ok and not filler and not dups and not near
        total += 1
        fails += not ok
        print(f"{'ok   ' if ok else 'FEL  '}{name} #{r + 1}: {len(material)} tecken, begärt {asked}, fick {len(items)}, tak {cap}"
              f" ({'ok' if cap_ok else 'UTANFÖR'}), delar {len(parts)} frågor per del {per} ({'ok' if spread_ok else 'över hälften'}),"
              f" utfyllnad {len(filler)}, dubbletter {dups}, nästan lika {len(near)} | servern {u.get('coverage')} questions_possible {j.get('questions_possible') or (j.get('summary') or {}).get('questions_possible')}"
              f" | {round(float(u.get('est_cost_usd') or 0), 4)} USD", flush=True)
        for f in filler:
            print(f"     utfyllnad?: {f}", flush=True)
        for a, b in near:
            print(f"     nästan lika: {a} | {b}", flush=True)
        pl = place(items, parts) if items else []
        for d in range(len(parts)):
            print(f"     del {d + 1}: " + " || ".join(items[i]["question"][:70] for i in range(len(items)) if pl[i] == d), flush=True)
print(f"\n=== O74 {total - fails}/{total} ok, Claude {cost:.3f} USD")
sys.exit(1 if fails else 0)
