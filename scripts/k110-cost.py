"""K110 (D241, Kevin moln 2026-11-19): what an exam really costs per question, against the estimate, on Oscar's five
materials (Vasa = Lübeck, printing included), the app's way (drill with answers false, then drill_answers may_fix), with
3 questions (what a new account fits) and 12 (the app's default after A154). The cost is the server's own (drill action
"cost", nothing saved). Also: long-answer words (the K110 cap), characters per word, question length, Lübeck and
"framgår inte" in the answers, and full exams. Test accounts from Actions (D240), 0 ElevenLabs. Claude about 0.25 USD.
Usage (kevin-live.yml): python -X utf8 scripts/k110-cost.py"""
import sys as _s, pathlib as _p
HERE = _p.Path(__file__).resolve().parent
_s.path.insert(0, str(HERE / "qa"))
import qa_testaccount as T  # noqa: E402
T.install()
import json, re, time, urllib.error, urllib.request  # noqa: E402
_s.path.insert(0, str(HERE / "qa" / "o79"))
_s.path.insert(0, str(HERE / "qa" / "repetition_bank"))
from o79_materials import O79  # noqa: E402


def photo_pages(m, eid):  # as k102-measure.py
    import base64, tempfile
    from make_files import photo  # noqa: PLC0415
    pages = []
    with tempfile.TemporaryDirectory() as d:
        for n, (h, p) in enumerate(m["parts"]):
            path = f"{d}/p{n}.jpg"
            photo(f"{h}\n{p}", path, seed=f"{eid}-{n}")
            pages.append({"media_type": "image/jpeg", "data": base64.b64encode(open(path, "rb").read()).decode()})
    return pages


sys = _s
sys.stdout.reconfigure(encoding="utf-8")
NA = re.compile(r"framgår inte|inte känt|förklaras inte|beskrivs inte|står inte här|is not (explained|stated|known|described)", re.I)


def call(fn, body, tok):
    r = urllib.request.Request(T.URL + "/functions/v1/" + fn, data=json.dumps(body).encode(), method="POST", headers=T.headers(tok, True))
    r.add_header("x-earmind-test", "kevin-k110")
    for _ in range(3):
        try:
            with urllib.request.urlopen(r, timeout=240) as x:
                return x.status, json.loads(x.read() or b"{}")
        except urllib.error.HTTPError as e:
            if e.code in (502, 503, 504):
                time.sleep(10)
                continue
            return e.code, json.loads(e.read() or b"{}")
    return 599, {}


def words(t):
    return len(re.findall(r"\S+", t or ""))


# K110/T55 (Angela Fable 2026-11-20): Toby's case, a 39-word text with 3 questions; every item printed (lengths only)
SHORT = "--short39" in sys.argv
if SHORT:
    O79 = {"t55-39ord": {"subject": "Biologi", "format": "text", "parts": [("Fotosyntes", "Fotosyntesen sker i växternas blad. Med hjälp av ljus, vatten och koldioxid bildar växten glukos och syre. Klorofyllet fångar ljuset. Glukosen används som energi och byggmaterial, och syret släpps ut genom klyvöppningarna i bladen.")]}}
rows = []
for eid, m in O79.items():
    for n in ((3, 3) if SHORT else (3, 12)):
        tok = T.signup(True)[0]
        body = {"action": "drill", "answers": False, "questions": n, "subject": m["subject"]}
        body |= {"pages": photo_pages(m, eid), "text": ""} if m["format"] == "photo" else {"pages": [], "text": "\n\n".join(f"{h}\n\n{p}" for h, p in m["parts"])}
        st, plan = call("exam", body, tok)
        if st != 200:
            rows.append({"eid": eid, "n": n, "error": st})
            print("FEL", eid, n, st, plan.get("error"), flush=True)
            continue
        sa, ans = call("exam", {"action": "drill_answers", "may_fix": True, "items": plan["items"], "notes": plan.get("notes"),
                                "subject": plan["summary"]["subject"], "grade": plan["summary"]["grade"]}, tok)
        its = [i for i in (ans.get("items") or []) if i.get("long")]
        save = [{k: i[k] for k in ("question", "short", "long") if i.get(k)} for i in its]
        sc, c = call("drill", {"action": "cost", "drill": {"title": f"K110 {eid}", "subject": m["subject"]}, "items": save}, tok)
        q = len(its) or 1
        row = {"eid": eid, "asked": n, "got": len(its), "cost": c.get("cost"), "per_q": round((c.get("cost") or 0) / q),
               "q_chars": round(sum(len(i["question"]) for i in its) / q), "long_chars": round(sum(len(i["long"]) for i in its) / q),
               "long_words_max": max((words(i["long"]) for i in its), default=0),
               "cpw": round(sum(len(i["long"]) for i in its) / max(1, sum(words(i["long"]) for i in its)), 2),
               "lubeck": [i["question"] for i in its if "Lübeck" in i["question"]],
               "not_answered": [i["question"] for i in its if NA.search(i.get("long", ""))]}
        rows.append(row)
        print(json.dumps(row, ensure_ascii=False), flush=True)
        if SHORT:
            for i in its:
                print("   item", json.dumps({"q_chars": len(i["question"]), "short_words": words(i.get("short", "")), "long_words": words(i["long"]),
                                          "long_chars": len(i["long"]), "long_starts_with_short": i["long"].startswith(i.get("short", "")),
                                          "screen_long_chars": len((i.get("screen") or {}).get("long") or "")}), flush=True)
ok = [r for r in rows if "per_q" in r]
print("=== K110", json.dumps({"per_q_max": max(r["per_q"] for r in ok), "q_chars_max": max(r["q_chars"] for r in ok),
                             "cpw_max": max(r["cpw"] for r in ok), "long_words_max": max(r["long_words_max"] for r in ok),
                             "full": [(r["eid"][4:], r["asked"], r["got"]) for r in ok], "not_answered": sum(len(r["not_answered"]) for r in ok),
                             "lubeck": [x for r in ok for x in r["lubeck"]]}, ensure_ascii=False), flush=True)
json.dump(rows, open(HERE.parent / "reports" / "qa" / "data" / (time.strftime("%Y-%m-%d-%H%M%S") + "-k110-cost.json"), "w", encoding="utf8"), ensure_ascii=False, indent=1)
