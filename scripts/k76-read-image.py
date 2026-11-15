"""K76 (Kevin moln, 2026-11-15): Toby's T28 finding, /exam read gave 422 on his test picture. The same picture (black
text on white, A4 at 150 dpi, the text from scripts/apptest/fullflow.sh) drawn with Pillow, then /exam read and
/exam drill on it with a test account (Claude only, 0 ElevenLabs). Usage: python -X utf8 scripts/k76-read-image.py
"""
import base64, io, json, os, subprocess, sys, time
subprocess.run([sys.executable, "-m", "pip", "install", "-q", "pillow"], check=True)
from PIL import Image, ImageDraw, ImageFont  # noqa: E402
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "qa"))
import qa_testaccount as qa  # noqa: E402
qa.install()
TEXT = "Fotosyntes. Växter tillverkar socker av koldioxid och vatten med hjälp av solljus. Klorofyllet i bladen fångar ljuset. Syre bildas och släpps ut. Sockret ger växten energi och byggmaterial."
img = Image.new("RGB", (1240, 1754), "white")
d = ImageDraw.Draw(img)
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 46)
words, lines, cur = TEXT.split(), [], ""
for w in words:
    t = (cur + " " + w).strip()
    if d.textlength(t, font=font) > 1020: lines.append(cur); cur = w
    else: cur = t
lines.append(cur)
for i, l in enumerate(lines): d.text((110, 110 + i * 70), l, fill="black", font=font)
buf = io.BytesIO(); img.save(buf, "PNG"); b64 = base64.b64encode(buf.getvalue()).decode()
print("png bytes", len(buf.getvalue()))
tok = qa.signup()[0]
out = {}
for action in ["read", "drill"]:
    body = {"action": action, "pages": [{"media_type": "image/png", "data": b64}], **({"questions": 3, "answers": False} if action == "drill" else {})}
    t0 = time.perf_counter()
    st, _, raw = qa.call("POST", "/functions/v1/exam", body, tok, timeout=120)
    out[action] = {"status": st, "ms": round((time.perf_counter() - t0) * 1000), "body": json.loads(raw) if raw else None}
    print(action, st, json.dumps(out[action]["body"], ensure_ascii=False)[:800])
out["checks"] = {"read_200": out["read"]["status"] == 200, "drill_200": out["drill"]["status"] == 200}
p = os.path.join(HERE, "..", "reports", "qa", "data", time.strftime("%Y-%m-%d-%H%M%S") + "-k76-read-image.json")
json.dump(out, open(p, "w", encoding="utf8"), ensure_ascii=False, indent=1)
