import importlib.util, json, pathlib, sys, time, datetime as dt
sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path("/home/user/aronstenlund-airpods-ai")
sys.argv = sys.argv[:1]
sp = importlib.util.spec_from_file_location("o43", ROOT / "scripts/qa/o43_short_answers.py"); M = importlib.util.module_from_spec(sp); sp.loader.exec_module(M)
tok = M.O.signup(); rows = []
for exam, q, heard, key in (
    ("bio", "Vilken organell i växtcellen gör fotosyntes?", "kloroplast", {"answer": "Kloroplasten", "alternatives": ["Kloroplast", "Grönkorn", "Mitokondrien", "Cellkärnan", "Ribosomen"]}),
    ("bio", "Vad kallas den process där en cell delar sig och bildar två identiska dotterceller?", "mitos", {"answer": "Mitos", "alternatives": ["Meios", "Celldelning", "Mitos och cytokines", "Knoppning", "Befruktning"]}),
    ("bio", "Vad kallas den process där en cell delar sig och bildar två identiska dotterceller?", "celldelning", {"answer": "Mitos", "alternatives": ["Meios", "Celldelning", "Mitos och cytokines", "Knoppning", "Befruktning"]}),
):
    time.sleep(3.2)
    r = M.answer(tok, exam, q, heard, key)
    rows.append({"question": q, "heard": heard, "quiz_key": key, "reply": r.get("said"), "quiz_sound": (r.get("done") or {}).get("quiz_sound")})
    print(heard, "->", (r.get("done") or {}).get("quiz_sound"), "|", r.get("said", "")[:120])
out = ROOT / "reports/qa/data" / (dt.datetime.now().strftime("%Y-%m-%d-%H%M%S") + "-o43e-alt-right-form.json")
out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8"); print(out)
