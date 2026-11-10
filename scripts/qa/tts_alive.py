#!/usr/bin/env python3
"""Oscar QA: is the app's voice alive? One anonymous signup (waits out the auth rate limit), one 4-character /tts
call with the default model and one stt-token. Costs about 1 ElevenLabs credit.
  python -I scripts/qa/tts_alive.py"""
import importlib.util, json, pathlib, sys, time

sys.stdout.reconfigure(encoding="utf-8")
ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("o15", ROOT / "scripts/qa/o15.py")
O = importlib.util.module_from_spec(spec)
spec.loader.exec_module(O)
D = O.D
tok = O.signup()
o = D.call("POST", "/functions/v1/tts", {"text": "Hej.", "language": "sv", "output_format": "pcm_24000"}, tok)
print(time.strftime("%H:%M"), "tts", o["status"], o["headers"].get("x-tts-model"), len(o["body"]), o["body"][:200] if o["status"] != 200 else "")
o = D.call("GET", "/functions/v1/stt-token", None, tok)
print(time.strftime("%H:%M"), "stt-token", o["status"], o["body"][:160] if o["status"] != 200 else "ok")
