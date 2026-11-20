"""O92 (Deangelo 2026-11-20 16:45): omtest av K113 och O91 N5 live, Oscar (moln).
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o92_k113_n5_live.py
Testkonton (x-earmind-test), inget ljud görs (defer_audio, ingen start), 0 ElevenLabs. Webb: 4 enheter av testtaket
(två sökta svar, en sång, en nulägesfråga), efter nattens eval. Claude: fyra /answer, cirka 0,03 USD.

K113: från Actions räknas all trafik som test (K105), så "vanlig användare utan huvud" går inte att visa härifrån; det
prövas offline i scripts/qa/o92_k113_test.ts. Live: stats svarar logged: true för testtrafik, med och utan share_history.
N5: sökta svar kapas efter sista hela meningen inom 80 ord, källan finns kvar (done.source), sånger kapas aldrig."""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE))
import qa_testaccount as T  # noqa: E402
T.install()
import importlib.util, json, re, urllib.error, urllib.request  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
spec = importlib.util.spec_from_file_location("live_eval", HERE.parent / "live-eval.py")
LE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(LE)
OK = []


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:2500], flush=True)


def drill(body, tok):
    r = urllib.request.Request(T.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST", headers=T.headers(tok, True))
    try:
        with urllib.request.urlopen(r, timeout=120) as x:
            return x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


# ---------------- K113 ----------------
tok = T.signup(True)[0]
items = [{"question": "Vad är fotosyntes?", "short": "Växter gör socker av ljus.", "long": "Växter gör socker av ljus, vatten och koldioxid."},
         {"question": "Var sker fotosyntesen?", "short": "I kloroplasterna.", "long": "I kloroplasterna i bladens celler."}]
s1, j1 = drill({"action": "save", "defer_audio": True, "drill": {"title": "O92 (QA)", "subject": "Biologi"}, "items": items}, tok)
did = (j1.get("drill") or {}).get("id")
s2, j2 = drill({"action": "stats", "id": did, "presses": {"1": 1, "2": 0, "3": 0}}, tok)
s3, j3 = drill({"action": "stats", "id": did, "share_history": True, "presses": {"1": 0, "2": 1, "3": 0}}, tok)
s4, j4 = drill({"action": "stats", "id": did, "share_history": False, "presses": {"1": 0, "2": 0, "3": 1}}, tok)
check("K113 live: testtrafik loggas (stats logged: true utan, med och med falsk share_history); save utan ljud",
      s1 == 200 and s2 == s3 == s4 == 200 and j2.get("logged") is True and j3.get("logged") is True and j4.get("logged") is True,
      {"save": [s1, (j1.get("audio") or {}).get("cost")], "stats utan": [s2, j2], "stats share_history true": [s3, j3], "stats share_history false": [s4, j4]})
drill({"action": "delete", "id": did}, tok)

# ---------------- N5 ----------------
be = LE.Backend()
u = be.user(0)
domains = LE.reliable_domains()
CASES = [
    ("hur byter man däck", "web", True),
    ("recept på köttbullar", "web", True),
    ("vad händer i Ukraina just nu, berätta utförligt", "web", True),
    ("sjung Gubben Noak, alla verser", "song", False),
]
for q, kind, must_cut in CASES:
    r = be.ask(u, {"fragment": q, "mode": "text", "language": "sv", "context": {"recent_qa": []}})
    d = r["done"] or {}
    text = r["text"].strip()
    spoken, src_line = LE.split_source(text)
    spoken = re.sub(r"\s*Källa: [^.]*\.\s*$", "", spoken) if d.get("source") else spoken
    words = len(spoken.split())
    ends = spoken.rstrip()[-1:] in ".!?\"”»"
    ws = (d.get("usage") or {}).get("web_searches")
    if kind == "web":
        ok = bool(ws) and words <= 80 and ends and bool(d.get("source") or src_line) and not d.get("web_cap_test")
        name = f"N5 sökt svar ≤ 80 ord, hel mening sist, källa kvar: {q}"
    else:
        ok = not d.get("web_cap_test") and words > 0 and ends
        name = f"N5 sång kapas inte (antal ord visas; längre än 80 är tillåtet): {q}"
    check(name, ok, {"ord": words, "sista tecken": spoken.rstrip()[-1:], "web_searches": ws, "source": d.get("source") or src_line,
                     "web_cap_test": d.get("web_cap_test"), "ttft_ms": r["ttft_ms"], "fel": r["error"], "text": text[:1800]})

print(f"\n=== O92 {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
