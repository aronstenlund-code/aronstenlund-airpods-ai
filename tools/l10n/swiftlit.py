"""A157 (D251): finds the string literals in Swift source. A small lexer, not a parser: it knows comments, ordinary
and multi-line strings, raw strings and interpolation (nested), which is what the language check needs."""
from __future__ import annotations
import dataclasses, os


@dataclasses.dataclass
class Literal:
    file: str
    line: int
    start: int          # offset of the opening quote (or of the first # of a raw string)
    end: int            # offset just after the closing quote
    parts: list         # str (text, unescaped) and ("expr", source) in order
    multiline: bool
    raw: bool
    before: str         # the code before the literal on its line
    after: str          # the code after the literal on its last line

    @property
    def text(self) -> str:
        """The literal with every interpolation written as \\(…) (what a reader sees)."""
        return "".join(p if isinstance(p, str) else "\\(" + p[1] + ")" for p in self.parts)

    @property
    def plain(self) -> str:
        """The words only (interpolations as a space), for telling the language."""
        return "".join(p if isinstance(p, str) else " " for p in self.parts)

    @property
    def interpolated(self) -> bool:
        return any(not isinstance(p, str) for p in self.parts)


ESC = {"n": "\n", "t": "\t", "r": "\r", "0": "\0", "\\": "\\", '"': '"', "'": "'"}


def _string(src: str, i: int, hashes: int):
    """Reads a string whose opening quote is at src[i]. Returns (parts, end, multiline)."""
    multi = src.startswith('"""', i)
    i += 3 if multi else 1
    close = ('"""' if multi else '"') + "#" * hashes
    esc = "\\" + "#" * hashes
    parts, buf = [], []
    n = len(src)
    while i < n:
        if src.startswith(close, i):
            i += len(close)
            break
        if src.startswith(esc, i):
            j = i + len(esc)
            c = src[j] if j < n else ""
            if c == "(":
                depth, k = 1, j + 1
                while k < n and depth:
                    ch = src[k]
                    if ch == '"':
                        _, k, _ = _string(src, k, 0)
                        continue
                    if ch == "(":
                        depth += 1
                    elif ch == ")":
                        depth -= 1
                    k += 1
                if buf:
                    parts.append("".join(buf)); buf = []
                parts.append(("expr", src[j + 1:k - 1]))
                i = k
                continue
            if c == "u" and src.startswith("{", j + 1):
                k = src.index("}", j)
                buf.append(chr(int(src[j + 2:k], 16)))
                i = k + 1
                continue
            if c == "\n" and multi:      # a line continuation in a multi-line string
                i = j + 1
                while i < n and src[i] in " \t":
                    i += 1
                continue
            buf.append(ESC.get(c, c))
            i = j + 1
            continue
        if src[i] == "\n" and not multi:
            break                         # an unterminated string: give up on this line
        buf.append(src[i])
        i += 1
    if buf:
        parts.append("".join(buf))
    if multi:
        parts = _dedent(parts)
    return parts, i, multi


def _dedent(parts):
    """Removes the first newline, the last line's indentation from every line, and the last newline."""
    text = "".join(p if isinstance(p, str) else "\x00" for p in parts)
    lines = text.split("\n")
    indent = lines[-1] if lines[-1].strip() == "" else ""
    out, exprs = [], [p for p in parts if not isinstance(p, str)]
    body = lines[1:-1] if lines and lines[0].strip() == "" else lines[:-1]
    body = [l[len(indent):] if l.startswith(indent) else l.lstrip() for l in body]
    text = "\n".join(body)
    res, k = [], 0
    for piece in text.split("\x00"):
        if piece:
            res.append(piece)
        if k < len(exprs):
            res.append(exprs[k]); k += 1
    return res[:len(res) - 0] if k >= len(exprs) else res


def literals(path: str, src: str | None = None):
    if src is None:
        with open(path, encoding="utf-8") as f:
            src = f.read()
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if src.startswith("/*", i):
            depth, i = 1, i + 2
            while i < n and depth:
                if src.startswith("/*", i):
                    depth += 1; i += 2
                elif src.startswith("*/", i):
                    depth -= 1; i += 2
                else:
                    i += 1
            continue
        hashes = 0
        if c == "#":
            j = i
            while j < n and src[j] == "#":
                j += 1
            if j < n and src[j] == '"':
                hashes = j - i
                start = i
                parts, end, multi = _string(src, j, hashes)
            else:
                i = j
                continue
        elif c == '"':
            start = i
            parts, end, multi = _string(src, i, 0)
        else:
            i += 1
            continue
        ls = src.rfind("\n", 0, start) + 1
        le = src.find("\n", end)
        le = n if le < 0 else le
        out.append(Literal(path, src.count("\n", 0, start) + 1, start, end, parts, multi, hashes > 0,
                           src[ls:start], src[end:le]))
        i = end
    return out


def swift_files(*roots):
    for root in roots:
        for d, _, fs in os.walk(root):
            for f in sorted(fs):
                if f.endswith(".swift"):
                    yield os.path.join(d, f)
