"""Oscar's test accounts after K62b (D180): every QA call that can reach ElevenLabs goes through here.
A test request is marked twice: the header `x-earmind-test: oscar-qa` and a script user agent, so the server gives fake
audio and a fake transcript and never spends ElevenLabs credits (see backend/supabase/functions/_shared/testmode.ts).
`test=False` exists ONLY for O61's check that an ordinary app call is not treated as a test; never use it otherwise.
"""
import json, urllib.error, urllib.request

URL = "https://xjczbzfkmbjdebwlccki.supabase.co"
KEY = "sb_publishable_UNDoMfEur7nwt4qH8RRanQ_pVJCrGy8"  # public by design, it is in the app
TEST_HEADERS = {"x-earmind-test": "oscar-qa", "user-agent": "python-urllib/oscar-qa"}
APP_UA = "EarMind/1 CFNetwork/3826.400.120 Darwin/25.0.0"  # looks like the iPhone app, for the non-test check only


class RealElevenLabsBlocked(RuntimeError):
    pass


_installed = False


def install():
    """D180 for any Oscar script: every urllib call to our Supabase gets the test header and a script user agent, and
    any direct call to ElevenLabs (HTTP or websocket, e.g. a Scribe ws_url) is refused before it leaves the machine.
    Put `import qa_testaccount; qa_testaccount.install()` at the top of a script, before it makes any call."""
    global _installed
    if _installed:
        return
    _installed = True
    real_urlopen = urllib.request.urlopen

    def urlopen(url, *a, **kw):
        u = url.full_url if isinstance(url, urllib.request.Request) else str(url)
        if "elevenlabs" in u.lower():
            raise RealElevenLabsBlocked(f"D180: direct ElevenLabs call refused ({u[:60]})")
        if isinstance(url, urllib.request.Request) and u.startswith(URL):
            for k, v in TEST_HEADERS.items():
                url.add_header(k.capitalize(), v)  # urllib stores header names capitalized
        return real_urlopen(url, *a, **kw)

    urllib.request.urlopen = urlopen
    try:
        import websockets  # noqa: PLC0415  (only the audio scripts have it)
        real_connect = websockets.connect

        def connect(uri, *a, **kw):
            if not uri or "elevenlabs" in str(uri).lower():
                raise RealElevenLabsBlocked("D180: Scribe websocket refused; test accounts get a fake transcript")
            return real_connect(uri, *a, **kw)

        websockets.connect = connect
    except ImportError:
        pass


def headers(tok=None, test=True, extra=None):
    h = {"apikey": KEY, "content-type": "application/json"}
    if tok:
        h["authorization"] = "Bearer " + tok
    h.update(TEST_HEADERS if test else {"user-agent": APP_UA})
    if extra:
        h.update(extra)
    return h


def signup(test=True):
    req = urllib.request.Request(URL + "/auth/v1/signup", data=b"{}", method="POST", headers=headers(None, test))
    j = json.load(urllib.request.urlopen(req, timeout=30))
    return j["access_token"], (j.get("user") or {}).get("id")


def call(method, path, body, tok, test=True, timeout=120):
    """Returns (status, headers dict lower-case, raw bytes)."""
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(URL + path, data=data, method=method, headers=headers(tok, test))
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, {k.lower(): v for k, v in r.headers.items()}, r.read()
    except urllib.error.HTTPError as e:
        return e.code, {k.lower(): v for k, v in e.headers.items()}, e.read()
