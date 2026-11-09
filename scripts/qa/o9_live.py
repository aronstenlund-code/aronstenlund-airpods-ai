#!/usr/bin/env python3
"""Oscar QA, O9 live: does the behaviour follow the task? A sample of my phrasings (incl. the three offline misses) and
two ordinary sentences, against the deployed /answer. python -I scripts/qa/o9_live.py -> reports/qa/data/<stamp>-o9-live.json"""
import datetime as dt, importlib.util, json, pathlib, sys
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("d81", ROOT / "scripts/qa/d81.py")
M = importlib.util.module_from_spec(spec); spec.loader.exec_module(M)
D, A, rec = M.D, M.A, M.rec
PROF = "Prov i Biologi på fredag om fotosyntesen och cellandningen. Årskurs: Åk 9. Ämne: Biologi. Kontrollfrågor: korta frågor. Förklaringar: mellanlånga förklaringar."
QA = [{"q": "fotosyntes", "a": "Fotosyntes är när växter med ljusenergi gör om koldioxid och vatten till glukos och syre i kloroplasterna. Ett exempel är ett blad i solen."}]
STATS = [{"concept": "cellandning", "right": 1, "wrong": 4}, {"concept": "fotosyntes", "right": 5, "wrong": 0}, {"concept": "klorofyll", "right": 3, "wrong": 1}]
prov = lambda frag: {"fragment": frag, "mode": "tutor", "language": "sv", "persona": "tutor", "persona_setup": PROF, "voice_instruction": True,
                     "context": {"recent_qa": QA, "concept_stats": STATS}}
CASES = [
    ("example", prov("Lumen, kan jag få ett exempel?")),
    ("summary", prov("sammanfatta kort")),
    ("quiz_topic", prov("förhör mig om cellandningen")),
    ("weak_areas (offline: quiz_topic)", prov("förhör mig på mina sämsta begrepp")),
    ("self_assessment (offline: none)", prov("hur går det för mig")),
    ("no task: ordinary question", dict(prov("vad är ett bra exempel på en näringskedja"), voice_instruction=False)),
    ("no task: ordinary question", dict(prov("sammanfatta andra världskriget för mig"), voice_instruction=False)),
    ("interview_help:counter_question", {"fragment": "motfråga", "mode": "tutor", "language": "sv", "persona": "interview",
                                          "persona_setup": M.AD + " CV: " + M.CV, "turn": "question", "voice_instruction": True,
                                          "context": {"recent_qa": [{"q": "Varför vill du jobba hos oss?", "a": "Jag gillar att möta kunder och vill lära mig mer om sortimentet."}]}}),
    ("social:funnier (offline: none)", {"fragment": "", "mode": "tutor", "language": "sv", "persona": "social",
                                        "social": {"style": "social", "trigger": "other_spoke", "calibrate": "kan du göra det roligare",
                                                   "transcript": [{"speaker": "Talare 1", "text": "Jag har tentavecka och har inte sovit på tre dagar."}], "speaker": "Talare 1"}}),
]
stamp = dt.datetime.now().strftime("%Y-%m-%d-%H%M")
tok = D.signup()
for name, body in CASES:
    r = A(tok, body)
    rec(name, fragment=body["fragment"] or body.get("social", {}).get("calibrate"), status=r["status"], text=r["text"], sugg=r["sugg"], calib=r["calib"],
        model=r["model"], cost=r["cost"], err=r["err"], first_ms=r["first_ms"])
rec("spent", usd=round(D.spent, 4))
(ROOT / "reports/qa/data" / f"{stamp}-o9-live.json").write_text(json.dumps(M.log, ensure_ascii=False, indent=1), encoding="utf-8")
