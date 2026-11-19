"""O79: provkvalitet på fem nya material (D206, D207), Oscar (moln) 2026-11-17.
Kör i Actions (oscar-live.yml):  python -I -X utf8 scripts/qa/o79_quality.py
Appens väg utan ljud: exam drill (frågor) + drill_answers (svar), inget save, alltså 0 ElevenLabs. Testkonto per material.
Ett material görs till ett telefonfoto (Pillow, samma som banken) och skickas som pages, så att OCR-vägen prövas.
Skriver ut alla frågor och svar (för min granskning av korrekthet och förståelse) och räknar automatiskt:
  täckning: frågor per del (TF-IDF mot materialets delar), delar utan fråga, högst hälften i en del (3+ delar)
  upprepning: samma eller nästan samma fråga (ordöverlapp >= 75 %)
  frågetyp: andel frågor som börjar med varför/hur/förklara/vad händer/jämför/why/how/explain (förståelse) mot rena fakta
Claude-tak 0,5 USD."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import base64, collections, io, json, math, re, tempfile, time, urllib.error  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(_p.Path(__file__).resolve().parent / "o79"))
sys.path.insert(0, str(_p.Path(__file__).resolve().parent / "repetition_bank"))
from o79_materials import O79  # noqa: E402

CAP = 0.5
STOP = set("och att det som en är på för med av till den de i om har inte kan så när var ett vad hur varför vilka vilken man sig sin sina eller också från ut upp alla mer andra efter vid över under då nu där här bara hade blir blev vara ska skulle the and of to a in is that for on are as with by it this be or what why how which was were did does do".split())
WHY = re.compile(r"^\s*(varför|hur |förklara|vad händer|vad skulle|jämför|vilken betydelse|vad blir|beskriv hur|why|how|explain|what would|what happens|compare|in what way)", re.I)


def toks(s):
    return [w[:6] for w in re.findall(r"[a-zåäöéü]+", s.lower()) if len(w) > 2 and w not in STOP]


def place(items, parts):
    docs = [collections.Counter(toks(h + " " + p)) for h, p in parts]
    df = collections.Counter(w for d in docs for w in d)
    idf = {w: math.log((1 + len(docs)) / (1 + c)) + 1 for w, c in df.items()}
    vec = lambda c: {w: n * idf.get(w, 1.0) for w, n in c.items()}  # noqa: E731
    pv = [vec(d) for d in docs]

    def cos(a, b):
        num = sum(a[w] * b.get(w, 0) for w in a)
        da, db = math.sqrt(sum(x * x for x in a.values())), math.sqrt(sum(x * x for x in b.values()))
        return num / (da * db) if da and db else 0
    return [max(range(len(pv)), key=lambda i: cos(vec(collections.Counter(toks(it["question"] + " " + (it.get("short") or "")))), pv[i])) for it in items]


def call(body, tok):
    for _ in range(4):
        try:
            st, _h, raw = T.call("POST", "/functions/v1/exam", body, tok, timeout=240)
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            print("  nätfel:", e, flush=True)
            time.sleep(5)
            continue
        if st in (429, 502, 503, 504):
            time.sleep(20)
            continue
        return st, json.loads(raw or b"{}")
    return st, {}


def photo_pages(m, eid):
    from make_files import photo  # noqa: PLC0415  (samma fotoeffekt som banken)
    pages = []
    with tempfile.TemporaryDirectory() as d:
        for n, (h, p) in enumerate(m["parts"]):
            path = f"{d}/p{n}.jpg"
            photo(f"{h}\n{p}", path, seed=f"{eid}-{n}")
            pages.append({"media_type": "image/jpeg", "data": base64.b64encode(open(path, "rb").read()).decode()})
    return pages


def usd(j):
    u = j.get("usage") or {}
    return float(u.get("est_cost_usd") or (u.get("plan") or {}).get("est_cost_usd") or 0)


total_usd, summary = 0.0, []
for eid, m in O79.items():
    if total_usd > CAP:
        print(f"kostnadstaket nått ({total_usd:.3f}), hoppar över {eid}")
        continue
    tok = T.signup(True)[0]
    full = "\n\n".join(f"{h}\n\n{p}" for h, p in m["parts"])
    body = {"action": "drill", "answers": False, "subject": m["subject"]}
    if m["format"] == "photo":
        body |= {"pages": photo_pages(m, eid), "text": ""}
    else:
        body |= {"pages": [], "text": full}
    st, plan = call(body, tok)
    total_usd += usd(plan)
    if st != 200:
        print(f"FEL  {eid}: exam drill {st} {plan.get('error')}", flush=True)
        summary.append({"eid": eid, "error": st})
        continue
    st2, ans = call({"action": "drill_answers", "items": plan["items"], "notes": plan.get("notes"), "may_fix": True,  # K110/K111: as the app
                     "subject": plan["summary"]["subject"], "grade": plan["summary"]["grade"]}, tok)
    total_usd += usd(ans)
    items = ans.get("items") or plan["items"]
    pl = place(items, m["parts"])
    per = [pl.count(i) for i in range(len(m["parts"]))]
    keys = [frozenset(toks(i["question"])) for i in items]
    near = [(a + 1, b + 1) for a in range(len(keys)) for b in range(a + 1, len(keys))
            if keys[a] and keys[b] and len(keys[a] & keys[b]) / min(len(keys[a]), len(keys[b])) >= 0.75]
    why = sum(bool(WHY.match(i["question"])) for i in items)
    s = plan.get("summary") or {}
    row = {"eid": eid, "format": m["format"], "chars": len(full), "parts": len(m["parts"]), "questions": len(items), "per_part": per,
           "empty_parts": per.count(0), "max_share": round(max(per) / len(items), 2) if items else None, "near_dupes": near,
           "understanding": f"{why}/{len(items)}", "summary": {k: s.get(k) for k in ("subject", "grade", "questions_possible")},
           "coverage_server": (plan.get("usage") or {}).get("coverage"), "usd": round(usd(plan) + usd(ans), 4)}
    summary.append(row)
    print(f"\n=== {eid} ({m['format']}, {m['lang']}, {len(full)} tecken, {len(m['parts'])} delar): {len(items)} frågor, per del {per}, "
          f"nästan lika {near}, förståelse {why}/{len(items)}, {row['usd']} USD | {json.dumps(row['summary'], ensure_ascii=False)} | servern {row['coverage_server']}", flush=True)
    asked = [i.get("question") for i in plan["items"]]
    for n, it in enumerate(items, 1):
        was = asked[n - 1] if n - 1 < len(asked) else None
        mark = f"→ (förut: {was}) " if was and was != it["question"] else ""  # K111: rewritten by the answer step
        print(f"  {n:2d}. [del {pl[n - 1] + 1}] F: {mark}{it['question']}\n      K: {it.get('short')}\n      L: {it.get('long')}", flush=True)
    if m["format"] == "photo":
        print("  OCR-text (början):", json.dumps((plan.get("text") or plan.get("ocr_text") or "")[:300], ensure_ascii=False), flush=True)

print("\n=== O79 sammanfattning", json.dumps(summary, ensure_ascii=False))
print(f"=== Claude {total_usd:.3f} USD")
