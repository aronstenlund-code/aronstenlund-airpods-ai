"""O64: omtest av O63 efter Kevins K66. Skrivet av Oscar (QA).
  python -I -X utf8 scripts/qa/o64_k66.py onecall <id,id,...>   -> /exam drill med svar i samma anrop (där K66 may_fix gäller)
  python -I -X utf8 scripts/qa/o64_k66.py check <drill.json> ...  -> de fem K66-punkterna, maskinellt, per fil
  python -I -X utf8 scripts/qa/o64_k66.py save <drill.json>       -> spara (testkonto, falskt ljud), length_class och screen, ta bort
Via testkonto (o55_grade installerar qa_testaccount): inga ElevenLabs-anrop. Bara Claude.
Resultat: reports/qa/data/<tid>-o64-*.json"""
import datetime as dt, json, pathlib, re, sys

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import o55_grade as G  # noqa: E402  (installerar D180-skyddet)

MATERIAL = re.compile(r"(?<![^\W\d_])(materialet|i texten|enligt texten|anteckningarna|enligt boken|i boken|the material|"
                      r"the text says|according to the text)(?![^\W\d_])", re.I)
GROUP = re.compile(r"\b(alla|alltid|aldrig|inga|kan alltså vara|all|always|never|no)\b", re.I)
NUM_WORDS = re.compile(r"\b(hundra|tusen|komma|i kvadrat|kvadrat|delat med|gånger|procent|hundred|thousand|point|squared|per cent|percent)\b", re.I)
SWEDISH = re.compile(r"\b(och|är|det|som|att|för|inte|med|på|har|vad|varför|hur)\b", re.I)
ENGLISH = re.compile(r"\b(the|and|is|are|what|why|how|does|of|to|in|he|his)\b", re.I)


def stem(w):
    return re.sub(r"[^\w]", "", w.lower())[:5]


def circular(q, short):  # samma regel som Kevins isCircular, så att jag ser vad servern släpper igenom
    if not re.match(r"^(varför|why)\b", q.strip(), re.I):
        return False
    qs = {stem(w) for w in q.split()}
    fresh = {stem(w) for w in short.split() if len(stem(w)) >= 5 and stem(w) not in qs}
    return len(fresh) < 2


def lang(s):
    sv, en = len(SWEDISH.findall(s)), len(ENGLISH.findall(s))
    return "en" if en > sv else "sv"


def onecall(ids):
    out, res = G.out_path("o64-onecall"), []
    for eid in ids:
        tok = G.S.token()
        pages, text = G.drill_material(eid, tok)
        plan, t = G.call("/functions/v1/exam", {"action": "drill", "pages": pages, "text": text, "questions": 12}, tok)
        G.COST["claude"] += (plan.get("usage") or {}).get("est_cost_usd", 0) or 0
        items = [{"question": i["question"], "short": i.get("short", ""), "long": i.get("long", ""), "screen": i.get("screen")}
                 for i in plan["items"]]
        res.append({"list": {"id": eid, "summary": plan["summary"], "n": len(items), "t_s": round(t, 1)}, "items": items})
        print(f"{eid}: {plan['summary']['subject']}/{plan['summary']['grade']} {len(items)} frågor {t:.0f} s", flush=True)
        out.write_text(json.dumps({"mode": "onecall", "cost": G.COST, "results": res}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Claude {G.COST['claude']:.3f} USD -> {out}")


def check(paths):
    rows = []
    for p in paths:
        d = json.loads(pathlib.Path(p).read_text(encoding="utf-8"))
        for r in d["results"]:
            eid = r["list"]["id"]
            m = G.M[eid]
            mat = G.material_text(eid).lower()
            for it in r["items"]:
                q, s, l, sc = it["question"], it["short"], it["long"], it.get("screen") or {}
                rows.append({
                    "file": pathlib.Path(p).name, "exam": eid, "subject_detected": r["list"]["summary"]["subject"],
                    "question": q, "short": s, "long": l, "screen": sc,
                    "why": bool(re.match(r"^(varför|why)\b", q.strip(), re.I)),
                    "circular": circular(q, s),
                    "mentions_material": bool(MATERIAL.search(f"{s} {l}")),
                    "group_words": sorted({w.lower() for w in GROUP.findall(l)} - {"no"}),
                    "num_words_spoken": bool(NUM_WORDS.search(q + " " + l)),
                    "has_screen": bool(sc),
                    "digits_in_screen": bool(re.search(r"\d|²|·|/|=", " ".join(sc.values()))) if sc else False,
                    "lang_q": lang(q), "lang_long": lang(l), "expect_lang": "en" if m["subject"] == "Engelska" else "sv",
                    "fjarde": "fjärde" in (q + l).lower() and "fjärde" not in mat,
                })
    summ = {}
    for f in sorted({x["file"] for x in rows}):
        xs = [x for x in rows if x["file"] == f]
        summ[f] = {
            "n": len(xs), "why": sum(x["why"] for x in xs), "circular": sum(x["circular"] for x in xs),
            "mentions_material": sum(x["mentions_material"] for x in xs),
            "group_words": sum(bool(x["group_words"]) for x in xs),
            "num_words_spoken": sum(x["num_words_spoken"] for x in xs),
            "num_words_with_screen": sum(x["num_words_spoken"] and x["has_screen"] for x in xs),
            "screens": sum(x["has_screen"] for x in xs),
            "lang_ok": sum(x["lang_q"] == x["expect_lang"] and x["lang_long"] == x["expect_lang"] for x in xs),
            "fjarde": sum(x["fjarde"] for x in xs),
        }
    out = G.ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o64-k66-check.json")
    out.write_text(json.dumps({"summary": summ, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(summ, ensure_ascii=False, indent=1), "->", out)


def save(path):
    """Sparar varje prov med ett nytt testkonto (falskt ljud), läser length_class och screen från servern, tar bort."""
    import qa_testaccount as T
    d = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    res = []
    for r in d["results"]:
        tok, _ = T.signup(True)
        items = [{"question": i["question"], "short": i["short"], "long": i["long"], **({"screen": i["screen"]} if i.get("screen") else {})}
                 for i in r["items"]][:15]
        s_, _, b = T.call("POST", "/functions/v1/drill", {"action": "save", "drill": {"title": "O64 " + r["list"]["id"] + " (QA)",
                          "subject": r["list"]["summary"]["subject"]}, "items": items}, tok)
        g = json.loads(b or b"{}")
        did = (g.get("drill") or {}).get("id")
        s2, _, b2 = T.call("POST", "/functions/v1/drill", {"action": "get", "id": did}, tok)
        g2 = json.loads(b2 or b"{}")
        got = g2.get("items", [])
        sent_screen = sum(bool(i.get("screen")) for i in items)
        back_screen = sum(bool(i.get("screen")) for i in got)
        same = sum(json.dumps(a.get("screen") or {}, sort_keys=True) == json.dumps(b_.get("screen") or {}, sort_keys=True)
                   for a, b_ in zip(items, got))
        row = {"exam": r["list"]["id"], "save": s_, "get": s2, "n": len(got),
               "length_class": [i.get("length_class") for i in got], "voice_chars": [i.get("voice_chars") for i in got],
               "screen_sent": sent_screen, "screen_back": back_screen, "screen_same": same,
               "credits": (g2.get("audio") or {}).get("chars")}
        s3, _, _ = T.call("POST", "/functions/v1/drill", {"action": "delete", "id": did}, tok)
        row["delete"] = s3
        res.append(row)
        print(json.dumps({k: v for k, v in row.items() if k not in ("voice_chars",)}, ensure_ascii=False), flush=True)
    out = G.ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o64-save.json")
    out.write_text(json.dumps(res, ensure_ascii=False, indent=1), encoding="utf-8")
    print("->", out)


if __name__ == "__main__":
    {"onecall": lambda: onecall(sys.argv[2].split(",")), "check": lambda: check(sys.argv[2:]), "save": lambda: save(sys.argv[2])}[sys.argv[1]]()
