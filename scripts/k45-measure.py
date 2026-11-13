#!/usr/bin/env python3
"""K45 live measurement of /exam drill on Oscar's invented test bank (scripts/qa/repetition_bank, never student text).
Per exam: the material as the app sends it (photos as images, a PDF page as text, a .docx through doc_text), then
  1. drill with "answers": false  -> summary + questions (R1: within 30 s)
  2. drill_answers on those questions -> short + long answers (R1: all answers within 90 s of the start)
and the checks done in code: question words (R3: >= 80 % at most 5 words, all at most 8), understanding questions
(starts with varför/hur/vad händer/jämför/skillnad/förklara), D145 (long starts with short), long-answer words,
Claude cost per step (Haiku plan, Sonnet answers). R2/R4 (coverage, A level, facts) are Oscar's (O55).
  python -X utf8 scripts/k45-measure.py [--ids bio-ak8-fotosyntes,ke1-mol] [--out reports/eval]"""
import argparse, base64, datetime, json, pathlib, re, sys, time, urllib.error, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
BANK = ROOT / "scripts" / "qa" / "repetition_bank"
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design
INTRO = re.compile(r"^(?:[\w-]+\s+){0,6}?(?:är en (?:viktig|central|grundläggande|komplex|intressant|avgörande)|handlar om|det finns (?:flera|många|olika|tre|två)|det beror på (?:flera|många)|det är (?:viktigt|intressant) att|det här är|man kan säga att|svaret är att|frågan handlar)(?!\w)", re.I)
UNDERSTANDING = re.compile(r"^(varför|hur|vad händer|vad hände|vad skiljer|jämför|skillnad|förklara|vilken roll|vad betyder .* för|vad gör att|på vilket sätt)", re.I)


def call(path, body, tok, timeout=180):
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r), time.time() - t0


def token():
    req = urllib.request.Request(URL + "/auth/v1/signup", data=b"{}", method="POST", headers={"apikey": KEY, "content-type": "application/json"})
    return json.load(urllib.request.urlopen(req))["access_token"]


def material(e, tok):
    """(pages, text) as the app would send them."""
    folder = BANK / "files" / e["id"]
    pages, texts = [], []
    for f in e["material"]["formats"]:
        if f["format"] == "photo":
            for i in f["pages"]:
                p = folder / f"p{i + 1:02d}.jpg"
                if p.exists():
                    pages.append({"media_type": "image/jpeg", "data": base64.b64encode(p.read_bytes()).decode()})
        elif f["format"] == "docx":
            d = folder / "material.docx"
            j, _ = call("/functions/v1/exam", {"action": "doc_text", "data": base64.b64encode(d.read_bytes()).decode()}, tok)
            texts.append(j["text"])
        else:  # pdf (text layer read on the phone) and text
            texts.extend(e["material"]["pages"][i] for i in f["pages"])
    return pages, "\n\n".join(texts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", default="bio-ak8-fotosyntes,ke1-mol,hist-ak9-forsta-varldskriget")
    ap.add_argument("--out", default=str(ROOT / "reports" / "eval"))
    ap.add_argument("--no-context", action="store_true", help="send no subject or grade (as O55 did): measures the grade reading")
    a = ap.parse_args()
    bank = {e["id"]: e for e in json.load(open(BANK / "exams.json", encoding="utf-8"))}
    rows = []
    out = pathlib.Path(a.out) / f"k45-drill-{datetime.date.today().isoformat()}.json"
    for id_ in a.ids.split(","):
        e = bank[id_]
        tok = token()  # one new user per exam: a drill weighs 4 + 3 in the exam rate limit (12 per minute)
        pages, text = material(e, tok)
        t0 = time.time()
        plan, t_plan = call("/functions/v1/exam", {"action": "drill", "pages": pages, "text": text, **({} if a.no_context else {"subject": e["subject"], "grade": e["grade"]}), "answers": False}, tok)
        items = plan["items"]
        ans, t_ans = call("/functions/v1/exam", {"action": "drill_answers", "items": items, "notes": plan["notes"],
                                                "subject": plan["summary"]["subject"], "grade": plan["summary"]["grade"]}, tok)
        total = time.time() - t0
        qs = [i["question"] for i in items]
        wq = [len(q.split()) for q in qs]
        longs = [i.get("long", "") for i in ans["items"]]
        shorts = [i.get("short", "") for i in ans["items"]]
        row = {
            "id": id_, "photos": len(pages), "text_chars": len(text),
            "summary": plan["summary"], "grade_expected": e["grade"], "questions": len(qs),
            "t_questions_s": round(t_plan, 1), "t_answers_s": round(t_ans, 1), "t_total_s": round(total, 1),
            "q_le5": sum(w <= 5 for w in wq), "q_le8": sum(w <= 8 for w in wq),
            "q_understanding": sum(bool(UNDERSTANDING.search(q)) for q in qs),
            "answered": sum(bool(s) for s in shorts),
            "d145": sum(l.startswith(s) for s, l in zip(shorts, longs) if s),
            "long_words_p50": sorted(len(l.split()) for l in longs)[len(longs) // 2] if longs else 0,
            "long_words_max": max((len(l.split()) for l in longs), default=0),
            "short_words_max": max((len(s.split()) for s in shorts), default=0),
            "short_words_p50": sorted(len(s.split()) for s in shorts)[len(shorts) // 2] if shorts else 0,
            "short_le25": sum(1 for s in shorts if s and len(s.split()) <= 25),
            "short_intro": sum(1 for s in shorts if s and INTRO.search(s)),
            "chars_short": sum(len(s) for s in shorts), "chars_long": sum(len(l) for l in longs), "chars_questions": sum(len(q) for q in qs),
            "cost_plan_usd": plan["usage"]["plan"]["est_cost_usd"], "cost_answers_usd": ans["usage"]["est_cost_usd"],
            "items": [{"question": q, "short": s, "long": l} for q, s, l in zip(qs, shorts, longs)],
        }
        row["cost_claude_usd"] = round(row["cost_plan_usd"] + row["cost_answers_usd"], 4)
        rows.append(row)
        out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"{id_}: {len(qs)} frågor på {t_plan:.1f} s, svar {t_ans:.1f} s (totalt {total:.1f} s), "
              f"<=5 ord {row['q_le5']}/{len(qs)}, förståelse {row['q_understanding']}/{len(qs)}, D145 {row['d145']}/{row['answered']}, "
              f"kort p50 {row['short_words_p50']} ord, <=25 {row['short_le25']}/{row['answered']}, inledningar {row['short_intro']}, "
              f"årskurs {plan['summary'].get('grade')!r} (rätt {e['grade']!r}), tomma svar {sum(1 for s_ in shorts if not s_)}, "
              f"långt p50 {row['long_words_p50']} ord (max {row['long_words_max']}), Claude {row['cost_claude_usd']:.3f} USD")
    print("->", out)


if __name__ == "__main__":
    sys.exit(main())
