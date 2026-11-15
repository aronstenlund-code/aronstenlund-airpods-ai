"""O68: vad som låter konstigt, kontrollerat på uppläsningstexten (inte ljudet). Oscar (moln) 2026-11-15.
Kör i Actions (oscar-live.yml):
  python -I -X utf8 scripts/qa/o68_voice.py                      -> gör cirka 100 långa svar ur 9 holdout-prov (appens
                                                                    väg: exam drill + drill_answers, cirka 0,45 USD Claude),
                                                                    sparar dem med testkonton och skriver underlaget
  python -I -X utf8 scripts/qa/o68_voice.py --fixture=FILE       -> sparar samma svar igen (0 Claude), för omtest efter K74
Sedan i samma flöde: o68_analyze.mjs räknar uppläsningstexten med serverns egen kod (voiceText/longVoice ur backend,
buntad med esbuild) och listar de 15 värsta. Sparandet gör att de riktiga uppläsningsraderna finns i drill_audio_files
(teströst, 0 krediter), så att analysen kan jämföras med servern via SQL (md5 av texten).
Bara testkonton (qa_testaccount.install()), 0 ElevenLabs."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import datetime as dt, json, pathlib, sys, time, urllib.error  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
DATA = ROOT / "reports/qa/data"
CAP_USD = 0.5
# svenska, engelska, matte och NO (holdout, inte i Kevins testdata); antal frågor per prov
EXAMS = [("h2-sv-argumentera", 12), ("h3-en-climate", 12), ("h4-en-lighthouse", 12), ("o57-ma-procent", 12),
         ("h3-ma-pythagoras", 12), ("ho-fy1-newton", 12), ("h4-fy-hastighet", 10), ("h3-ke-atomer", 10), ("ho-bio-ak9-blodet", 10)]


def call(fn, body, tok, timeout=240):
    st = 0
    for _ in range(4):
        try:
            st, _h, raw = T.call("POST", f"/functions/v1/{fn}", body, tok, timeout=timeout)
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            print("  nätfel:", e, flush=True)
            time.sleep(5)
            continue
        if st in (429, 502, 503, 504):
            print(f"  {fn} {st}, väntar 20 s", flush=True)
            time.sleep(20)
            continue
        return st, json.loads(raw or b"{}")
    return st, {}


def signup():
    for _ in range(5):
        try:
            return T.signup(True)[0]
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            time.sleep(60)
    raise SystemExit("kan inte registrera testkonto")


def cost(j):
    return float(((j or {}).get("usage") or {}).get("est_cost_usd") or 0)


def save(tok, eid, subject, items):
    its = [{"question": i["question"], "short": i["short"], "long": i["long"]} for i in items]
    st, j = call("drill", {"action": "save", "drill": {"title": f"O68 {eid} (QA)", "subject": subject}, "items": its}, tok)
    return st, (j.get("drill") or {}).get("id"), j.get("new_chars")


def main():
    DATA.mkdir(parents=True, exist_ok=True)
    start = dt.datetime.now(dt.timezone.utc)
    fixture = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--fixture=")), None)
    out, usd = [], 0.0
    if fixture:
        groups = {}
        for it in json.loads((ROOT / fixture).read_text(encoding="utf-8"))["items"]:
            groups.setdefault((it["eid"], it["subject"]), []).append(it)
        for (eid, subject), items in groups.items():
            tok = signup()
            st, did, nc = save(tok, eid, subject, items)
            print(f"{eid}: sparat {st}, {len(items)} svar, new_chars {nc}", flush=True)
            out += [{**i, "drill_id": did} for i in items]
    else:
        import o55_grade as G  # noqa: PLC0415  (materialbanken; samma D180-skydd)
        for eid, n in EXAMS:
            if usd > CAP_USD:
                print(f"kostnadstaket nått ({usd:.3f} USD), hoppar över {eid}", flush=True)
                continue
            tok = signup()
            pages, text = G.drill_material(eid, tok)
            st, plan = call("exam", {"action": "drill", "pages": pages, "text": text, "answers": False, "questions": n}, tok)
            usd += cost(plan)
            if st != 200:
                print(f"{eid}: exam drill {st} {plan.get('error')}", flush=True)
                continue
            st, ans = call("exam", {"action": "drill_answers", "items": plan["items"], "notes": plan["notes"],
                                    "subject": plan["summary"]["subject"], "grade": plan["summary"]["grade"]}, tok)
            usd += cost(ans)
            items = [i for i in ans.get("items", []) if i.get("long")]
            subject = plan["summary"]["subject"]
            st2, did, nc = save(tok, eid, subject, items)
            print(f"{eid}: {subject}, {len(items)} svar, sparat {st2}, new_chars {nc}, {usd:.3f} USD hittills", flush=True)
            out += [{"eid": eid, "subject": subject, "question": i["question"], "short": i["short"], "long": i["long"], "drill_id": did}
                    for i in items]
    end = dt.datetime.now(dt.timezone.utc)
    p = DATA / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o68-items.json")
    p.write_text(json.dumps({"start": start.isoformat(), "end": end.isoformat(), "claude_usd": round(usd, 4), "fixture": fixture,
                             "items": out}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\n=== {len(out)} svar, Claude {usd:.3f} USD, {start.isoformat(timespec='seconds')}–{end.isoformat(timespec='seconds')}")
    print("drills:", sorted({i["drill_id"] for i in out if i.get("drill_id")}))
    print("->", p)


if __name__ == "__main__":
    main()
