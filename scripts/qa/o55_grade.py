#!/usr/bin/env python3
"""Oscar O55/O55a: bedömning av repetitionslägets frågor och svar (R2–R4, R10), mot testbanken i
scripts/qa/repetition_bank/ (påhittade prov, aldrig elevtext). 0 ElevenLabs.

Per fråga/svar-par (item):
  i kod   q_words <= 8 (R3, hård), <= 5 (R3, mjuk), ja/nej-fråga, förståelsefråga (varför/hur/jämför ...),
          utanför materialet (frågans innehållsord saknas i materialet OCH det korta svaret vilar till < 35 % på
          materialets ord, gräns 0,35 efter kalibreringen), D145 (långt börjar ordagrant med kort), långt svar 40–108 ord (D146: ~90, högst en femtedel över)
  domare  /provlage-eval grade med Sonnet (samma domare som D87-natten): långt svar correct + a_level,
          kort svar correct. correct = 0 räknas som faktafel och läses för hand innan det rapporteras.
  item_ok = allt ovan.
Per prov (lista):
  R2 ämne/årskurs, täckning av lärandemålen (ett mål räknas som täckt när en fråga + dess korta svar innehåller
     minst hälften av målets nyckelord, minst ett), frågor utanför materialet
  R3 andel <= 5 ord (>= 80 %), alla <= 8, andel förståelsefrågor (>= 70 %)
  R4 långa A-nivå och korrekta, korta korrekta
  R10 Claude-kostnad från usage, ElevenLabs-tecken räknade på texten (uppskattning, 0 anrop)

  python -I -X utf8 scripts/qa/o55_grade.py calibrate               -> 20 handskrivna par, ska bli 20/20
  python -I -X utf8 scripts/qa/o55_grade.py baseline [--ids a,b,c]  -> dagens /study-cards + /my-answers suggest
  python -I -X utf8 scripts/qa/o55_grade.py drill [--ids ...]       -> K45 /exam drill + drill_answers (R1–R4, R10)
Resultat: reports/qa/data/<tid>-o55-<läge>.json"""
import sys as _d180s, pathlib as _d180p; _d180s.path.insert(0, str(_d180p.Path(__file__).resolve().parent)); import qa_testaccount; qa_testaccount.install()  # D180: bara testkonton, aldrig riktiga ElevenLabs
import argparse, base64, datetime as dt, json, pathlib, re, sys, time, urllib.error, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
BANK = ROOT / "scripts/qa/repetition_bank"
sys.path.insert(0, str(BANK))
from materials import M  # noqa: E402
from materials_holdout import H  # noqa: E402  (O55b: hållout, inte i exams.json)
M.update(H)
from materials_holdout2 import H2  # noqa: E402  (O60)
M.update(H2)
from materials_holdout3 import H3  # noqa: E402  (O63)
M.update(H3)

URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # publik nyckel (finns i appen och i Kevins skript)
EL_PRICE = 0.08 / 1000  # USD per tecken, Multilingual v2/v3 (verifierat i docs 2026-11-13, specen §6)

STOP = set("""varför vilken vilket vilka vilkas vad hur när var vem vems kan kunde finns fanns gör görs gjorde gör
blir blev bli vara är var varit har hade ska skulle bör måste får fick kallas kallar betyder betydde fungerar
fungerade leder ledde visar visade händer hände sker skedde skiljer skillnad mellan jämför jämfört förklara beskriv
olika några någon något många mycket mer mest mindre minst andra annan annat detta denna dessa det den de som och
eller men för från till med utan inom under över efter före genom om på av i en ett att sig sin sitt sina deras
man när då så också bara alltid aldrig ofta egentligen viktig viktigt viktiga roll sätt följden följder orsak
orsaker exempel""".split())
UNDERSTANDING = re.compile(r"^(varför|hur|vad händer|vad hände|vad skiljer|vad blir|vad gör att|jämför|skillnad|"
                           r"förklara|beskriv hur|vilken roll|vilka följder|vilka orsaker|på vilket sätt|why|how|"
                           r"what happens|what is the difference|explain|compare)", re.I)
YESNO = re.compile(r"^(är|kan|finns|fanns|har|hade|blir|blev|gäller|går|får|ska|skulle|bör|måste|stämmer|var|"
                   r"behöver|brukar|is|are|can|does|do|did|was|were|has|have)\b", re.I)
WORD = re.compile(r"[\wåäöÅÄÖéü]+")


def words(s):
    return WORD.findall(s or "")


def stem(w):
    w = w.lower()
    return w[:5] if len(w) > 5 else w


def material_stems(eid):
    return {stem(w) for w in words(" ".join(M[eid]["pages"]))}


def content(s):
    return [w for w in words(s) if len(w) >= 4 and w.lower() not in STOP and not w.isdigit()]


def code_checks(eid, q, short, long_, mstems):
    qw = len(words(q))
    unknown = [w for w in content(q) if stem(w) not in mstems]
    sc = content(short)
    grounded_short = sum(stem(w) in mstems for w in sc) / len(sc) if sc else 0
    lw = len(words(long_))
    return {
        "q_words": qw, "q_le5": qw <= 5, "q_le8": qw <= 8,
        "yesno": bool(YESNO.match(q.strip())), "understanding": bool(UNDERSTANDING.match(q.strip())),
        "q_unknown": unknown, "short_grounded": round(grounded_short, 2),
        "outside": bool(unknown) and grounded_short < 0.35,
        "q_le6": qw <= 6, "short_words": len(words(short)),
        "short_sentences": len(re.findall(r"[.!?](?:\s|$)", short.strip())) or (1 if short.strip() else 0),
        "empty": not short.strip() or not long_.strip(),
        "d145": bool(short) and long_.startswith(short.strip()),
        "long_words": lw, "long_len_ok": 40 <= lw <= 108,
    }


def call(path, body, tok, timeout=180):
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
    t0 = time.time()
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.load(r), time.time() - t0
        except urllib.error.HTTPError as e:
            body_ = e.read().decode()[:300]
            if e.code == 429 and attempt < 3:
                wait = 20
                try:
                    wait = int(json.loads(body_)["error"].get("retryAfterSec", 20)) + 1
                except Exception:
                    pass
                print(f"  429, väntar {wait} s", flush=True)
                time.sleep(min(wait, 70))
                continue
            raise RuntimeError(f"{path} HTTP {e.code}: {body_}")
        except (TimeoutError, urllib.error.URLError, ConnectionError) as e:
            if attempt < 3:
                print(f"  {type(e).__name__}, försöker igen", flush=True)
                time.sleep(5)
                continue
            raise


class Session:
    """En anonym testanvändare för hela körningen (exam 300/dygn, domaren 700/dygn per användare). Token sparas i
    O55_TOKEN_FILE (standard: %TEMP%/o55_token.json) och förnyas med refresh token; ny registrering bara när det
    saknas en, eftersom anonyma registreringar har tak per IP (429 i första körningen)."""

    def __init__(self):
        import os
        self.file = pathlib.Path(os.environ.get("O55_TOKEN_FILE") or (pathlib.Path(os.environ.get("TEMP", "/tmp")) / "o55_token.json"))
        self.tok, self.refresh, self.t = None, None, 0
        try:
            d = json.loads(self.file.read_text())
            self.tok, self.refresh, self.t = d["access"], d["refresh"], d["t"]
        except Exception:
            pass

    def _auth(self, path, body):
        for attempt in range(8):
            req = urllib.request.Request(URL + path, data=json.dumps(body).encode(), method="POST",
                                         headers={"apikey": KEY, "content-type": "application/json"})
            try:
                return json.load(urllib.request.urlopen(req))
            except urllib.error.HTTPError as e:
                if e.code != 429 or attempt == 7:
                    raise
                print("  auth 429, väntar 60 s", flush=True)
                time.sleep(60)

    def token(self):
        if self.tok and time.time() - self.t < 45 * 60:
            return self.tok
        j = None
        if self.refresh:
            try:
                j = self._auth("/auth/v1/token?grant_type=refresh_token", {"refresh_token": self.refresh})
            except urllib.error.HTTPError:
                j = None
        if not j:
            j = self._auth("/auth/v1/signup", {})
        self.tok, self.refresh, self.t = j["access_token"], j["refresh_token"], time.time()
        self.file.write_text(json.dumps({"access": self.tok, "refresh": self.refresh, "t": self.t}))
        return self.tok


S = Session()
COST = {"judge": 0.0, "claude": 0.0}


def judge(eid, q, answer, expect, kind):
    m = M[eid]
    case = {"grade": m["grade"] or "högstadiet", "subject": m["subject"], "q": q, "expect": expect,
            "profile": "Utförliga förklaringar" if kind == "long" else "Korta förklaringar"}
    time.sleep(1.6)
    j, _ = call("/functions/v1/provlage-eval", {"action": "grade", "judge": "sonnet", "case": case, "answer": answer}, S.token())
    COST["judge"] += j.get("usage", {}).get("est_cost_usd", 0)
    s = j.get("scores", {})
    return {"correct": s.get("correct", 0), "a_level": s.get("a_level", 0), "sufficient": s.get("sufficient", 0),
            "covers": s.get("covers", 0), "note": j.get("note", "")}


def best_goal(eid, text):
    t = text.lower()
    best, hits = None, 0
    for g, goal, kws in M[eid]["goals"]:
        h = sum(k.lower() in t for k in kws)
        if h > hits:
            best, hits = (g, goal, kws), h
    return best


def grade_item(eid, q, short, long_, mstems, goal_id=None, use_judge=True):
    c = code_checks(eid, q, short, long_, mstems)
    g = next((x for x in M[eid]["goals"] if x[0] == goal_id), None) if goal_id else best_goal(eid, q + " " + short)
    expect = f"{g[1]} (nyckelord: {', '.join(g[2])}). Allt ska stämma med studiematerialet." if g else ""
    r = {"goal": g[0] if g else "", **c}
    if use_judge:
        jl = judge(eid, q, long_, expect, "long")
        js = judge(eid, q, short, "", "short")
        r.update({"long_correct": jl["correct"], "long_a_level": jl["a_level"], "long_note": jl["note"],
                  "short_correct": js["correct"], "short_note": js["note"]})
    fails = []
    if c["empty"]: fails.append("tomt svar")
    if not c["q_le8"]: fails.append("fråga > 8 ord")
    if c["yesno"]: fails.append("ja/nej-fråga")
    if c["outside"]: fails.append(f"utanför materialet {c['q_unknown']}")
    if not c["d145"]: fails.append("D145")
    if not c["long_len_ok"]: fails.append(f"långt {c['long_words']} ord")
    if use_judge:
        if not r["long_correct"]: fails.append("långt fel")
        if not r["long_a_level"]: fails.append("långt ej A")
        if not r["short_correct"]: fails.append("kort fel")
    r["fails"], r["item_ok"] = fails, not fails
    return r


def coverage(eid, items):
    covered = {}
    for g, goal, kws in M[eid]["goals"]:
        need = max(1, (len(kws) + 1) // 2)
        hit = None
        for it in items:
            t = (it["question"] + " " + it.get("short", "")).lower()
            if sum(k.lower() in t for k in kws) >= need:
                hit = it["question"]
                break
        covered[g] = hit
    return covered


def grade_ok(m, summary):
    """K52/O55b: rätt eller tom, aldrig fel. Gamla banken (utan grade_ok) kräver exakt årskurs."""
    if summary is None:
        return False
    g = (summary.get("grade") or "").replace(" ", "").lower()
    if "grade_ok" not in m:
        return g == m["grade"].replace(" ", "").lower()
    return g == "" or g in {x.replace(" ", "").lower() for x in (m["grade_ok"] or [])}


def list_report(eid, items, graded, summary=None):
    n = len(items)
    cov = coverage(eid, items)
    m = M[eid]
    r = {
        "id": eid, "n": n,
        "subject_ok": summary is not None and summary.get("subject", "").lower() == m["subject"].lower(),
        "grade_ok": grade_ok(m, summary),
        "grade_read": bool(summary and (summary.get("grade") or "").strip()),
        "empty": sum(x.get("empty", False) for x in graded),
        "q_le6": round(sum(x.get("q_le6", False) for x in graded) / n, 2) if n else 0,
        "short_words_p50": sorted(x.get("short_words", 0) for x in graded)[n // 2] if n else 0,
        "short_le25": sum(x.get("short_words", 0) <= 25 for x in graded),
        "summary": summary,
        "coverage": round(sum(1 for v in cov.values() if v) / len(cov), 2), "missed_goals": [g for g, v in cov.items() if not v],
        "outside": sum(x["outside"] for x in graded),
        "q_le5": round(sum(x["q_le5"] for x in graded) / n, 2) if n else 0, "q_le8_all": all(x["q_le8"] for x in graded),
        "understanding": round(sum(x["understanding"] for x in graded) / n, 2) if n else 0,
        "yesno": sum(x["yesno"] for x in graded),
        "d145": sum(x["d145"] for x in graded),
        "long_words_p50": sorted(x["long_words"] for x in graded)[n // 2] if n else 0,
        "long_words_max": max((x["long_words"] for x in graded), default=0),
        "items_ok": sum(x["item_ok"] for x in graded),
    }
    if graded and "long_correct" in graded[0]:
        r.update({"long_correct": sum(x["long_correct"] for x in graded), "long_a_level": sum(x["long_a_level"] for x in graded),
                  "short_correct": sum(x["short_correct"] for x in graded)})
    # R10: ElevenLabs-tecken om allt blir ljud (D145: kort = början av långt, alltså fråga + långt)
    r["el_chars"] = sum(len(it["question"]) + len(it.get("long", "")) for it in items)
    r["el_usd_est"] = round(r["el_chars"] * EL_PRICE, 3)
    return r


def out_path(mode):
    p = ROOT / "reports/qa/data"
    p.mkdir(parents=True, exist_ok=True)
    return p / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + f"-o55-{mode}.json")


def calibrate(_a):
    C = json.loads((BANK / "o55_calibration.json").read_text(encoding="utf-8"))["items"]
    rows, right = [], 0
    out = out_path("calibrate")
    for it in C:
        mst = material_stems(it["exam"])
        g = grade_item(it["exam"], it["question"], it["short"], it["long"], mst, goal_id=it.get("goal") or None)
        verdict = "good" if g["item_ok"] else "bad"
        ok = verdict == it["label"]
        right += ok
        rows.append({**it, "verdict": verdict, "agree": ok, **g})
        print(f"{'OK ' if ok else 'MISS'} {it['label']:4s} -> {verdict:4s} | {it['question'][:50]:50s} | {', '.join(g['fails']) or '-'}"
              + (f" | väntat: {it['defect']}" if it.get("defect") else ""), flush=True)
        out.write_text(json.dumps({"rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\nKalibrering: {right}/{len(C)} rätt, domare {COST['judge']:.3f} USD -> {out}")


def material_text(eid):
    return "\n\n".join(M[eid]["pages"])


def baseline(a):
    ids = a.ids.split(",") if a.ids else ["bio-ak8-fotosyntes", "ke1-mol", "hist-ak9-forsta-varldskriget"]
    out, res = out_path("baseline"), []
    for eid in ids:
        m, mst = M[eid], material_stems(eid)
        t0 = time.time()
        cards, t_cards = None, 0
        for attempt in range(2):
            try:
                cards, t_cards = call("/functions/v1/study-cards", {"summary": material_text(eid)[:6000], "cards": 12,
                                      "profile": f"Ämne: {m['subject']}. Årskurs: {m['grade']}.", "language": "sv"}, S.token())
                break
            except RuntimeError as e:
                print(f"  study-cards försök {attempt + 1}: {e}", flush=True)
                time.sleep(20)
        if cards is None:
            res.append({"list": {"id": eid, "error": "study-cards 502 cards_failed två gånger"}, "items": []})
            continue
        COST["claude"] += cards.get("usage", {}).get("est_cost_usd", 0)
        items = []
        for c in cards.get("cards", []):
            time.sleep(1.0)
            sug, _ = call("/functions/v1/my-answers", {"action": "suggest", "q": c["q"], "subject": m["subject"], "grade": m["grade"],
                          "exam": m["topic"]}, S.token())
            COST["claude"] += sug.get("usage", {}).get("est_cost_usd", 0)
            items.append({"question": c["q"], "short": c["a"], "long": sug.get("answer", "")})
        t_total = time.time() - t0
        graded = []
        for it in items:
            g = grade_item(eid, it["question"], it["short"], it["long"], mst)
            graded.append(g)
            print(f"  {'ok ' if g['item_ok'] else 'BAD'} {it['question'][:55]:55s} | {', '.join(g['fails']) or '-'}", flush=True)
        lr = list_report(eid, items, graded)
        lr.update({"t_total_s": round(t_total, 1), "t_cards_s": round(t_cards, 1)})
        res.append({"list": lr, "items": [{**it, **g} for it, g in zip(items, graded)]})
        print(f"{eid}: {lr['n']} frågor, täckning {lr['coverage']:.0%}, utanför {lr['outside']}, <=5 ord {lr['q_le5']:.0%}, "
              f"förståelse {lr['understanding']:.0%}, långa korrekta {lr.get('long_correct')}/{lr['n']}, A {lr.get('long_a_level')}/{lr['n']}, "
              f"korta korrekta {lr.get('short_correct')}/{lr['n']}, D145 {lr['d145']}/{lr['n']}, {t_total:.0f} s", flush=True)
        out.write_text(json.dumps({"mode": "baseline", "cost": COST, "results": res}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Claude {COST['claude']:.3f} USD, domare {COST['judge']:.3f} USD -> {out}")


def drill_material(eid, tok):
    folder = BANK / "files" / eid
    pages, texts = [], []
    for fmt, idx in M[eid]["formats"]:
        if fmt == "photo":
            for n, _i in enumerate(idx, 1):
                pages.append({"media_type": "image/jpeg", "data": base64.b64encode((folder / f"p{n:02d}.jpg").read_bytes()).decode()})
        elif fmt == "docx":
            j, _ = call("/functions/v1/exam", {"action": "doc_text", "data": base64.b64encode((folder / "material.docx").read_bytes()).decode()}, tok)
            texts.append(j["text"])
        else:  # pdf (textlagret läses på telefonen) och text
            texts.extend(M[eid]["pages"][i] for i in idx)
    return pages, "\n\n".join(texts)


def drill(a):
    ids = a.ids.split(",") if a.ids else list(M)
    out, res = out_path("drill" + (f"-{a.tag}" if a.tag else "")), []
    for eid in ids:
        mst = material_stems(eid)
        tok = S.token()
        pages, text = drill_material(eid, tok)
        body = {"action": "drill", "pages": pages, "text": text, "answers": False}
        if a.questions:
            body["questions"] = a.questions
        t0 = time.time()
        plan, t_plan = call("/functions/v1/exam", body, tok)
        COST["claude"] += plan.get("usage", {}).get("est_cost_usd", 0) or plan.get("usage", {}).get("plan", {}).get("est_cost_usd", 0)
        ans, t_ans = call("/functions/v1/exam", {"action": "drill_answers", "items": plan["items"], "notes": plan["notes"],
                          "subject": plan["summary"]["subject"], "grade": plan["summary"]["grade"]}, tok)
        COST["claude"] += ans.get("usage", {}).get("est_cost_usd", 0)
        t_total = time.time() - t0
        items = [{"question": i["question"], "short": i.get("short", "") or "", "long": i.get("long", "") or "",
                  "error": i.get("error")} for i in ans["items"]]
        graded = []
        for it in items:
            g = grade_item(eid, it["question"], it["short"], it["long"], mst, use_judge=not a.no_judge)
            graded.append(g)
            print(f"  {'ok ' if g['item_ok'] else 'BAD'} {it['question'][:55]:55s} | {', '.join(g['fails']) or '-'}", flush=True)
        lr = list_report(eid, items, graded, plan["summary"])
        lr.update({"questions_asked": plan.get("questions_asked"), "questions_possible": plan.get("questions_possible"),
                   "note": plan.get("note"), "max_q": M[eid].get("max_q"), "item_errors": sum(bool(i.get("error")) for i in items),
                   "photos": len(pages), "text_chars": len(text), "t_questions_s": round(t_plan, 1), "t_answers_s": round(t_ans, 1),
                   "t_total_s": round(t_total, 1), "claude_usd": round((plan.get("usage", {}).get("est_cost_usd") or 0) + (ans.get("usage", {}).get("est_cost_usd") or 0), 4),
                   "usage_plan": plan.get("usage"), "usage_answers": ans.get("usage")})
        res.append({"list": lr, "notes": plan.get("notes"), "items": [{**it, **g} for it, g in zip(items, graded)]})
        print(f"{eid}: {lr['summary']['subject']}/{lr['summary']['grade']} ({'ok' if lr['subject_ok'] and lr['grade_ok'] else 'FEL'}), "
              f"{lr['n']} frågor på {t_plan:.1f} s + svar {t_ans:.1f} s, täckning {lr['coverage']:.0%} (miss {lr['missed_goals']}), "
              f"utanför {lr['outside']}, <=5 ord {lr['q_le5']:.0%}, förståelse {lr['understanding']:.0%}, långa korrekta "
              f"{lr.get('long_correct')}/{lr['n']}, A {lr.get('long_a_level')}/{lr['n']}, korta {lr.get('short_correct')}/{lr['n']}, "
              f"D145 {lr['d145']}/{lr['n']}, ElevenLabs ~{lr['el_chars']} tecken", flush=True)
        out.write_text(json.dumps({"mode": "drill", "cost": COST, "results": res}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"Claude {COST['claude']:.3f} USD, domare {COST['judge']:.3f} USD -> {out}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["calibrate", "baseline", "drill"])
    ap.add_argument("--ids", default="")
    ap.add_argument("--questions", type=int, default=0)
    ap.add_argument("--tag", default="")
    ap.add_argument("--no-judge", action="store_true")
    a = ap.parse_args()
    {"calibrate": calibrate, "baseline": baseline, "drill": drill}[a.mode](a)


if __name__ == "__main__":
    main()
