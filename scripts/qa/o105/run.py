"""O105 (Oscar moln, 2026-11-27): hjälpen och Komprimera genom Kevins K122-återspelning (ingen nätåtkomst, 0 ElevenLabs, 0 Claude).
Kör: python3 scripts/qa/o105/run.py [DENO] [--only ID,ID]
Fallen står i cases.json här; svaren (som modellen) i replies/<id>.cN.txt|json. Ett fall utan svar skriver sin prompt
till prompts/<id>.json. Utfallet: out/<id>.json och en sammanfattning på stdout."""
import json, os, pathlib, subprocess, sys
HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DENO = next((a for a in sys.argv[1:] if not a.startswith("--") and "/" in a), "deno")
ONLY = None
if "--only" in sys.argv:
    ONLY = set(sys.argv[sys.argv.index("--only") + 1].split(","))
cases = json.loads((HERE / "cases.json").read_text())
for d in ("prompts", "out", "replies"):
    (HERE / d).mkdir(exist_ok=True)
for c in cases:
    if ONLY and c["id"] not in ONLY:
        continue
    cmd = [DENO, "run", "--no-lock", "--allow-read", "--allow-write", "--allow-env", "scripts/k122-replay.ts", "--endpoint", c["endpoint"],
           "--body", json.dumps(c["body"], ensure_ascii=False), "--out", str(HERE / "out" / c["id"]), "--json"]
    for h in c.get("headers", []):
        cmd += ["--header", h]
    n = 1
    while True:
        f = next((HERE / "replies" / f"{c['id']}.c{n}{ext}" for ext in (".txt", ".json") if (HERE / "replies" / f"{c['id']}.c{n}{ext}").exists()), None)
        if not f:
            break
        cmd += ["--reply", str(f)]
        n += 1
    p = subprocess.run(cmd, cwd=ROOT / "backend", capture_output=True, text=True)
    line = next((l for l in p.stdout.splitlines()[::-1] if l.startswith("{")), None)
    if not line:
        print(c["id"], "FEL", p.stderr[-600:])
        continue
    r = json.loads(line)
    (HERE / "out" / f"{c['id']}.json").write_text(json.dumps(r, ensure_ascii=False, indent=1))
    if r.get("needs"):
        pr = next((x for x in r["prompts"] if x["stem"] == r["needs"]), r["prompts"][-1])
        (HERE / "prompts" / f"{c['id']}.c{n}.json").write_text(json.dumps(pr, ensure_ascii=False, indent=1))
    for t in r["turns"]:
        d = {k: v for k, v in (t.get("done") or {}).items() if k not in ("usage", "llm_first_token_ms", "total_ms", "ttft_ms")}
        print(json.dumps({"id": c["id"], "status": r["status"], "needs": r.get("needs"), "http": t.get("http_status"), "said": t.get("said"),
                          "json": t.get("json"), "error": t.get("error"), "done": d or None}, ensure_ascii=False)[:1400])
