"""K66 live check (Kevin, 2026-11-14): Oscar's six O63 hold-out exams through the deployed /exam drill.
Counts per exam: why-questions, circular why-answers (same rule as exam/drill.ts isCircular), answers that mention
"materialet", items with a display text (screen) and the language of the questions (D182).
Test account and test header only (D180: /exam never calls ElevenLabs; the header is there anyway).
Usage: python -X utf8 scripts/k66-quality-check.py  -> reports/qa/data/<time>-k66-quality.json
"""
import concurrent.futures as cf, datetime, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
sys.path.insert(0, os.path.join(HERE, "qa", "repetition_bank"))
import qa_testaccount as qa  # noqa: E402

qa.install()
from materials_holdout3 import H3  # noqa: E402


def stem(w):
    return re.sub(r"[^\w]", "", w.lower())[:5]


def circular(q, short):
    if not re.match(r"^(varför|why)\b", q.strip(), re.I):
        return False
    if re.search(r"just det sambandet|det är bara så|helt enkelt så", short, re.I):
        return True
    qs = {stem(w) for w in q.split()}
    return len({stem(w) for w in short.split() if len(stem(w)) >= 5 and stem(w) not in qs}) < 2


MAT = re.compile(r"(?<!\w)(materialet|i texten|enligt texten|anteckningarna|the material)(?!\w)", re.I)


def run(key, ex, tok):
    text = "\n\n".join(ex["pages"])
    st, _, raw = qa.call("POST", "/functions/v1/exam", {"action": "drill", "text": text, "questions": 12}, tok, timeout=240)
    if st != 200:
        return key, {"status": st, "body": raw[:300].decode("utf8", "replace")}
    j = json.loads(raw)
    items = j.get("items", [])
    return key, {
        "status": st,
        "subject": j.get("summary", {}).get("subject"),
        "questions": len(items),
        "why": sum(1 for i in items if re.match(r"^(varför|why)\b", i["question"], re.I)),
        "circular": [i["question"] for i in items if circular(i["question"], i.get("short", ""))],
        "mentions_material": [i["question"] for i in items if MAT.search(i.get("long", ""))],
        "screen": [{"question": i["question"], "screen": i["screen"]} for i in items if i.get("screen")],
        "english_questions": sum(1 for i in items if re.match(r"^(what|why|how|which|who|when|where|explain|describe)\b", i["question"], re.I)),
        "items": items,
        "cost_usd": j.get("usage", {}).get("est_cost_usd"),
    }


def main():
    only = sys.argv[1:]
    todo = [(k, v) for k, v in H3.items() if not only or k in only]
    out = {}
    with cf.ThreadPoolExecutor(3) as pool:  # one test account per exam (the rate limit is per account)
        for key, r in pool.map(lambda kv: run(kv[0], kv[1], qa.signup()[0]), todo):
            out[key] = r
            print(key, {k: (v if not isinstance(v, list) or k in ("circular", "mentions_material") else len(v)) for k, v in r.items() if k != "items"}, flush=True)
    stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M%S")
    p = os.path.join(HERE, "..", "reports", "qa", "data", f"{stamp}-k66-quality.json")
    with open(p, "w", encoding="utf8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print("saved", os.path.normpath(p))
    print("total cost", round(sum((r.get("cost_usd") or 0) for r in out.values()), 3))


main()
