"""O70: K77 live med testkonton (Oscar moln, 2026-11-15). Kör i Actions (oscar-live.yml):
  python -I -X utf8 scripts/qa/o70_k77_live.py
Testkonton ska INTE komma med i Arons analys (qa_log). Skriptet sparar ett frågeprov och ett läsläge med ett unikt
märkord, ändrar, skickar tryckstatistik, delar och importerar, och skriver tidsfönstret och märkordet. Efteråt (Supabase
MCP): 0 rader i qa_log med märkordet och 0 rader med mode repetition/read i fönstret. 0 ElevenLabs (testljud), 0 Claude."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import datetime as dt, json, random, time  # noqa: E402

sys = _s
sys.stdout.reconfigure(encoding="utf-8")
START = dt.datetime.now(dt.timezone.utc)
MARK = "o70mark" + "".join(random.choice("abcdefghijkmnopqrstuvwxyz") for _ in range(8))
OK = []


def call(body, tok):
    st, _h, raw = T.call("POST", "/functions/v1/drill", body, tok, timeout=120)
    return st, json.loads(raw or b"{}")


def check(name, ok, detail=""):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name + (f" | {str(detail)[:200]}" if detail else ""), flush=True)


tok = T.signup(True)[0]
items = [{"question": f"Vad betyder {MARK}?", "short": f"{MARK} är ett påhittat ord.", "long": f"{MARK} är ett påhittat ord. Det används i O70."},
         {"question": "Vad är 2 + 2?", "short": "Det är fyra.", "long": "Det är fyra. Två plus två."}]
st, j = call({"action": "save", "defer_audio": True, "drill": {"title": f"O70 {MARK} (QA)", "subject": "Biologi"}, "items": items}, tok)
check("spara frågeprov (testkonto)", st == 200, st)
did = j["drill"]["id"]
ed = [{**items[0], "id": j["items"][0]["id"], "long": items[0]["long"] + f" Ändrad {MARK}."}, {**items[1], "id": j["items"][1]["id"]}]
st, _ = call({"action": "save", "defer_audio": True, "drill": {"id": did}, "items": ed}, tok)
check("ändra svaret", st == 200, st)
st, s = call({"action": "stats", "id": did, "presses": {"1": 3, "2": 2, "3": 1}, "per_question": [{"position": 0, "presses": {"1": 2, "2": 1, "3": 0}}], "minutes": 4}, tok)
check("stats svarar logged: false för testkonto", st == 200 and s.get("logged") is False, s)
st, t = call({"action": "save", "drill": {"kind": "text", "title": "O70 text (QA)", "subject": "Historia"},
              "items": [{"kind": "heading", "text": f"Rubrik {MARK}"}, {"kind": "para", "text": f"Materialtext med {MARK}. Den ska aldrig loggas."}]}, tok)
check("spara läsläge (testkonto)", st == 200, st)
st, s = call({"action": "stats", "id": t["drill"]["id"], "presses": {"1": 1, "2": 4, "3": 0}}, tok)
check("stats för läsläget: logged false", st == 200 and s.get("logged") is False, s)
st, bad = call({"action": "stats", "id": did, "presses": {"1": -1, "2": 0, "3": 0}}, tok)
check("ogiltiga tryck ger 400", st == 400, st)
st, sh = call({"action": "start", "id": did}, tok)
check("starta prov (testljud)", st == 200, st)
for _ in range(15):
    st, v = call({"action": "status", "id": did}, tok)
    a = v.get("audio") or {}
    if a.get("total") and a.get("done") == a.get("total"):
        break
    time.sleep(2)
st, sh = call({"action": "share", "id": did}, tok)
tok2 = T.signup(True)[0]
st, c = call({"action": "import", "code": sh.get("code")}, tok2)
check("importera kopian (testkonto 2)", st == 200, st)
for k, d in ((tok, did), (tok, t["drill"]["id"]), (tok2, (c.get("drill") or {}).get("id"))):
    if d:
        call({"action": "delete", "id": d}, k)
END = dt.datetime.now(dt.timezone.utc)
print(f"\n=== O70 {sum(OK)}/{len(OK)} ok, märkord {MARK}, fönster {START.isoformat()} – {END.isoformat()}")
print(f"SQL: select count(*) from qa_log where question ilike '%{MARK}%' or answer ilike '%{MARK}%';")
print(f"SQL: select mode, count(*) from qa_log where created_at between '{START.isoformat()}' and '{END.isoformat()}' group by 1;")
sys.exit(0 if all(OK) else 1)
