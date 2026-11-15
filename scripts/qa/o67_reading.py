"""O67: läsläget på servern (D185/D187, K70). Skrivet av Oscar (moln) 2026-11-15. Kör i Actions (oscar-live.yml):
  python -I -X utf8 scripts/qa/o67_reading.py
Bara testkonton (qa_testaccount.install(): testhuvud på varje anrop, direkta ElevenLabs-anrop vägras), 0 ElevenLabs.
Claude: bara /exam read (Haiku), cirka 0,01 USD per text.

Kontroller (ok / FEL / obs):
  A  städningen: skräp bort (sidnummer, sidhuvud, "Sida 3 av 8", copyright), avstavning och OCR lagade, och ORD FÖR ORD
     samma som det förväntade innehållet (difflib över orden: saknade och tillagda ord listas). Inget kortat.
  B  meningsdelningen: serverns meningar (status.items[].sentences) mot de förväntade, med förkortningar (t.ex., bl.a.,
     ca., kap., s., Dr., e.Kr., osv.), siffror (1850, 3,5, 1.2), initialer och citat.
  C  tidsstämplarna: lika många tider som meningar per del, start <= slut, stigande, sista slut <= duration_ms.
  D  kvoten: counts_as = ceil(chars/800) i read; generated_questions i save = ceil(new_chars/800); kvoten (action quota)
     ökar med just det; samma text igen på ett nytt konto kostar 0 (D144).
  E  delning (share -> import: kind text, new_chars 0, samma delar) och publicering (publish -> search hittar, kind text,
     unpublish, delete).
SQL efteråt (Supabase MCP) står i resultatfilen: alla nya ljudfiler ska ha teströsten och 0 krediter."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import datetime as dt, difflib, json, math, pathlib, random, re, sys, time, urllib.error  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
DATA = ROOT / "reports/qa/data"
START = dt.datetime.now(dt.timezone.utc)
CHECKS, COST = [], {"claude": 0.0}
_W = "äpple björk citron dalgång ekorre fjäll gran hassel igelkott jordgubbe kastanj lärk mossa nypon olvon pil rönn sälg tall vass".split()
NONCE = " ".join(random.Random(START.timestamp()).sample(_W, 3))  # nya hashar varje körning (D144)


def check(area, name, ok, detail="", obs=False):
    CHECKS.append({"area": area, "check": name, "ok": bool(ok), "obs": bool(obs and not ok), "detail": str(detail)[:600]})
    tag = "ok   " if ok else ("obs  " if obs else "FEL  ")
    print(f"{tag}{area} {name}" + (f" | {str(detail)[:220]}" if detail else ""), flush=True)


def call(fn, body, tok, timeout=180):
    for _ in range(4):
        try:
            st, _, raw = T.call("POST", f"/functions/v1/{fn}", body, tok, timeout=timeout)
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            print("  nätfel, försöker igen:", e, flush=True)
            time.sleep(5)
            continue
        if st in (429, 502, 503, 504):
            print(f"  {fn} {st}, väntar 20 s", flush=True)
            time.sleep(20)
            continue
        try:
            return st, json.loads(raw or b"{}")
        except ValueError:
            return st, {"raw": raw[:300].decode("utf8", "replace")}
    return st, {}


def signup():
    for _ in range(5):
        try:
            return T.signup(True)[0]
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            print("  registrering 429, väntar 60 s", flush=True)
            time.sleep(60)
    raise SystemExit("kan inte registrera testkonto")


def spend(j):
    u = (j or {}).get("usage") or {}
    c = u.get("est_cost_usd")
    if c is None:  # /exam read: usage kan ligga per steg
        c = sum(float((x or {}).get("est_cost_usd") or 0) for x in (u.get("steps") or j.get("steps") or []))
    COST["claude"] += float(c or 0)
    if not c:
        print("  usage:", json.dumps(u, ensure_ascii=False)[:200], flush=True)


# ---------- materialet: råtext (som en dålig inskanning) och vad som ska bli kvar ----------
RAW_SV = f"""Biologi åk 8 – Kapitel 3                                    Sida 12
# Fotosyntesen

Växter bildar glukos av koldioxid och vatten med hjälp av ljus. Det sker i klorofyll-
korn, som finns i bladens celler, t.ex. i palissadcellerna. Syre blir över och släpps ut. Dagens ord är {NONCE}.

Redan år 1771 visade J. Priestley att växter "förbättrar" luften. År 1850 visste man mer. Enligt kap. 4 i boken, s. 18, är
fotosyntcs den viktigaste processen på jorden. Den binder bl.a. kol, kväve osv. Nästa stycke handlar om energi.

Biologi åk 8 – Kapitel 3                                    Sida 13
© 2024 Läromedelsförlaget AB. Får ej kopieras.
# Cellandning

Cellandningen är fotosyntesens motsats. Glukos och syre blir koldioxid, vatten och energi. Temperaturen i en
muskel kan stiga ca. 3,5 grader vid hårt arbete. Hon sa: "Musklerna behöver syre." Sedan sprang hon vidare.
"Varför?" frågade han. Dr. Ek svarade att det beror på mjölksyra.

Sida 3 av 8
"""
# Det som ska läsas upp, ord för ord (avstavning och OCR lagade, skräp borta)
EXPECT_SV = f"""Fotosyntesen
Växter bildar glukos av koldioxid och vatten med hjälp av ljus. Det sker i klorofyllkorn, som finns i bladens celler,
t.ex. i palissadcellerna. Syre blir över och släpps ut. Dagens ord är {NONCE}.
Redan år 1771 visade J. Priestley att växter "förbättrar" luften. År 1850 visste man mer. Enligt kap. 4 i boken, s. 18, är
fotosyntes den viktigaste processen på jorden. Den binder bl.a. kol, kväve osv. Nästa stycke handlar om energi.
Cellandning
Cellandningen är fotosyntesens motsats. Glukos och syre blir koldioxid, vatten och energi. Temperaturen i en
muskel kan stiga ca. 3,5 grader vid hårt arbete. Hon sa: "Musklerna behöver syre." Sedan sprang hon vidare.
"Varför?" frågade han. Dr. Ek svarade att det beror på mjölksyra."""
JUNK_SV = ["Sida 12", "Sida 13", "Kapitel 3", "Sida 3 av 8", "Läromedelsförlaget", "kopieras", "klorofyll-", "fotosyntcs"]
SENT_SV = [
    "Fotosyntesen",
    "Växter bildar glukos av koldioxid och vatten med hjälp av ljus.",
    "Det sker i klorofyllkorn, som finns i bladens celler, t.ex. i palissadcellerna.",
    "Syre blir över och släpps ut.",
    f"Dagens ord är {NONCE}.",
    'Redan år 1771 visade J. Priestley att växter "förbättrar" luften.',
    "År 1850 visste man mer.",
    "Enligt kap. 4 i boken, s. 18, är fotosyntes den viktigaste processen på jorden.",
    "Den binder bl.a. kol, kväve osv.",  # osv. sist i meningen: ska delas (det svåra fallet)
    "Nästa stycke handlar om energi.",
    "Cellandning",
    "Cellandningen är fotosyntesens motsats.",
    "Glukos och syre blir koldioxid, vatten och energi.",
    "Temperaturen i en muskel kan stiga ca. 3,5 grader vid hårt arbete.",
    'Hon sa: "Musklerna behöver syre."',
    "Sedan sprang hon vidare.",
    '"Varför?" frågade han.',
    "Dr. Ek svarade att det beror på mjölksyra.",
]

RAW_EN = f"""History 9 – The Industrial Revolution                     Page 4
# Steam power

In 1769 James Watt improved the steam engine. By 1850 about 1.2 million people worked in British cotton mills,
e.g. in Manchester. Mr. Brown, a mill owner, said: "Coal is the new gold." Not everyone agreed. Today's word is {NONCE}.

Page 5 of 9
"""
EXPECT_EN = f"""Steam power
In 1769 James Watt improved the steam engine. By 1850 about 1.2 million people worked in British cotton mills,
e.g. in Manchester. Mr. Brown, a mill owner, said: "Coal is the new gold." Not everyone agreed. Today's word is {NONCE}."""
JUNK_EN = ["Page 4", "Page 5 of 9", "History 9"]
SENT_EN = [
    "Steam power",
    "In 1769 James Watt improved the steam engine.",
    "By 1850 about 1.2 million people worked in British cotton mills, e.g. in Manchester.",
    'Mr. Brown, a mill owner, said: "Coal is the new gold."',
    "Not everyone agreed.",
    f"Today's word is {NONCE}.",
]


def words(s):
    return re.findall(r"[\w']+(?:[.,]\d+)?", s.lower().replace("’", "'"))


def norm(s):
    return re.sub(r"\s+", " ", s.replace("”", '"').replace("“", '"').replace("’", "'")).strip()


def part_text(area, lang, raw, expect, junk, sents, subject):
    tok = signup()
    st, r = call("exam", {"action": "read", "text": raw, "subject": subject, "grade": "åk 8"}, tok)
    spend(r)
    check(area, f"{lang}: /exam read 200", st == 200, f"{st} {r.get('error')}")
    if st != 200:
        return None
    parts = r.get("parts") or []
    joined = " ".join(p["text"] for p in parts)
    heads = [p["text"] for p in parts if p["kind"] == "heading"]
    left = [j for j in junk if j in joined]
    check("A", f"{lang}: skräp och fel borta (sidnr, sidhuvud, ©, avstavning, OCR)", not left, left)
    check("A", f"{lang}: rubrikerna är rubriker", heads == [s for s in sents if not s.endswith((".", '"', "?"))], heads)
    exp_w, got_w = words(expect), words(joined)
    sm = difflib.SequenceMatcher(a=exp_w, b=got_w, autojunk=False)
    missing, added = [], []
    for op, a0, a1, b0, b1 in sm.get_opcodes():
        if op in ("delete", "replace"):
            missing.append(" ".join(exp_w[a0:a1]))
        if op in ("insert", "replace"):
            added.append(" ".join(got_w[b0:b1]))
    check("A", f"{lang}: ord för ord som materialet ({len(exp_w)} ord, inget kortat eller tillagt)", not missing and not added,
          f"saknas {missing} | tillagt {added}")
    exp_chars = sum(len(p["text"]) for p in parts)
    check("D", f"{lang}: counts_as = ceil(chars/800)", r.get("chars") == exp_chars and r.get("counts_as") == math.ceil(exp_chars / 800),
          f"chars {r.get('chars')} (delar {exp_chars}), counts_as {r.get('counts_as')}")
    check("A", f"{lang}: titeln", bool(r.get("title")), r.get("title"))
    want = "English" if lang == "en" else "sv"
    check("A", f"{lang}: K72 language från read = {want}", r.get("language") == want, r.get("language"))
    check("A", f"{lang}: K72 usage i read", bool((r.get("usage") or {}).get("est_cost_usd") is not None), r.get("usage"))

    # spara som text (appens väg) och kvoten
    st, q0 = call("drill", {"action": "quota"}, tok)
    st, s = call("drill", {"action": "save", "drill": {"kind": "text", "title": f"O67 {lang} (QA)", "subject": subject},
                           "items": [{"kind": p["kind"], "text": p["text"]} for p in parts]}, tok)
    check(area, f"{lang}: /drill save kind text 200", st == 200, f"{st} {s.get('error')}")
    if st != 200:
        return None
    did = s["drill"]["id"]
    nc, gq = s.get("new_chars"), s.get("generated_questions")
    check("D", f"{lang}: generated_questions = ceil(new_chars/800)", gq == math.ceil((nc or 0) / 800), f"new_chars {nc}, generated {gq}")
    check("D", f"{lang}: read.counts_as stämmer med save.generated_questions", gq == r.get("counts_as"),
          f"read {r.get('chars')} tecken -> {r.get('counts_as')}, save {nc} uppläsningstecken -> {gq}", obs=True)
    st, q1 = call("drill", {"action": "quota"}, tok)
    check("D", f"{lang}: kvoten ökar med generated_questions", (q1.get("used") or 0) - (q0.get("used") or 0) == gq,
          f"före {q0.get('used')} efter {q1.get('used')}, generated {gq}")

    # ljudet och tiderna
    for _ in range(30):
        st, v = call("drill", {"action": "status", "id": did}, tok)
        a = v.get("audio") or {}
        if a.get("total") and a.get("done") == a.get("total"):
            break
        time.sleep(2)
    check("C", f"{lang}: allt ljud klart", a.get("total") and a.get("done") == a.get("total"), a)
    items = v.get("items") or []
    check("E", f"{lang}: status kind text", (v.get("drill") or {}).get("kind") == "text", (v.get("drill") or {}).get("kind"))
    got_s = [norm(x) for it in items for x in (it.get("sentences") or [])]
    exp_s = [norm(x) for x in sents]
    wrong = [(e, g) for e, g in zip(exp_s, got_s) if e != g]
    check("B", f"{lang}: meningarna delas rätt ({len(exp_s)} väntade, {len(got_s)} fick)", got_s == exp_s,
          f"första skillnader: {wrong[:3]}" if wrong else f"längd {len(got_s)} mot {len(exp_s)}: {got_s[len(exp_s):][:2] or exp_s[len(got_s):][:2]}")
    bad_t = []
    for it in items:
        au = (it.get("audio") or {}).get("text") or {}
        ts, n = au.get("sentences"), len(it.get("sentences") or [])
        if not isinstance(ts, list) or len(ts) != n:
            bad_t.append(f"{it.get('part')} {n} meningar, tider {None if ts is None else len(ts)}")
            continue
        prev = -1
        for t0, t1 in ts:
            if not (t0 <= t1 and t0 >= prev):
                bad_t.append(f"{it.get('part')} ej stigande {ts}")
                break
            prev = t1
        if ts and au.get("duration_ms") is not None and ts[-1][1] > au["duration_ms"] + 50:
            bad_t.append(f"{it.get('part')} sista {ts[-1][1]} > duration {au['duration_ms']}")
    check("C", f"{lang}: tiderna följer meningarna (antal, ordning, inom ljudet)", not bad_t, bad_t[:4])
    return {"tok": tok, "id": did, "parts": parts, "new_chars": nc, "read": {k: r.get(k) for k in ("title", "chars", "counts_as")},
            "sentences": got_s}


def part_share_publish(t):
    tok, did, parts = t["tok"], t["id"], t["parts"]
    st, sh = call("drill", {"action": "share", "id": did}, tok)
    check("E", "dela: kod", st == 200 and sh.get("code"), f"{st} {sh.get('error')}")
    tok2 = signup()
    st, q0 = call("drill", {"action": "quota"}, tok2)
    st, c = call("drill", {"action": "import", "code": sh.get("code")}, tok2)
    texts = [i.get("text") for i in c.get("items") or []]
    check("E", "import: kind text, samma delar", st == 200 and (c.get("drill") or {}).get("kind") == "text" and texts == [p["text"] for p in parts],
          f"{st} kind {(c.get('drill') or {}).get('kind')}, {len(texts)} delar")
    st, q1 = call("drill", {"action": "quota"}, tok2)
    check("E", "import kostar 0 (new_chars 0, kvoten oförändrad)", c.get("new_chars") in (0, None) and q1.get("used") == q0.get("used"),
          f"new_chars {c.get('new_chars')}, kvot {q0.get('used')} -> {q1.get('used')}")
    # samma text på ett tredje konto via save: ljudet finns redan (D144)
    tok3 = signup()
    st, s3 = call("drill", {"action": "save", "drill": {"kind": "text", "title": "O67 samma text (QA)", "subject": "Biologi"},
                            "items": [{"kind": p["kind"], "text": p["text"]} for p in parts]}, tok3)
    check("D", "samma text igen kostar 0 (D144)", st == 200 and s3.get("new_chars") == 0 and s3.get("generated_questions") == 0,
          f"{st} new_chars {s3.get('new_chars')} generated {s3.get('generated_questions')}")
    if st == 200:
        call("drill", {"action": "delete", "id": s3["drill"]["id"]}, tok3)
    # publicera
    st, sc = call("drill", {"action": "schools", "q": "Katedral"}, tok)
    school = ((sc.get("schools") or [{}])[0]).get("code")
    date = (dt.date.today() + dt.timedelta(days=9)).isoformat()
    st, pub = call("drill", {"action": "publish", "id": did, "school_code": school, "subject": "Biologi", "exam_date": date}, tok)
    check("E", "publicera texten", st == 200, f"{st} {pub.get('error')} skola {school}")
    pid = (pub.get("publication") or {}).get("id")
    found = None
    for _ in range(3):
        st, s = call("drill", {"action": "search", "school_code": school}, tok2)
        found = next((x for x in s.get("results") or [] if x.get("id") == pid), None)
        if found:
            break
        time.sleep(3)
    check("E", "hitta via skolan (search)", bool(found), school)
    if found:
        check("E", "search: kind text eller förhandsvisning av texten", found.get("kind") == "text" or bool(found.get("preview")),
              json.dumps(found, ensure_ascii=False)[:300], obs=True)
    st, u = call("drill", {"action": "unpublish", "id": did}, tok)  # unpublish tar provets id, inte publiceringens
    check("E", "avpublicera", st == 200, st)
    st, s = call("drill", {"action": "search", "school_code": school}, tok2)
    check("E", "avpublicerad text syns inte i sök", not any(x.get("id") == pid for x in s.get("results") or []), pid)
    st, d = call("drill", {"action": "delete", "id": did}, tok)
    check("E", "ta bort", st == 200, st)
    st, d = call("drill", {"action": "list"}, tok2)
    for x in d.get("drills") or []:
        call("drill", {"action": "delete", "id": x["id"]}, tok2)


def main():
    DATA.mkdir(parents=True, exist_ok=True)
    res = {}
    sv = en = None
    try:
        sv = part_text("A", "sv", RAW_SV, EXPECT_SV, JUNK_SV, SENT_SV, "Biologi")
    except Exception as e:  # noqa: BLE001
        check("A", "sv kraschade", False, f"{type(e).__name__}: {e}")
    try:
        en = part_text("A", "en", RAW_EN, EXPECT_EN, JUNK_EN, SENT_EN, "Historia")
    except Exception as e:  # noqa: BLE001
        check("A", "en kraschade", False, f"{type(e).__name__}: {e}")
    if sv:
        try:
            part_share_publish(sv)
        except Exception as e:  # noqa: BLE001
            check("E", "dela/publicera kraschade", False, f"{type(e).__name__}: {e}")
    if en:
        call("drill", {"action": "delete", "id": en["id"]}, en["tok"])
    for k, t in (("sv", sv), ("en", en)):
        if t:
            res[k] = {x: t[x] for x in ("read", "new_chars", "parts", "sentences")}
    end = dt.datetime.now(dt.timezone.utc)
    sql = {
        "elevenlabs": ("select voice_id, kind, count(*), sum(coalesce(credits,0)) from drill_audio_files "
                       f"where created_at between '{START.isoformat()}' and '{end.isoformat()}' group by 1, 2;"),
        "voice_text": ("select kind, left(text, 300), sentence_ends, sentences from drill_audio_files where kind = 'text' "
                       f"and created_at between '{START.isoformat()}' and '{end.isoformat()}';"),
    }
    fel = [c for c in CHECKS if not c["ok"] and not c["obs"]]
    obs = [c for c in CHECKS if c["obs"]]
    summ = {"start": START.isoformat(timespec="seconds"), "end": end.isoformat(timespec="seconds"), "nonce": NONCE,
            "checks": len(CHECKS), "ok": len(CHECKS) - len(fel) - len(obs), "obs": len(obs), "fail": len(fel),
            "claude_usd": round(COST["claude"], 4),
            "by_area": {a: f"{sum(c['ok'] for c in CHECKS if c['area'] == a)}/{sum(c['area'] == a for c in CHECKS)}"
                        for a in sorted({c["area"] for c in CHECKS})}}
    out = DATA / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o67-reading.json")
    out.write_text(json.dumps({"summary": summ, "checks": CHECKS, "texts": res, "sql": sql}, ensure_ascii=False, indent=1), encoding="utf-8")
    print("\n=== Sammanfattning", json.dumps(summ, ensure_ascii=False))
    for c in fel + obs:
        print(f"{'FEL ' if c in fel else 'obs '} {c['area']} {c['check']} | {c['detail'][:300]}")
    print("SQL efteråt (Supabase MCP):", json.dumps(sql, ensure_ascii=False))
    print("->", out)
    sys.exit(1 if fel else 0)


if __name__ == "__main__":
    main()
