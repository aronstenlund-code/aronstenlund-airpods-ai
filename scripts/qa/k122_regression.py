"""O108 (Oscar moln, 2026-11-27): regressionssviten för Oscars K122-fall (O102–O107). Spelar upp de sparade modellsvaren
genom serverns kedja (inga modellanrop, inget nät till Anthropic eller ElevenLabs, fast klocka) och jämför utfallet med
baslinjen scripts/qa/k122_baseline.json. Ett ändrat fall betyder att serverns kod eller promptar ändrar vad användaren
får för samma modellsvar – det kan vara en rättning eller ett fel; rapporten visar före/efter.
Kör:  python3 scripts/qa/k122_regression.py [--deno PATH] [--update] [--report FIL.md]
  --update skriver en ny baslinje (efter en avsiktlig ändring, granskad av Oscar).
Avslutas med 1 när något fall har ändrats, saknas eller är nytt, annars 0."""
import json, os, pathlib, re, subprocess, sys, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[2]
QA = ROOT / "scripts/qa"
BASE = QA / "k122_baseline.json"
args = sys.argv[1:]
DENO = args[args.index("--deno") + 1] if "--deno" in args else os.environ.get("DENO", "deno")
UPDATE = "--update" in args
REPORT = args[args.index("--report") + 1] if "--report" in args else None
NOW = os.environ.setdefault("K122_NOW", "2026-11-27T08:00:00Z")
WRAP = [DENO, "run", "--no-lock", "--allow-read", "--allow-write", "--allow-env", str(QA / "k122_fixed_clock.ts")]
UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
DROP = {"timing", "usage", "llm_first_token_ms", "total_ms", "ttft_ms", "meta_ms", "est_cost_usd", "input_tokens", "output_tokens",
        "created_at", "updated_at", "first_audio_url", "cold", "body_ms", "auth_ms", "limits_ms", "llm_first_chunk_ms"}


def norm(x):
    if isinstance(x, dict):
        return {k: norm(v) for k, v in sorted(x.items()) if k not in DROP}
    if isinstance(x, list):
        return [norm(v) for v in x]
    if isinstance(x, str):
        return UUID.sub("<id>", x)
    return x


def case_view(r):
    turns = []
    for t in r.get("turns") or []:
        turns.append(norm({"http": t.get("http_status"), "said": t.get("said"), "done": t.get("done"), "json": t.get("json"),
                           "error": (t.get("error") or {}).get("code") if isinstance(t.get("error"), dict) else t.get("error"),
                           "suggestions": [e.get("data") for e in (t.get("events") or []) if e.get("event") == "suggestions"] or None,
                           "credits": t.get("credits") or None}))
    return {"status": r.get("status"), "needs": r.get("needs"), "turns": turns}


def run(cmd, cwd):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, env=os.environ)
    if p.returncode not in (0,) and not p.stdout.strip():
        print(f"varning: {' '.join(cmd[:6])} … slutade med {p.returncode}: {p.stderr[-400:]}", file=sys.stderr)
    return p


results = {}
tmp = pathlib.Path(tempfile.mkdtemp(prefix="k122reg-"))
# 1. bank cases: every case with saved replies, plus those the server answers by itself
replies = ROOT / "reports/qa/k122-replies"
ids = sorted({f.name.split(".")[0] for f in replies.iterdir()} | {"C01", "C02", "C03", "C04", "C10", "T01", "T02", "T04"})
run(WRAP + ["scripts/k122-replay.ts", "--case", ",".join(ids), "--replies", str(replies), "--out", str(tmp / "bank")], ROOT / "backend")
for i in ids:
    f = tmp / "bank" / f"{i}.json"
    results[f"bank/{i}"] = case_view(json.loads(f.read_text())) if f.exists() else {"status": "saknas"}
# 2. Oscar's own suites
env_replay = " ".join([str(QA / "k122_fixed_clock.ts"), "scripts/k122-replay.ts"])
for s in ("o103", "o104", "o105", "o106", "o107"):
    out = tmp / s
    os.environ["K122_REPLAY"] = env_replay
    os.environ["K122_OUT"] = str(out)
    run(["python3", str(QA / s / "run.py"), DENO], ROOT)
    for c in json.loads((QA / s / "cases.json").read_text()):
        f = out / f"{c['id']}.json"
        results[f"{s}/{c['id']}"] = case_view(json.loads(f.read_text())) if f.exists() else {"status": "saknas"}
# 3. the harnesses (style, voice, speech text; memory, profile, plan)
for name, path in (("o105-harness", "../scripts/qa/o105/style_voice.ts"), ("o107-harness", "../scripts/qa/o107/memory_plan.ts")):
    p = run(WRAP + [path], ROOT / "backend")
    try:
        data = json.loads(p.stdout)
    except ValueError:
        data = None
    rows = data["out"] if isinstance(data, dict) else data
    for row in rows or []:
        row = {k: v for k, v in row.items() if k not in ("user", "prompts", "system_tail")}
        results[f"{name}/{row.get('id')}"] = norm(row)
    if not rows:
        results[f"{name}/*"] = {"status": "saknas", "stderr": p.stderr[-300:]}

if UPDATE:
    BASE.write_text(json.dumps({"now": NOW, "cases": results}, ensure_ascii=False, indent=1, sort_keys=True) + "\n")
    print(f"baslinje skriven: {len(results)} fall → {BASE.relative_to(ROOT)}")
    sys.exit(0)

base = json.loads(BASE.read_text())["cases"] if BASE.exists() else {}
changed = [k for k in results if k in base and results[k] != base[k]]
new = [k for k in results if k not in base]
gone = [k for k in base if k not in results]
missing = [k for k, v in results.items() if v.get("status") == "saknas"]


def short(v):
    s = json.dumps(v, ensure_ascii=False)
    return s if len(s) < 900 else s[:900] + " …"


lines = [f"# K122-regression (O108): {len(results)} fall, fast klocka {NOW}", "",
         f"- oförändrade: {len(results) - len(changed) - len(new)}", f"- **ändrade: {len(changed)}**", f"- nya: {len(new)}",
         f"- borta ur sviten: {len(gone)}", f"- saknar utfall (fel i körningen): {len(missing)}", ""]
for k in changed:
    b, a = base[k], results[k]
    lines += [f"## Ändrat: `{k}`"]
    for ti, (tb, ta) in enumerate(zip(b.get("turns", []), a.get("turns", [])), 1):
        for field in sorted(set(tb) | set(ta)):
            if tb.get(field) != ta.get(field):
                lines += [f"- tur {ti}, `{field}`:", f"  - före: {short(tb.get(field))}", f"  - efter: {short(ta.get(field))}"]
    if "turns" not in b or "turns" not in a or len(b.get("turns", [])) != len(a.get("turns", [])):
        lines += [f"- före: {short(b)}", f"- efter: {short(a)}"]
    lines.append("")
for k in new:
    lines.append(f"- nytt fall: `{k}`")
for k in gone:
    lines.append(f"- borta: `{k}`")
for k in missing:
    lines.append(f"- inget utfall: `{k}`")
lines += ["", "Ett ändrat fall: samma sparade modellsvar ger nu ett annat resultat. Är ändringen avsiktlig (en rättning), kör",
          "`python3 scripts/qa/k122_regression.py --update` och lägg in den nya baslinjen; annars är det ett fel i servern.",
          "Ändras en prompt så att modellen borde svara annorlunda, skriver Oscar ett nytt svar (scripts/qa/OMKORNING.md)."]
text = "\n".join(lines) + "\n"
print(text)
if REPORT:
    pathlib.Path(REPORT).write_text(text)
if os.environ.get("GITHUB_STEP_SUMMARY"):
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as fh:
        fh.write(text)
sys.exit(1 if (changed or new or gone or missing) else 0)
