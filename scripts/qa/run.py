#!/usr/bin/env python3
"""Oscar QA round against the deployed Lumen backend (/answer, /tts).

Never calls the Claude API directly: answers are judged in the QA session, by hand.

  python -I scripts/qa/run.py --level quick --answer-version 37 --tts-version 10 [--dry-run]
  python -I scripts/qa/run.py --level full  --answer-version 37 --tts-version 10 [--owner-asked]

The versions come from Supabase (list_edge_functions), because the server does not report them itself.

Hard rules enforced here (from the assignment):
  - budget per round: quick $0.10, full $0.50, computed from tokens; the round stops when it is reached
  - per round at most 10 Rizz turns, 3 web searches, 2 /tts calls; no other voice calls
  - one anonymous sign-in for the whole round
  - full round at most once per day unless --owner-asked
  - same server versions as the last round: conversations already run are skipped (volatile ones run again)

A web answer can use up to 3 searches on the server, so a web turn only starts when 3 searches are still
left. Any turn the server would send to web search counts, also by accident (the trigger words are read
from backend/supabase/functions/answer/web.ts).
"""
import argparse
import datetime as dt
import hashlib
import json
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
QA = ROOT / "scripts" / "qa"
DATA = ROOT / "reports" / "qa" / "data"
STATE = QA / "state.json"
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design, see backend/README.md

BUDGET = {"quick": 0.10, "full": 0.50}
MAX_RIZZ = 10
MAX_WEB_SEARCHES = 3
WEB_WORST_CASE = 3  # server cap per answer
MAX_TTS = 2
SPACING_S = 3.4  # server allows 20 requests per minute per user
PRICES = {"claude-haiku-5-5": (0.10, 0.50), "claude-sonnet-5-5": (2.0, 10.0)}  # USD per MTok, list price
HISTORY = 3  # what the app sends in ordinary flows (Conversation.recentQA)
HISTORY_LONG = 6  # tutor and interview sessions
TTS_TEXTS = [
    ("pcm_24000", "Berlinmuren föll den nionde november nittonhundraåttionio."),
    ("mp3_22050_32", "Svaret är fyrahundratrettiosju, alltså drygt fyra hundra."),
]


def web_regexes():
    """Reads the server's trigger words, so the guard cannot drift from web.ts."""
    src = (ROOT / "backend/supabase/functions/answer/web.ts").read_text(encoding="utf-8")
    rx = []
    for name in ("EXPLICIT", "CURRENT"):
        m = re.search(name + r" = pat\(\s*\[(.*?)\]\.join", src, re.S)
        if not m:
            sys.exit(f"cannot read {name} from web.ts")
        alts = [a.replace("\\\\", "\\") for a in re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1))]
        rx.append(re.compile(r"(?<![^\W_])(?:" + "|".join(alts) + r")(?![^\W_])", re.I))
    rx.append(re.compile(r"https?://\S+|(?<![\w@.])[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:se|com|org|net|nu|io|eu|dev|gov|edu|info|app|ai|co|uk|de|no|dk|fi)(?:/\S*)?(?!\w)", re.I))
    return rx


def would_search(rx, fragment):
    f = fragment.strip()
    return bool(f) and len(f) <= 400 and any(r.search(f) for r in rx)


def post(path, body, token=None, timeout=90):
    h = {"apikey": KEY, "content-type": "application/json"}
    if token:
        h["Authorization"] = "Bearer " + token
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode(), headers=h)
    return urllib.request.urlopen(req, timeout=timeout)


def ask(body, token):
    """Streams one /answer call. Returns a dict with the text, timing and usage."""
    t0 = time.perf_counter()
    out = {"text": "", "suggestions": None, "ttft_ms": None, "done": None, "error": None, "meta": None}
    try:
        with post("/functions/v1/answer", body, token) as r:
            ev = None
            for raw in r:
                line = raw.decode("utf-8").rstrip("\r\n")
                if line.startswith("event: "):
                    ev = line[7:]
                elif line.startswith("data: "):
                    d = json.loads(line[6:])
                    if ev in ("delta", "suggestions") and out["ttft_ms"] is None:
                        out["ttft_ms"] = round((time.perf_counter() - t0) * 1000)
                    if ev == "delta":
                        out["text"] += d.get("text", "")
                    elif ev == "suggestions":
                        out["suggestions"] = d
                    elif ev == "meta":
                        out["meta"] = d
                    elif ev == "done":
                        out["done"] = d
                    elif ev == "error":
                        out["error"] = d
    except urllib.error.HTTPError as e:
        out["error"] = {"http": e.code, "body": e.read().decode("utf-8", "replace")[:300]}
        out["retry_after"] = e.headers.get("Retry-After")
    except Exception as e:  # network trouble is a finding, not a crash
        out["error"] = {"exception": repr(e)}
    out["wall_ms"] = round((time.perf_counter() - t0) * 1000)
    return out


def cost_of(done):
    """USD from tokens, on the high side: uncached input is priced as a cache write."""
    u = (done or {}).get("usage") or {}
    pi, po = PRICES.get(u.get("model"), PRICES["claude-sonnet-5-5"])
    total, read = u.get("input_tokens") or 0, u.get("cache_read_tokens") or 0
    own = (max(0, total - read) * 1.25 + read * 0.1) * pi / 1e6 + (u.get("output_tokens") or 0) * po / 1e6
    own += (u.get("web_searches") or 0) * 0.01
    return max(own, u.get("est_cost_usd") or 0)


FLAG_RULES = [
    ("siffra", re.compile(r"\d")),
    ("symbol", re.compile(r"[\^=+*#_/\\<>\[\]{}|~%$€§]")),
    ("förkortning", re.compile(r"\b(?:f\.Kr|e\.Kr|t\.ex|bl\.a|m\.m|o\.s\.v|ca|km|kg)\b\.?")),
    ("frågeslut", re.compile(r"\?\s*$")),
    ("läckt tagg", re.compile(r"\[\[|\]\]|SAMMANFATTNING|\[\[REL")),
    ("punktlista", re.compile(r"(?m)^\s*(?:[-*•]|\d+\.)\s")),
]


def flags(text):
    return [name for name, rx in FLAG_RULES if rx.search(text or "")]


def conv_hash(c):
    return hashlib.sha256(json.dumps(c, ensure_ascii=False, sort_keys=True).encode()).hexdigest()[:16]


def body_for(c, q, hist, memories, extra):
    mode = c.get("mode", "push_to_talk")
    b = {"fragment": q, "mode": mode, "language": "sv", "context": {}}
    if hist:
        n = HISTORY_LONG if (mode == "tutor" or c.get("persona")) else HISTORY
        b["context"]["recent_qa"] = [{"q": h["q"][:400], "a": h["a"][:1500]} for h in hist[-n:]]
    for k in ("persona", "persona_setup", "goals"):
        if k in c:
            b[k] = c[k]
    if "context_transcript" in c:
        b["context"]["transcript"] = c["context_transcript"]
    if memories:
        b["memories"] = list(memories)
    b.update(extra)
    return b


def plan(cases, level):
    return [c for c in cases if level == "full" or c.get("quick")]


def count_turns(c):
    return 1 if c.get("rizz") else len(c["turns"])


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", choices=["quick", "full"], required=True)
    ap.add_argument("--answer-version", type=int, required=True)
    ap.add_argument("--tts-version", type=int, required=True)
    ap.add_argument("--owner-asked", action="store_true", help="owner asked for another full round today")
    ap.add_argument("--dry-run", action="store_true", help="print the plan; no network, no cost")
    a = ap.parse_args()

    cases = json.loads((QA / "cases.json").read_text(encoding="utf-8"))
    rx = web_regexes()
    state = json.loads(STATE.read_text(encoding="utf-8")) if STATE.exists() else {"rounds": [], "seen": {}}
    now = dt.datetime.now()  # the test machine runs on Swedish time
    today = now.strftime("%Y-%m-%d")

    if a.level == "full" and not a.owner_asked and not a.dry_run:
        if any(r["level"] == "full" and r["date"] == today for r in state["rounds"]):
            sys.exit("full round already run today; use the quick level, or --owner-asked")

    versions = f"answer-v{a.answer_version}/tts-v{a.tts_version}"
    same = state.get("versions") == versions
    todo, skipped = [], []
    for c in plan(cases, a.level):
        h = conv_hash(c)
        if same and state["seen"].get(c["id"]) == h and not c.get("volatile"):
            skipped.append({"id": c["id"], "why": "samma serverversion som förra rundan"})
        else:
            todo.append(c)

    # Only one web turn fits a round, so the web conversations take turns between rounds.
    web = [c for c in todo if c.get("web")]
    if web:
        first = web[len(state["rounds"]) % len(web)]
        todo = [first] + [c for c in todo if c is not first]

    accidental = []
    for c in todo:
        if c.get("rizz") or c.get("web"):
            continue
        for t in c["turns"]:
            if would_search(rx, t["q"]):
                accidental.append((c["id"], t["q"]))
    print(f"level={a.level} versions={versions} same_as_last={same} conversations={len(todo)} "
          f"turns={sum(count_turns(c) for c in todo)} skipped={len(skipped)} budget=${BUDGET[a.level]}")
    print("accidental web triggers:", accidental or "none")
    if a.dry_run:
        return

    DATA.mkdir(parents=True, exist_ok=True)
    stamp = now.strftime("%Y-%m-%d-%H%M")
    path = DATA / f"{stamp}-{a.level}.json"
    token = json.load(post("/auth/v1/signup", {}))["access_token"]  # one anonymous user per round

    rows = []
    spent = 0.0
    rizz_used = web_used = tts_used = 0
    stop = None
    last_start = 0.0

    def run_one(c, tid, q, body):
        nonlocal spent, web_used, last_start
        for attempt in (1, 2):
            wait = SPACING_S - (time.perf_counter() - last_start)
            if wait > 0:
                time.sleep(wait)
            last_start = time.perf_counter()
            r = ask(body, token)
            e = r["error"] or {}
            busy = e.get("http") in (429, 503) or e.get("code") in ("provider_busy", "rate_limited")
            if busy and attempt == 1:
                time.sleep(min(int(r.get("retry_after") or 15), 60))
                continue
            break
        spent += cost_of(r["done"])
        u = (r["done"] or {}).get("usage") or {}
        web_used += u.get("web_searches") or 0
        text = " | ".join(r["suggestions"]) if r["suggestions"] else r["text"]
        d = r["done"] or {}
        row = {
            "key": tid, "conv": c["id"], "cat": c["cat"], "q": q, "a": text, "ttft_ms": r["ttft_ms"],
            "wall_ms": r["wall_ms"], "server_ttft_ms": (d.get("timing") or {}).get("ttft_ms"),
            "cold": (d.get("breakdown") or {}).get("cold"), "answer_type": (d.get("breakdown") or {}).get("answer_type"),
            "relation": d.get("relation"), "summary": d.get("summary"), "memory_add": d.get("memory_add"),
            "usage": u, "cost_usd": round(cost_of(r["done"]), 6), "error": r["error"],
            "flags": flags(text), "chars": len(text), "at": dt.datetime.now().strftime("%H:%M:%S"),
        }
        rows.append(row)
        print(f"[{row['ttft_ms']}ms ${spent:.4f}] {tid} {q[:50]!r} -> {text[:90]!r} {row['flags'] or ''}", flush=True)
        path.write_text(json.dumps({"rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
        return row

    for c in todo:
        if spent >= BUDGET[a.level]:
            stop = f"budget reached (${spent:.4f})"
            break
        if c.get("rizz"):
            if rizz_used >= MAX_RIZZ:
                skipped.append({"id": c["id"], "why": "Rizz-taket"})
                continue
            rizz_used += 1
            body = {"fragment": "", "mode": "tutor", "language": "sv", "persona": "social", "social": c["social"],
                    "context": {}}
            run_one(c, c["id"], json.dumps(c["social"], ensure_ascii=False), body)
            continue
        hist, memories = [], list(c.get("memories", []))
        for i, t in enumerate(c["turns"]):
            q = t["q"]
            if would_search(rx, q) and web_used + WEB_WORST_CASE > MAX_WEB_SEARCHES:
                skipped.append({"id": f"{c['id']}.{i + 1}", "why": "webbtaket"})
                continue
            extra = {"turn": t["turn"]} if "turn" in t else {}
            row = run_one(c, f"{c['id']}.{i + 1}", q, body_for(c, q, hist, memories, extra))
            if row["memory_add"]:
                memories.append(row["memory_add"])
            hist.append({"q": q, "a": row["a"]})

    tts_rows = []
    if not stop:
        for fmt, text in TTS_TEXTS:
            if tts_used >= MAX_TTS:
                break
            tts_used += 1
            t0 = time.perf_counter()
            row = {"format": fmt, "chars": len(text)}
            try:
                with post("/functions/v1/tts", {"text": text, "language": "sv", "output_format": fmt}, token) as r:
                    first = r.read(1)
                    row["first_byte_ms"] = round((time.perf_counter() - t0) * 1000)
                    row["bytes"] = len(first) + len(r.read())
                    row["status"], row["type"] = r.status, r.headers.get("content-type")
            except urllib.error.HTTPError as e:
                row["status"], row["error"] = e.code, e.read().decode("utf-8", "replace")[:200]
            row["total_ms"] = round((time.perf_counter() - t0) * 1000)
            tts_rows.append(row)
            print("tts", row, flush=True)

    result = {
        "started": stamp, "level": a.level, "versions": versions, "spent_usd": round(spent, 5),
        "budget_usd": BUDGET[a.level], "stopped": stop, "rizz_turns": rizz_used, "web_searches": web_used,
        "tts_calls": tts_used, "tts": tts_rows, "skipped": skipped, "rows": rows,
    }
    path.write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")

    state["versions"] = versions
    if not same:
        state["seen"] = {}
    ran = {r["conv"] for r in rows if not r["error"]}
    by_id = {c["id"]: c for c in cases}
    state["seen"].update({i: conv_hash(by_id[i]) for i in ran})
    state["rounds"].append({"date": today, "level": a.level, "versions": versions, "spent_usd": round(spent, 5),
                            "data": path.relative_to(ROOT).as_posix()})
    STATE.write_text(json.dumps(state, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"done: turns={len(rows)} spent=${spent:.4f} rizz={rizz_used} web={web_used} tts={tts_used} stop={stop} -> {path}")


if __name__ == "__main__":
    main()
