#!/usr/bin/env python3
"""D87: runs the Provläge test bank (scripts/provlage-bank.json) against the deployed backend and has a stronger
model grade every answer against the rubric (correct, A level, sufficient, natural, length). Main measure: the
share where the FIRST answer is enough (correct and sufficient), target >= 90 %.

  python3 scripts/provlage-eval.py --model haiku --judge opus  [--only term,followup] [--limit N] [--out DIR]

Uses an anonymous session and the public key, like scripts/live-eval.py; no secrets. The answers come from
POST /provlage-eval (the same /answer code, with Provläge on the chosen model), the grades from the same function
(judge opus = Claude Opus 5.5, sonnet = Claude Sonnet 5.5)."""
import argparse, concurrent.futures as cf, datetime, json, os, re, statistics, sys, time, urllib.request, http.client, ssl

URL_HOST = "xjczbzfkmbjdebwlccki.supabase.co"
URL = f"https://{URL_HOST}"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USERS = 4


def signup():
    req = urllib.request.Request(URL + "/auth/v1/signup", method="POST", data=b"{}",
                                 headers={"apikey": KEY, "content-type": "application/json"})
    return json.loads(urllib.request.urlopen(req, timeout=30).read())["access_token"]


def stream_answer(tok, model, body):
    """The SSE answer; client time to the first text, the text and the done event."""
    for attempt in range(3):
        c = http.client.HTTPSConnection(URL_HOST, timeout=90, context=ssl.create_default_context())
        t0 = time.perf_counter()
        c.request("POST", "/functions/v1/provlage-eval",
                  body=json.dumps({"action": "answer", "model": model, "request": body}).encode(),
                  headers={"apikey": KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
        r = c.getresponse()
        if r.status == 429 and attempt < 2:
            time.sleep(int(r.getheader("retry-after") or 20))
            c.close()
            continue
        if r.status != 200:
            return {"error": f"http {r.status} {r.read()[:150]!r}"}
        buf, text, done, ttft = "", "", None, None
        while True:
            chunk = r.read1(4096)
            if not chunk:
                break
            buf += chunk.decode("utf-8", "replace")
            while "\n\n" in buf:
                f, buf = buf.split("\n\n", 1)
                ev = re.search(r"^event: (.*)$", f, re.M)
                da = re.search(r"^data: (.*)$", f, re.M)
                if not ev or not da:
                    continue
                d = json.loads(da.group(1))
                if ev.group(1) == "delta":
                    if ttft is None:
                        ttft = (time.perf_counter() - t0) * 1000
                    text += d.get("text", "")
                elif ev.group(1) == "done":
                    done = d
        c.close()
        return {"text": text.strip(), "client_ttft": ttft, "done": done}
    return {"error": "rate limited"}


def post(tok, payload):
    for attempt in range(3):
        req = urllib.request.Request(f"{URL}/functions/v1/provlage-eval", method="POST", data=json.dumps(payload).encode(),
                                     headers={"apikey": KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
        try:
            return json.loads(urllib.request.urlopen(req, timeout=120).read())
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 2:
                time.sleep(int(e.headers.get("retry-after") or 20))
                continue
            return {"error": f"http {e.code} {e.read()[:150]!r}"}
        except Exception as e:  # network blip
            if attempt < 2:
                time.sleep(5)
                continue
            return {"error": str(e)}


def run_case(tok, case, model, judge):
    body = {"fragment": case["q"], "mode": "tutor", "language": "sv", "persona": "tutor",
            "persona_setup": case["profile"], "context": {"recent_qa": case["context"][-3:]}}
    a = stream_answer(tok, model, body)
    if a.get("error"):
        return {**case, "error": a["error"]}
    done = a["done"] or {}
    g = post(tok, {"action": "grade", "judge": judge, "case": case, "answer": a["text"]})
    if g.get("error"):
        return {**case, "answer": a["text"], "error": g["error"]}
    u = done.get("usage") or {}
    return {
        **case, "answer": a["text"], "scores": g["scores"], "first_ok": g["first_answer_suffices"], "note": g.get("note", ""),
        "server_ttft": (done.get("timing") or {}).get("ttft_ms"), "client_ttft": a["client_ttft"],
        "answer_cost": float(u.get("est_cost_usd") or 0), "judge_cost": float((g.get("usage") or {}).get("est_cost_usd") or 0),
        "cache_read": u.get("cache_read_tokens"), "chars": len(a["text"]),
    }


def pct(xs, p):
    xs = sorted(x for x in xs if x is not None)
    return round(xs[min(len(xs) - 1, int(p * len(xs)))]) if xs else None


def summary(rows, model, judge):
    ok = [r for r in rows if "scores" in r]
    n = len(ok)
    def share(f):
        return round(100 * sum(1 for r in ok if f(r)) / n, 1) if n else 0
    out = {
        "model": model, "judge": judge, "cases": len(rows), "graded": n, "errors": len(rows) - n,
        "first_answer_suffices_pct": share(lambda r: r["first_ok"] == 1),
        **{f"{k}_pct": share(lambda r, k=k: r["scores"][k] == 1) for k in ("correct", "a_level", "sufficient", "natural", "length_ok")},
        "server_ttft_p50": pct([r["server_ttft"] for r in ok], .5), "server_ttft_p90": pct([r["server_ttft"] for r in ok], .9),
        "client_ttft_p50": pct([r["client_ttft"] for r in ok], .5),
        "answer_cost_mean_usd": round(statistics.mean([r["answer_cost"] for r in ok]), 6) if n else 0,
        "answer_cost_total_usd": round(sum(r["answer_cost"] for r in ok), 4),
        "judge_cost_total_usd": round(sum(r["judge_cost"] for r in ok), 4),
        "by_kind": {},
    }
    for k in sorted({r["kind"] for r in ok}):
        sub = [r for r in ok if r["kind"] == k]
        out["by_kind"][k] = f'{sum(1 for r in sub if r["first_ok"] == 1)}/{len(sub)}'
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="haiku", choices=["haiku", "sonnet"])
    ap.add_argument("--judge", default="sonnet", choices=["opus", "sonnet"])
    ap.add_argument("--only", default="")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--out", default=os.path.join(ROOT, "reports", "eval"))
    a = ap.parse_args()
    cases = json.load(open(os.path.join(ROOT, "scripts", "provlage-bank.json"), encoding="utf-8"))
    if a.only:
        kinds = set(a.only.split(","))
        cases = [c for c in cases if c["kind"] in kinds]
    if a.limit:
        cases = cases[:a.limit]
    toks = [signup() for _ in range(USERS)]
    rows = []
    with cf.ThreadPoolExecutor(max_workers=a.workers) as ex:
        futs = [ex.submit(run_case, toks[i % USERS], c, a.model, a.judge) for i, c in enumerate(cases)]
        for f in cf.as_completed(futs):
            rows.append(f.result())
    rows.sort(key=lambda r: r["id"])
    s = summary(rows, a.model, a.judge)
    os.makedirs(a.out, exist_ok=True)
    date = datetime.datetime.now().strftime("%Y-%m-%d")
    base = os.path.join(a.out, f"provlage-{date}-{a.model}")
    json.dump({"summary": s, "rows": rows}, open(base + ".json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    lines = [f"# Provläge test bank {date}: {a.model} (judge {a.judge})", "",
             f"**First answer is enough: {s['first_answer_suffices_pct']} %** of {s['graded']} graded ({s['errors']} errors). Target ≥ 90 %.", "",
             "| correct | A level | sufficient | natural | length | TTFT p50 server / client (ms) | cost per answer (USD) |", "|---|---|---|---|---|---|---|",
             f"| {s['correct_pct']} % | {s['a_level_pct']} % | {s['sufficient_pct']} % | {s['natural_pct']} % | {s['length_ok_pct']} % | {s['server_ttft_p50']} / {s['client_ttft_p50']} | {s['answer_cost_mean_usd']} |", "",
             "By kind (first answer enough): " + ", ".join(f"{k} {v}" for k, v in s["by_kind"].items()), "",
             f"Cost: answers {s['answer_cost_total_usd']} USD, judge {s['judge_cost_total_usd']} USD.", "", "## Misses", ""]
    for r in rows:
        if r.get("error"):
            lines.append(f"- **{r['id']}** ({r['kind']}) \"{r['q']}\": error {r['error']}")
        elif r["first_ok"] != 1:
            bad = ", ".join(k for k, v in r["scores"].items() if v == 0)
            lines.append(f"- **{r['id']}** ({r['kind']}, {r['grade']}, {r['subject']}) \"{r['q']}\" → {bad}: {r['note']}  \n  > {r['answer'][:220]}")
    open(base + ".md", "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print(json.dumps(s, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
