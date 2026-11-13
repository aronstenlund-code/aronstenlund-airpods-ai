"""O55: gör materialfilerna (foton, PDF, .docx, text) ur materials.py.

Kör:  python -I scripts/qa/repetition_bank/make_files.py
Skriver till scripts/qa/repetition_bank/files/<prov-id>/ (git-ignorerat; deterministiskt, seed per prov).
  photo -> p01.jpg … (sidan som ett telefonfoto: lätt sned, ojämnt ljus, brus)
  pdf   -> material.pdf (PDF med textlager, Helvetica/WinAnsi, så att DocumentText kan läsa den)
  docx  -> material.docx (minimal Office Open XML, ett stycke per rad)
  text  -> material.txt (det eleven skulle klistra in)
Bara Pillow behövs. 0 nätverksanrop.
"""
import os
import random
import sys
import textwrap
import zipfile
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from materials import M  # noqa: E402
from materials_holdout import H  # noqa: E402  (O55b)
M.update(H)

from PIL import Image, ImageDraw, ImageFilter, ImageFont  # noqa: E402

FONT = "C:/Windows/Fonts/arial.ttf" if os.path.exists("C:/Windows/Fonts/arial.ttf") else None


def font(size):
    if FONT:
        return ImageFont.truetype(FONT, size)
    return ImageFont.load_default(size)


def photo(text, path, seed):
    rnd = random.Random(seed)
    W, H = 1240, 1754  # A4 i 150 dpi
    page = Image.new("L", (W, H), 250)
    d = ImageDraw.Draw(page)
    y = 110
    lines = text.split("\n")
    for i, para in enumerate(lines):
        f = font(46 if i == 0 else 34)
        for line in textwrap.wrap(para, 56 if i else 40) or [""]:
            d.text((100, y), line, fill=25, font=f)
            y += 58 if i == 0 else 48
        y += 24
    # som ett telefonfoto: liten rotation, bakgrund (bord), ojämnt ljus, lätt oskärpa, brus
    page = page.rotate(rnd.uniform(-2.5, 2.5), expand=True, fillcolor=120, resample=Image.BICUBIC)
    bg = Image.new("L", (page.width + 120, page.height + 160), 110)
    bg.paste(page, (60 + rnd.randint(-20, 20), 80 + rnd.randint(-20, 20)))
    grad = Image.linear_gradient("L").rotate(rnd.choice([0, 90, 180, 270])).resize(bg.size)
    bg = Image.blend(bg, Image.eval(grad, lambda v: 200 + v // 5), 0.18)
    bg = bg.filter(ImageFilter.GaussianBlur(0.7))
    noise = Image.effect_noise(bg.size, 6)
    bg = Image.blend(bg, noise, 0.04)
    bg = bg.resize((bg.width * 3 // 4, bg.height * 3 // 4))
    bg.convert("RGB").save(path, "JPEG", quality=72)


def pdf(pages, path):
    """En PDF med riktigt textlager. Helvetica med WinAnsiEncoding täcker å, ä, ö, é och ·."""
    objs = []

    def esc(s):
        b = s.encode("cp1252", errors="replace")
        return b.replace(b"\\", b"\\\\").replace(b"(", b"\\(").replace(b")", b"\\)")

    page_ids = []
    font_id = 3
    objs.append(None)  # 1 catalog
    objs.append(None)  # 2 pages
    objs.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
    for text in pages:
        ops = [b"BT /F1 12 Tf 15 TL 60 790 Td"]
        for i, para in enumerate(text.split("\n")):
            for line in textwrap.wrap(para, 88) or [""]:
                ops.append(b"(" + esc(line) + b") Tj T*")
            ops.append(b"T*")
        ops.append(b"ET")
        stream = b"\n".join(ops)
        objs.append(b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream")
        content_id = len(objs)
        objs.append(b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 %d 0 R >> >> "
                    b"/Contents %d 0 R >>" % (font_id, content_id))
        page_ids.append(len(objs))
    objs[0] = b"<< /Type /Catalog /Pages 2 0 R >>"
    objs[1] = b"<< /Type /Pages /Kids [" + b" ".join(b"%d 0 R" % i for i in page_ids) + b"] /Count %d >>" % len(page_ids)
    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = []
    for i, o in enumerate(objs, 1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % i + o + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    for off in offsets:
        out += b"%010d 00000 n \n" % off
    out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
    with open(path, "wb") as f:
        f.write(out)


def docx(pages, path):
    paras = []
    for text in pages:
        for i, line in enumerate(text.split("\n")):
            run = f'<w:r>{"<w:rPr><w:b/></w:rPr>" if i == 0 else ""}<w:t xml:space="preserve">{escape(line)}</w:t></w:r>'
            paras.append(f"<w:p>{run}</w:p>")
    doc = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
           '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>'
           + "".join(paras) + "</w:body></w:document>")
    ct = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/word/document.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>')
    rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/'
            'officeDocument" Target="word/document.xml"/></Relationships>')
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", ct)
        z.writestr("_rels/.rels", rels)
        z.writestr("word/document.xml", doc)


def main():
    total = 0
    for eid, m in M.items():
        out = os.path.join(HERE, "files", eid)
        os.makedirs(out, exist_ok=True)
        for fmt, idx in m["formats"]:
            pages = [m["pages"][i] for i in idx]
            if fmt == "photo":
                for n, i in enumerate(idx, 1):
                    photo(m["pages"][i], os.path.join(out, f"p{n:02d}.jpg"), seed=f"{eid}-{i}")
            elif fmt == "pdf":
                pdf(pages, os.path.join(out, "material.pdf"))
            elif fmt == "docx":
                docx(pages, os.path.join(out, "material.docx"))
            elif fmt == "text":
                with open(os.path.join(out, "material.txt"), "w", encoding="utf-8") as f:
                    f.write("\n\n".join(pages))
        size = sum(os.path.getsize(os.path.join(out, f)) for f in os.listdir(out))
        total += size
        print(f"{eid:32s} {', '.join(f for f, _ in m['formats']):18s} {len(os.listdir(out)):2d} filer {size // 1024:5d} kB")
    print(f"totalt {total // 1024} kB")


if __name__ == "__main__":
    main()
