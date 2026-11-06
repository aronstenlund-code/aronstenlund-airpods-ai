#!/usr/bin/env python3
"""Live eval of the deployed Lumen backend (D56).

~100 conversations (scripts/live-eval-cases.json): facts, follow-ups, topic switches, calculations, time
zones, symbols/formulas, practical, social/Rizz, memory, web search. Runs against the DEPLOYED /answer with
an anonymous Supabase session and the PUBLIC publishable key (both public by design, no secrets anywhere).

Automatic checks on every turn (spoken text): no digits or symbols, no question back, no copy of an earlier
answer, capital first letter, no hedging/filler, no leaked prompt tags, latency budget; per case: expected
(calculated) numbers, time-zone hour from the tz database, forbidden words after a topic switch, reliable web
source, Rizz option shape. Writes reports/eval/<date>.md (+ latest.json, history.csv).

    python3 scripts/live-eval.py [--only CAT[,CAT]] [--out DIR] [--dry]

Exit code: 0 = report written (failures are listed in it), 2 = backend unreachable.
"""
import argparse, csv, datetime, json, os, re, sys, time, urllib.request, urllib.error
from zoneinfo import ZoneInfo

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design
USERS = 5  # per-user limits are 20/min and 3 web/min; conversations rotate over a small pool

# ---------------------------------------------------------------- checks (pure functions, unit-testable)
BAD_CHARS = re.compile(r"[0-9=^/²³%*#_<>\[\]{}()~|\\@&+±×÷≈≠→√πΔ∞°]")
ABBREV = re.compile(r"(?<![\wåäö])[a-zåäö]{1,3}\.[a-zåäö]{1,3}\.?(?![\wåäö.])", re.I)
HEDGES = [
    "jag kan inte hjälpa", "som ai", "som en ai", "språkmodell", "jag är en ai", "jag är inte läkare",
    "det beror på", "tänk på att jag", "jag har inte tillgång", "jag kan inte surfa", "det här är något jag inte",
    "jag kan tyvärr inte", "jag är bara",
]
LEAKS = ["<computed", "<fragment", "<recent_qa", "<active_topic", "[[", "</", "is provided", "computed is"]
UNITS = ["noll", "ett", "två", "tre", "fyra", "fem", "sex", "sju", "åtta", "nio", "tio", "elva", "tolv", "tretton",
         "fjorton", "femton", "sexton", "sjutton", "arton", "nitton"]
TENS = ["", "", "tjugo", "trettio", "fyrtio", "femtio", "sextio", "sjuttio", "åttio", "nittio"]


def sv(n):
    """0-99 in Swedish words (enough for hours)."""
    if n < 20:
        return UNITS[n]
    return TENS[n // 10] + (UNITS[n % 10] if n % 10 else "")


def norm(s):
    return re.sub(r"[^a-zåäöéü0-9]+", "", s.lower())


def split_source(text):
    """(spoken text, source line or None): web answers end with 'källa: domain'."""
    m = re.search(r"\n+\s*källa:\s*(\S+)\s*$", text, re.I)
    return (text[: m.start()].rstrip(), m.group(1)) if m else (text, None)


def last_sentence(t):
    s = re.split(r"(?<=[.!?])\s+", t.strip())
    return s[-1] if s else ""


def generic_checks(text, prev_answers, turn, ttft_ms):
    """Problems found in a spoken answer; each is a short string."""
    out = []
    t = text.strip()
    if not t or t == "null":
        return ["tomt svar"]
    spoken, _ = split_source(t)
    m = BAD_CHARS.search(spoken)
    if m:
        out.append(f"förbjudet tecken i talad text: {m.group(0)!r}")
    if ABBREV.search(spoken):
        out.append("förkortning med punkter (t.ex./e.Kr.) i talad text")
    if "**" in spoken or spoken.lstrip().startswith(("#", "- ", "* ")):
        out.append("markdown i talad text")
    low = spoken.lower()
    for h in HEDGES:
        if h in low and h not in [x.lower() for x in turn.get("allow_hedge", [])]:
            out.append(f"brasklapp/utfyllnad: {h!r}")
            break
    for l in LEAKS:
        if l in low:
            out.append(f"läckt promptdel: {l!r}")
            break
    if not turn.get("allow_question") and last_sentence(spoken).endswith("?"):
        out.append("fråga tillbaka")
    first = re.search(r"[A-Za-zÅÄÖåäöÉé]", spoken)
    if first and first.group(0).islower():
        word = re.match(r"\S+", spoken[first.start():]).group(0)
        if not re.search(r"[A-ZÅÄÖ]", word):  # "iPhone" is fine
            out.append("börjar med gemen")
    n = norm(spoken)
    for p in prev_answers:
        pn = norm(p)
        if pn and (n == pn or (len(n) > 40 and len(pn) > 40 and n[:40] == pn[:40])):
            out.append("kopia av tidigare svar")
            break
    limit = turn.get("ttft_budget_ms", 8000 if turn.get("web") else 2500)
    if ttft_ms is not None and ttft_ms > limit:
        out.append(f"långsamt: {ttft_ms} ms till första ord (budget {limit})")
    return out


def case_checks(text, prev_answer, turn, now):
    """Expectation checks from the case definition."""
    out = []
    spoken, source = split_source(text.strip())
    low = spoken.lower()
    flat = re.sub(r"[\s\-]+", "", low)
    exp = list(turn.get("expect_any", []))
    if "tz" in turn:
        z = turn["tz"]
        h = z["hour"]
        there = datetime.datetime(now.year, now.month, now.day, h, 0, tzinfo=ZoneInfo("Europe/Stockholm")).astimezone(
            ZoneInfo(z["zone"]))
        h24 = there.hour
        h12 = h24 % 12 or 12
        exp = [sv(h24), sv(h12)]
        if there.minute:
            exp = [sv(h24) + " " + sv(there.minute), sv(h12) + " " + sv(there.minute)]
    if exp and not any(norm(e) in re.sub(r"[^a-zåäö0-9]", "", low) or e in low for e in exp):
        out.append(f"väntat svar saknas (något av: {', '.join(exp)})")
    for f in turn.get("forbid_any", []):
        if f.lower() in low:
            out.append(f"förbjudet ord i svaret: {f!r}")
            break
    if turn.get("shorter") and prev_answer is not None and len(spoken) >= len(prev_answer):
        out.append("inte kortare än föregående svar")
    mw = turn.get("max_words")
    if mw and len(spoken.split()) > mw:
        out.append(f"för långt ({len(spoken.split())} ord, max {mw})")
    return out


def web_checks(text, domains):
    spoken, source = split_source(text.strip())
    if not source:
        return ["källrad saknas"]
    s = source.strip(".,;").lower()
    if not any(s == d or s.endswith("." + d) for d in domains):
        return [f"opålitlig källa: {s}"]
    if len(spoken.split()) > 80:
        return ["webbsvar för långt"]
    return []


def rizz_checks(options):
    out = []
    if not isinstance(options, list) or not (2 <= len(options) <= 3):
        return [f"fel antal förslag: {len(options) if isinstance(options, list) else options!r}"]
    if len({norm(o) for o in options}) < len(options):
        out.append("dubbletter bland förslagen")
    for o in options:
        if len(o.split()) > 12:
            out.append(f"förslag för långt: {o!r}")
        if BAD_CHARS.search(o):
            out.append(f"förbjudet tecken i förslag: {o!r}")
    return out


# ---------------------------------------------------------------- transport
class Backend:
    def __init__(self):
        self.tokens = []
        self.i = 0

    def signup(self):
        r = self._post("/auth/v1/signup", {}, None)
        return json.load(r)["access_token"]

    def _post(self, path, body, tok):
        h = {"apikey": KEY, "content-type": "application/json"}
        if tok:
            h["Authorization"] = "Bearer " + tok
        req = urllib.request.Request(URL + path, data=json.dumps(body).encode(), headers=h)
        return urllib.request.urlopen(req, timeout=90)

    def user(self, k):
        while len(self.tokens) <= k % USERS:
            self.tokens.append(self.signup())
        return k % USERS

    def ask(self, u, body):
        """Returns dict(text, ttft_ms, total_ms, done, options, error)."""
        t0 = time.time()
        res = dict(text="", ttft_ms=None, total_ms=None, done={}, options=None, error=None)
        for attempt in (0, 1):
            try:
                with self._post("/functions/v1/answer", body, self.tokens[u]) as r:
                    ev = None
                    for line in r:
                        line = line.decode().rstrip("\n")
                        if line.startswith("event: "):
                            ev = line[7:]
                        elif line.startswith("data: "):
                            d = json.loads(line[6:])
                            if ev == "delta":
                                if res["ttft_ms"] is None:
                                    res["ttft_ms"] = int((time.time() - t0) * 1000)
                                res["text"] += d.get("text", "")
                            elif ev == "suggestions":
                                res["options"] = d
                                if res["ttft_ms"] is None:
                                    res["ttft_ms"] = int((time.time() - t0) * 1000)
                            elif ev == "done":
                                res["done"] = d
                            elif ev == "error":
                                res["error"] = d
                break
            except urllib.error.HTTPError as e:
                if e.code == 401 and attempt == 0:
                    self.tokens[u] = self.signup()
                    continue
                res["error"] = {"http": e.code}
                break
            except Exception as e:  # network trouble
                res["error"] = {"exception": str(e)[:120]}
                break
        res["total_ms"] = int((time.time() - t0) * 1000)
        return res


def reliable_domains():
    src = open(os.path.join(ROOT, "backend/supabase/functions/answer/web.ts"), encoding="utf-8").read()
    block = src[src.index("RELIABLE_DOMAINS = ["):]
    block = block[: block.index("];")]
    return re.findall(r'"([^"]+)"', block)


def run(cases, rizz, domains, only, now):
    be = Backend()
    rows = []
    n_conv = 0
    for case in cases:
        if only and case["cat"] not in only:
            continue
        u = be.user(n_conv)
        n_conv += 1
        hist, answers = [], []
        for ti, turn in enumerate(case["turns"]):
            body = {"fragment": turn["q"], "mode": "text", "language": "sv",
                    "context": {"recent_qa": hist[-3:]}}
            if turn.get("memories"):
                body["memories"] = turn["memories"]
            if turn.get("rizz_ref"):
                sc = rizz[turn["rizz_ref"]]
                body.update(mode="tutor", persona="social",
                            social={k: sc[k] for k in ("place", "style", "trigger", "transcript", "interests", "profile")})
                body["context"] = {}
            r = be.ask(u, body)
            problems = []
            text = r["text"]
            if r["error"]:
                problems.append(f"fel: {json.dumps(r['error'], ensure_ascii=False)[:100]}")
            elif turn.get("rizz_ref"):
                problems += rizz_checks(r["options"])
                text = " | ".join(r["options"]) if isinstance(r["options"], list) else ""
                if (r["ttft_ms"] or 0) > 5000:
                    problems.append(f"långsamt: {r['ttft_ms']} ms")
            else:
                problems += generic_checks(text, answers, turn, r["ttft_ms"])
                problems += case_checks(text, answers[-1] if answers else None, turn, now)
                if turn.get("web"):
                    problems += web_checks(text, domains)
            rel = r["done"].get("relation") if r["done"] else None
            rel_exp = None
            if ti > 0 and turn.get("follow"):
                rel_exp = ("continues", "refines")
            elif case["cat"] == "ämnesbyte" and ti == 1:
                rel_exp = ("new_topic",)
            rows.append(dict(
                id=case["id"], cat=case["cat"], turn=ti, q=turn["q"] or "(Rizz)", ttft=r["ttft_ms"], total=r["total_ms"],
                answer=text[:300], problems=problems, relation=rel,
                relation_ok=(None if rel is None or rel_exp is None else rel in rel_exp),
                cost=(r["done"].get("usage") or {}).get("est_cost_usd") or 0))
            if text and not r["error"]:
                answers.append(split_source(text)[0])
                hist.append({"q": turn["q"], "a": text[:380]})
            time.sleep(0.4)
    return rows


# ---------------------------------------------------------------- report
def pct(xs, p):
    xs = sorted(x for x in xs if x is not None)
    return xs[min(len(xs) - 1, int(len(xs) * p))] if xs else None


def report(rows, date):
    cats = sorted({r["cat"] for r in rows})
    bad = [r for r in rows if r["problems"]]
    out = [f"# Live-eval {date}", "",
           f"Backend: {URL} (anonym inloggning, publik nyckel). **{len(rows)} turer, {len(rows) - len(bad)} utan anmärkning, "
           f"{len(bad)} med anmärkning.**", "",
           "| Kategori | Turer | Anmärkningar | p50 första ord (ms) | p95 (ms) |", "|---|---:|---:|---:|---:|"]
    for c in cats:
        rs = [r for r in rows if r["cat"] == c]
        tt = [r["ttft"] for r in rs]
        out.append(f"| {c} | {len(rs)} | {sum(1 for r in rs if r['problems'])} | {pct(tt, .5)} | {pct(tt, .95)} |")
    rel = [r for r in rows if r["relation_ok"] is not None]
    if rel:
        out += ["", f"Relation (D53): {sum(1 for r in rel if r['relation_ok'])}/{len(rel)} rätt av de turer där modellen angav en."]
    cost = sum(float(r["cost"] or 0) for r in rows)
    out += ["", f"Uppskattad kostnad för körningen: ca {cost:.3f} USD.", ""]
    if bad:
        out += ["## Anmärkningar", ""]
        by = {}
        for r in bad:
            for p in r["problems"]:
                by.setdefault(re.sub(r"[:(].*", "", p).strip(), []).append(r)
        out += ["| Typ | Antal |", "|---|---:|"] + [f"| {k} | {len(v)} |" for k, v in sorted(by.items(), key=lambda kv: -len(kv[1]))]
        out.append("")
        for r in bad:
            out.append(f"- **{r['id']}** tur {r['turn'] + 1} \"{r['q']}\" ({r['ttft']} ms): " + "; ".join(r["problems"]) +
                       f"  \n  > {r['answer'][:220].replace(chr(10), ' ')}")
    else:
        out.append("Inga anmärkningar.")
    return "\n".join(out) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=os.path.join(ROOT, "reports", "eval"))
    ap.add_argument("--dry", action="store_true", help="print the report instead of writing files")
    a = ap.parse_args()
    cases = json.load(open(os.path.join(ROOT, "scripts", "live-eval-cases.json"), encoding="utf-8"))
    rizz = {s["id"]: s for s in json.load(open(os.path.join(ROOT, "testdata", "rizz-scenarios.json"), encoding="utf-8"))}
    now = datetime.datetime.now(datetime.timezone.utc)
    try:
        rows = run(cases, rizz, reliable_domains(), set(filter(None, a.only.split(","))), now)
    except Exception as e:
        print("backend unreachable:", e, file=sys.stderr)
        return 2
    if rows and all(r["problems"] and r["problems"][0].startswith("fel:") for r in rows):
        print("every request failed", file=sys.stderr)
        return 2
    date = now.strftime("%Y-%m-%d")
    md = report(rows, date)
    if a.dry:
        print(md)
        return 0
    os.makedirs(a.out, exist_ok=True)
    open(os.path.join(a.out, f"{date}.md"), "w", encoding="utf-8").write(md)
    json.dump(rows, open(os.path.join(a.out, "latest.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    hist = os.path.join(a.out, "history.csv")
    new = not os.path.exists(hist)
    tt = [r["ttft"] for r in rows if r["cat"] != "webb"]
    with open(hist, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["date", "turns", "flagged", "ttft_p50", "ttft_p95", "cost_usd"])
        w.writerow([date, len(rows), sum(1 for r in rows if r["problems"]), pct(tt, .5), pct(tt, .95),
                    f"{sum(float(r['cost'] or 0) for r in rows):.3f}"])
    print(md)
    return 0


if __name__ == "__main__":
    sys.exit(main())
