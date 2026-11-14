"""O61: K62b (D180) live check. Test traffic gets fake audio and a fake transcript and never reaches ElevenLabs.
Written by Oscar (QA). The ElevenLabs account has 0 credits, so a real call answers quota_exceeded (no cost).
  1. Test account (script user agent + header x-earmind-test): /tts, /stt-token, /drill save (3 questions) + status,
     /voice-lab sample, /provlage-eval transcribe -> all fake and successful.
  2. Ordinary call WITHOUT a test marker (the app's user agent, no header, a new account): /tts -> NOT fake (it reaches
     ElevenLabs and gets the quota error at 0 credits).
  3. D175: test account with 13 of 15 questions used -> /exam drill with 20 asked gives at most 2.
  python -I -X utf8 scripts/qa/o61_testmode.py
Result: reports/qa/data/<time>-o61-testmode.json (user ids only, never tokens)"""
import datetime as dt, json, pathlib, sys, time, urllib.error, urllib.request

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from qa_testaccount import URL, KEY, APP_UA, signup, call  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
ITEMS = [
    {"question": "Vad är en sluten krets?", "short": "En sluten krets är en obruten väg som strömmen kan gå runt i.",
     "long": "En sluten krets är en obruten väg som strömmen kan gå runt i. Bryts kretsen slutar strömmen gå."},
    {"question": "Vad mäts i volt?", "short": "Spänningen mäts i volt.",
     "long": "Spänningen mäts i volt. Den driver elektronerna runt i kretsen, ungefär som ett tryck."},
    {"question": "Varför finns säkringar?", "short": "En säkring bryter strömmen om den blir för stor.",
     "long": "En säkring bryter strömmen om den blir för stor. Då blir ledningarna inte så varma att de börjar brinna."},
]
MATERIAL = ("Elektrisk ström är elektroner som rör sig i en sluten krets och mäts i ampere. Spänningen mäts i volt och "
            "driver elektronerna. Resistans är motståndet mot strömmen och mäts i ohm. Ohms lag säger att U = R · I. "
            "I en seriekoppling går strömmen genom alla lampor efter varandra; i en parallellkoppling har varje lampa en "
            "egen väg. Metaller leder ström eftersom de har fria elektroner, plast och gummi är isolatorer. En säkring "
            "bryter strömmen om den blir för stor. ") * 3


def main():
    out = {"when": dt.datetime.now().isoformat(timespec="seconds"), "test": {}, "real": {}, "d175": {}}
    # ---------- 1. test account ----------
    tok, uid = signup(test=True)
    out["test"]["user_id"] = uid
    s, h, b = call("POST", "/functions/v1/tts", {"text": "Hej, det här är ett test.", "language": "sv"}, tok, test=True)
    out["test"]["tts"] = {"http": s, "content_type": h.get("content-type"), "fake_header": h.get("x-earmind-fake"), "bytes": len(b)}
    s, h, b = call("GET", "/functions/v1/stt-token", None, tok, test=True)
    out["test"]["stt_token"] = {"http": s, **{k: v for k, v in json.loads(b or b"{}").items() if k != "token"}}
    s, h, b = call("POST", "/functions/v1/drill", {"action": "save", "drill": {"title": "O61 testläge (QA)"}, "items": ITEMS}, tok, test=True)
    d = json.loads(b or b"{}")
    did = (d.get("drill") or {}).get("id")
    out["test"]["drill_save"] = {"http": s, "generated_questions": d.get("generated_questions"), "audio": d.get("audio"),
                                 "items": [{k: i.get(k) for k in ("voice_chars", "length_class")} for i in d.get("items", [])],
                                 "error": d.get("error")}
    st = {}
    for _ in range(12):
        time.sleep(5)
        s2, _, b2 = call("POST", "/functions/v1/drill", {"action": "status", "id": did}, tok, test=True)
        st = json.loads(b2 or b"{}").get("audio") or {}
        if st.get("done", 0) + st.get("failed", 0) >= st.get("total", 1):
            break
    out["test"]["drill_status"] = st
    s, h, b = call("POST", "/functions/v1/voice-lab", {"action": "sample", "text": "Hej.", "model": "eleven_multilingual_v2"}, tok, test=True)
    j = json.loads(b or b"{}")
    out["test"]["voice_lab"] = {"http": s, "fake": j.get("fake"), "character_cost": j.get("character_cost"), "error": j.get("error")}
    s, h, b = call("POST", "/functions/v1/provlage-eval", {"action": "transcribe", "audio_base64": "AAAA"}, tok, test=True)
    j = json.loads(b or b"{}")
    out["test"]["provlage_transcribe"] = {"http": s, "fake": j.get("fake"), "text": j.get("text"), "error": j.get("error")}
    s, _, b = call("POST", "/functions/v1/drill", {"action": "quota"}, tok, test=True)
    out["test"]["quota_after_save"] = json.loads(b or b"{}")
    # ---------- 3. D175: 13 of 15 used ----------
    tok3, uid3 = signup(test=True)
    out["d175"]["user_id"] = uid3
    filler = [{"question": f"Testfråga nummer {n}?", "short": f"Det här är svar nummer {n}.", "long": f"Det här är svar nummer {n}. Det är ett test."}
              for n in range(1, 14)]
    s, _, b = call("POST", "/functions/v1/drill", {"action": "save", "drill": {"title": "O61 D175 (QA)"}, "items": filler}, tok3, test=True)
    d3 = json.loads(b or b"{}")
    out["d175"]["save13"] = {"http": s, "generated_questions": d3.get("generated_questions"), "error": d3.get("error")}
    s, _, b = call("POST", "/functions/v1/drill", {"action": "quota"}, tok3, test=True)
    out["d175"]["quota_before"] = json.loads(b or b"{}")
    s, _, b = call("POST", "/functions/v1/exam", {"action": "drill", "text": MATERIAL, "questions": 20, "answers": False}, tok3, test=True)
    e = json.loads(b or b"{}")
    out["d175"]["exam"] = {"http": s, "items": len(e.get("items", [])), "questions_asked": e.get("questions_asked"),
                           "questions_possible": e.get("questions_possible"), "quota": e.get("quota"), "note": e.get("note"), "error": e.get("error")}
    s, _, b = call("POST", "/functions/v1/drill", {"action": "save", "drill": {"title": "O61 D175 till 15 (QA)"},
                                                     "items": filler[:2] + [{"question": "En fjortonde?", "short": "Ja.", "long": "Ja."}]}, tok3, test=True)
    out["d175"]["save3_over"] = {"http": s, "body": json.loads(b or b"{}").get("error")}
    # ---------- 2. ordinary call, no test marker (last, so nothing above depends on it) ----------
    tok2, uid2 = signup(test=False)
    out["real"]["user_id"] = uid2
    s, h, b = call("POST", "/functions/v1/tts", {"text": "Hej.", "language": "sv"}, tok2, test=False)
    out["real"]["tts"] = {"http": s, "content_type": h.get("content-type"), "fake_header": h.get("x-earmind-fake"), "bytes": len(b),
                          "body": b[:300].decode("utf-8", "replace") if not h.get("content-type", "").startswith("audio") else None}
    p = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o61-testmode.json")
    p.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(out, ensure_ascii=False, indent=1))
    print("->", p)


if __name__ == "__main__":
    main()
