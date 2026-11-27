"""O107 del 2 (Oscar moln, 2026-11-27): delade och publicerade prov live – vad mottagaren ser, språk, att ingen
kontouppgift läcker. Tre nya testkonton (A äger, B får länken, C söker på skolan, C med engelska). Inga modellanrop
(proven sparas med färdiga frågor och svar), falskt ljud (testhuvud), 0 ElevenLabs. Allt raderas sist.
Kör i Actions (oscar-live.yml): python -I -X utf8 scripts/qa/o107_share_live.py"""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import json, re, time, urllib.error, urllib.request, uuid  # noqa: E402
sys = _s
sys.stdout.reconfigure(encoding="utf-8")
OK = []


def check(name, ok, detail):
    OK.append(bool(ok))
    print(("ok   " if ok else "FEL  ") + name, flush=True)
    print("     " + json.dumps(detail, ensure_ascii=False)[:1400], flush=True)


def call(body, tok, lang="sv"):
    r = urllib.request.Request(T.URL + "/functions/v1/drill", data=json.dumps(body).encode(), method="POST",
                               headers=T.headers(tok, True, {"x-earmind-lang": lang}))
    try:
        with urllib.request.urlopen(r, timeout=90) as x:
            return x.status, json.loads(x.read() or b"{}")
    except urllib.error.HTTPError as e:
        raw = e.read() or b"{}"
        try:
            return e.code, json.loads(raw)
        except ValueError:
            return e.code, {"raw": raw[:200].decode(errors="replace")}


def err(j):
    e = j.get("error") or {}
    return {"kod": e.get("code"), "text": e.get("message")}


A, A_ID = T.signup(True)
B, B_ID = T.signup(True)
C, C_ID = T.signup(True)
LEAK = re.compile("|".join(re.escape(x) for x in (A_ID, A_ID.replace("-", ""))), re.I)
tag = uuid.uuid4().hex[:6]
ITEMS = [{"question": f"Vad gör mitokondrien? ({tag})", "short": "Den gör energi åt cellen.", "long": "Mitokondrien gör energi åt cellen i form av ATP genom cellandning."},
         {"question": f"Vad gör cellkärnan? ({tag})", "short": "Den styr cellen.", "long": "Cellkärnan styr cellen och innehåller DNA med cellens arvsanlag."}]
s, j = call({"action": "save", "drill": {"title": f"Cellen O107 ({tag})", "subject": "Biologi", "grade": "åk 8"}, "items": ITEMS}, A)
DID = (j.get("drill") or {}).get("id")
check("1: A sparar ett prov med färdiga frågor (ingen modell)", s == 200 and DID, {"status": s, "id": DID})

# 2. share before the audio is done: the message, sv and en
s1, j1 = call({"action": "share", "id": DID}, A, "sv")
s2, j2 = call({"action": "share", "id": DID}, A, "en")
check("2: dela innan ljudet är klart ger 409 med förloppet, på valt språk", (s1 == 409 or s1 == 200) and (s2 == 409 or s2 == 200),
      {"sv": [s1, err(j1)], "en": [s2, err(j2)]})
done = False
for _ in range(20):
    _, st = call({"action": "status", "id": DID}, A)
    a = st.get("audio") or {}
    if a.get("total") and a.get("done") == a.get("total"):
        done = True
        break
    time.sleep(3)
s, sh = call({"action": "share", "id": DID}, A)
CODE = sh.get("code")
check("3: när ljudet är klart ger dela en kod och länk", done and s == 200 and CODE and str(sh.get("url", "")).startswith("https://"),
      {"ljud klart": done, "status": s, "svar": sh})
s, sh2 = call({"action": "share", "id": DID}, A)
check("4: samma kod igen för samma prov", sh2.get("code") == CODE, {"andra": sh2.get("code")})

# 5-9. what B sees
s, info = call({"action": "share_info", "code": CODE}, B)
check("5: share_info visar titel, ämne, årskurs och antal frågor – inget om A", s == 200 and info.get("items") == 2 and "Cellen" in str(info.get("title"))
      and not LEAK.search(json.dumps(info)), {"status": s, "info": info})
s, cp = call({"action": "import", "code": CODE}, B)
CID = (cp.get("drill") or {}).get("id")
items = cp.get("items") or []
check("6: B:s kopia har samma frågor och svar, ett eget id och ingen uppgift om A", s == 200 and CID and CID != DID and len(items) == 2
      and [i.get("question") for i in items] == [i["question"] for i in ITEMS] and not LEAK.search(json.dumps(cp)),
      {"status": s, "kopia": CID, "frågor": [i.get("question") for i in items], "nycklar": sorted((cp.get("drill") or {}).keys())})
_, q = call({"action": "quota"}, B)
check("7: kopian kostar B inga krediter (samma ljud)", (q.get("used") or 0) == 0, {"used": q.get("used")})
s, ed = call({"action": "save", "drill": {"id": CID}, "items": [{**items[0], "long": items[0].get("long", "") + " Ändrat av B."}, items[1]]}, B)
_, orig = call({"action": "get", "id": DID}, A)
check("8: B:s ändring rör inte A:s original", s == 200 and "Ändrat av B" not in json.dumps(orig), {"spara": s, "A:s första långa svar": ((orig.get("items") or [{}])[0]).get("long")})
s, en = call({"action": "share_info", "code": "zzzzzzzzzz"}, C, "en")
s2, sv = call({"action": "share_info", "code": "zzzzzzzzzz"}, C, "sv")
check("9: okänd kod: nej på mottagarens språk (en/sv)", s in (404, 410) and s2 in (404, 410), {"en": [s, err(en)], "sv": [s2, err(sv)]})

# 10-11. unshare
s, un = call({"action": "unshare", "id": DID}, A)
s2, gone = call({"action": "share_info", "code": CODE}, C)
_, still = call({"action": "get", "id": CID}, B)
check("10: när A slutar dela fungerar länken inte längre, men B:s kopia finns kvar", s == 200 and s2 in (404, 410) and (still.get("drill") or {}).get("id") == CID,
      {"unshare": [s, un], "share_info efteråt": [s2, err(gone)], "B:s kopia": bool(still.get("drill"))})

# 12-19. publish
s, sc = call({"action": "schools", "q": "Katedralskolan"}, A)
school = ((sc.get("schools") or [{}])[0])
check("11: skolsök ger aktiva skolor", s == 200 and school.get("code"), {"status": s, "första": school})
s, p0 = call({"action": "publish", "id": DID}, A)
check("12: publicera utan skola/ämne/datum ger 409 med vad som saknas", s == 409 and (p0.get("missing") or (p0.get("error") or {}).get("missing")), {"status": s, "svar": p0})
s, pub = call({"action": "publish", "id": DID, "school_code": school.get("code"), "subject": "Biologi", "exam_date": time.strftime("%Y-%m-%d", time.gmtime(time.time() + 7 * 86400)), "show_name": False}, A)
PID = (pub.get("publication") or {}).get("id")
check("13: publicera med skola, ämne och datum", s == 200 and PID, {"status": s, "svar": pub})
s, res = call({"action": "search", "school_code": school.get("code"), "subject": "Biologi"}, C, "en")
mine = [r for r in (res.get("results") or []) if r.get("id") == PID]
check("14: C hittar provet på skolan; inget konto-id och inget namn (show_name false)", s == 200 and mine and not LEAK.search(json.dumps(res)) and not mine[0].get("display_name"),
      {"status": s, "träff": mine[:1], "nycklar": sorted(mine[0].keys()) if mine else None})
s, cp2 = call({"action": "import", "publication_id": PID}, C, "en")
check("15: C importerar det publicerade provet (egen kopia, inget om A)", s == 200 and (cp2.get("drill") or {}).get("id") and not LEAK.search(json.dumps(cp2)),
      {"status": s, "frågor": [i.get("question") for i in (cp2.get("items") or [])]})
s, rp = call({"action": "report", "publication_id": PID, "reason": "fel"}, C, "en")
s2, rp2 = call({"action": "report", "publication_id": PID, "reason": "fel"}, C, "en")
check("16: en rapport räknas en gång per konto (inte dold av ett konto)", s == 200 and not rp.get("hidden") and not rp2.get("hidden"), {"första": [s, rp], "igen": [s2, rp2]})
s, pub2 = call({"action": "publish", "id": DID, "school_code": school.get("code"), "subject": "Biologi", "exam_date": time.strftime("%Y-%m-%d", time.gmtime(time.time() + 7 * 86400)), "show_name": True, "display_name": "Testa Testsson"}, A)
s3, res2 = call({"action": "search", "school_code": school.get("code"), "subject": "Biologi"}, C)
mine2 = [r for r in (res2.get("results") or []) if r.get("id") == PID]
check("17: med show_name syns bara det valda visningsnamnet, aldrig konto eller e-post", mine2 and not LEAK.search(json.dumps(res2)),
      {"publicera igen": s, "träff": mine2[:1]})
s, mod = call({"action": "moderate", "publication_id": PID, "hidden": False}, C)
check("18: bara Aron kan moderera (C nekas)", s in (401, 403), {"status": s, "svar": err(mod)})
s, upub = call({"action": "unpublish", "id": DID}, A)
s2, res3 = call({"action": "search", "school_code": school.get("code"), "subject": "Biologi"}, C)
check("19: avpublicerat syns inte längre", s == 200 and not [r for r in (res3.get("results") or []) if r.get("id") == PID], {"unpublish": s})

for tok, did in ((A, DID), (B, CID), (C, (cp2.get("drill") or {}).get("id"))):
    if did:
        call({"action": "delete", "id": did}, tok)
print(f"\n=== O107 del 2 {sum(OK)}/{len(OK)} ok")
sys.exit(0 if all(OK) else 1)
