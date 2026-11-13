#!/usr/bin/env python3
"""K51 live check (D159), invented material only: a short text asked for 20 questions gets fewer (questions_possible,
note); a full exam from Oscar's bank still gets 20; a non-image gives a Swedish error. Questions only (answers: false),
so the cost is one Haiku call per case.  python -X utf8 scripts/k51-live.py"""
import base64, json, pathlib, sys, urllib.error, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design
SHORT = ("Fotosyntes sker i bladens kloroplaster. Klorofyll fångar ljusenergi. Växten tar upp koldioxid och vatten "
         "och bildar glukos och syre.")


def token():
    req = urllib.request.Request(URL + "/auth/v1/signup", data=b"{}", method="POST", headers={"apikey": KEY, "content-type": "application/json"})
    return json.load(urllib.request.urlopen(req))["access_token"]


def exam(body, tok):
    req = urllib.request.Request(URL + "/functions/v1/exam", data=json.dumps(body).encode(), method="POST",
                                 headers={"apikey": KEY, "authorization": "Bearer " + tok, "content-type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=150) as r:
            return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def main():
    tok = token()
    out = {}
    st, j = exam({"action": "drill", "text": SHORT, "subject": "Biologi", "grade": "åk 8", "questions": 20, "answers": False}, tok)
    out["short_text"] = {"status": st, "asked": j.get("questions_asked"), "possible": j.get("questions_possible"), "note": j.get("note"),
                         "questions": [i["question"] for i in j.get("items", [])]}
    bank = json.load(open(ROOT / "scripts/qa/repetition_bank/exams.json", encoding="utf-8"))
    e = next(x for x in bank if x["id"] == "hist-ak9-forsta-varldskriget")
    st, j = exam({"action": "drill", "text": "\n\n".join(e["material"]["pages"]), "subject": e["subject"], "grade": e["grade"], "questions": 20, "answers": False}, token())
    out["full_exam"] = {"status": st, "asked": j.get("questions_asked"), "possible": j.get("questions_possible"), "note": j.get("note")}
    heic = base64.b64encode(b"\x00\x00\x00\x18ftypheic" + b"\x00" * 64).decode()
    st, j = exam({"action": "drill", "pages": [{"media_type": "image/jpeg", "data": heic}], "answers": False}, token())
    out["heic"] = {"status": st, "error": j.get("error")}
    print(json.dumps(out, ensure_ascii=False, indent=1))
    (ROOT / "reports/eval/k51-live-2026-11-13.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
