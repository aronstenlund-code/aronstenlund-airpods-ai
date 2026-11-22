"""O97 (Oscar moln 2026-11-22): nattens eval fick 503 på alla svar som behöver modellen. Ett anrop till /answer och
ett till /exam (read, ingen modell) som visar felkoden. Testkonto, 0 ElevenLabs, högst ett litet Claude-anrop."""
import sys as _s, pathlib as _p
_s.path.insert(0, str(_p.Path(__file__).resolve().parent))
import qa_testaccount as T  # noqa: E402
T.install()
import json, urllib.error, urllib.request  # noqa: E402
_s.stdout.reconfigure(encoding="utf-8")
tok = T.signup(True)[0]
for path, body in (("/functions/v1/answer", {"fragment": "vad är fotosyntes", "mode": "text", "language": "sv", "context": {"recent_qa": []}}),
                   ("/functions/v1/exam", {"action": "drill", "answers": False, "questions": 3, "subject": "Biologi", "pages": [],
                                           "text": "Fotosyntesen sker i växternas blad. Med solljus gör växten socker av vatten och koldioxid."})):
    r = urllib.request.Request(T.URL + path, data=json.dumps(body).encode(), method="POST", headers=T.headers(tok, True))
    try:
        with urllib.request.urlopen(r, timeout=60) as x:
            print(path, x.status, x.read()[:400].decode(errors="replace"), flush=True)
    except urllib.error.HTTPError as e:
        print(path, e.code, dict(e.headers).get("retry-after"), (e.read() or b"")[:400].decode(errors="replace"), flush=True)
