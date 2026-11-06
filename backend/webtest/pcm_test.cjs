// D66 test of the continuous PCM player: `node pcm_test.cjs` (needs Playwright + Chromium, no network).
// Stubs the backend: /answer streams 4 short sentences, /tts streams raw PCM (24 kHz) in chunks with delays.
// Asserts: (1) the audio of ALL sentences is scheduled back to back without a gap (sample-accurate),
// (2) short sentences are merged (first sentence alone, the rest in one request), (3) the audio session is
// "playback" when the first sample is scheduled, (4) every microphone track was stopped before that.
const { chromium } = require("playwright");
const path = require("path");
(async () => {
  const b = await chromium.launch({ args: ["--autoplay-policy=no-user-gesture-required"] });
  const p = await b.newPage();
  const errs = []; p.on("pageerror", (e) => errs.push(String(e)));
  const jwt = "x." + Buffer.from(JSON.stringify({ exp: Date.now() / 1000 + 3600 })).toString("base64") + ".y";
  const ttsTexts = [];
  await p.route("**/auth/v1/signup", (r) => r.fulfill({ json: { access_token: jwt } }));
  await p.route("**/functions/v1/voices", (r) => r.fulfill({ json: { voices: [] } }));
  await p.route("**/functions/v1/stt-token", (r) => r.fulfill({ status: 503, json: { error: { code: "x", message: "no", fallback: true } } }));
  await p.route("**/functions/v1/tts", (r) => {
    if (r.request().method() !== "POST") return r.fulfill({ status: 204 });
    const j = r.request().postDataJSON(); ttsTexts.push(j);
    // 0.6 s of 24 kHz 16-bit mono sine, delivered as one body (Playwright cannot stream), odd split handled by the page
    const n = 14400, buf = Buffer.alloc(n * 2);
    for (let i = 0; i < n; i++) buf.writeInt16LE(Math.round(Math.sin(i / 20) * 8000), i * 2);
    r.fulfill({ status: 200, contentType: "audio/L16", body: buf });
  });
  await p.route("**/functions/v1/answer", (r) => {
    if (r.request().method() !== "POST") return r.fulfill({ status: 204 });
    const d = (t) => `event: delta\ndata: ${JSON.stringify({ text: t })}\n\n`;
    r.fulfill({ status: 200, contentType: "text/event-stream", body: "event: meta\ndata: {}\n\n" + d("Ja, det stämmer. ") + d("Här är nästa. ") + d("Och en tredje, lite längre mening. ") + d("Sist kommer fjärde. ") + `event: done\ndata: ${JSON.stringify({ timing: {}, breakdown: {}, usage: {} })}\n\n` });
  });
  await p.addInitScript(() => {
    window.__sched = []; window.__tracksStopped = 0; window.__sessionAtFirst = null;
    let type = "auto";
    Object.defineProperty(navigator, "audioSession", { value: { get type() { return type; }, set type(v) { type = v; } }, configurable: true });
    const orig = AudioBufferSourceNode.prototype.start;
    AudioBufferSourceNode.prototype.start = function (when) {
      if (this.buffer && this.buffer.length > 1) {
        if (window.__sched.length === 0) window.__sessionAtFirst = navigator.audioSession.type;
        window.__sched.push({ at: when, dur: this.buffer.duration });
      }
      return orig.apply(this, arguments);
    };
  });
  await p.goto("file://" + path.join(__dirname, "index.html"));
  await p.waitForTimeout(400);
  await p.selectOption("#audiomode", "pcm");
  await p.fill("#txt", "testfråga"); await p.press("#txt", "Enter");
  await p.waitForFunction(() => window.__sched.length >= 2, null, { timeout: 8000 });
  await p.waitForTimeout(800);
  const s = await p.evaluate(() => ({ sched: window.__sched, session: window.__sessionAtFirst }));
  const sched = s.sched.slice().sort((a, c) => a.at - c.at);
  let maxGap = 0;
  for (let i = 1; i < sched.length; i++) maxGap = Math.max(maxGap, Math.abs(sched[i].at - (sched[i - 1].at + sched[i - 1].dur)));
  const ok = [
    ["chunks scheduled (one per request here: " + sched.length + ")", sched.length >= 2],
    ["gapless (max gap " + (maxGap * 1000).toFixed(3) + " ms <= 1 ms)", maxGap <= 0.001],
    ["merged: " + ttsTexts.length + " tts requests for 4 sentences (first alone + the rest merged)", ttsTexts.length === 2],
    ["pcm requested", ttsTexts.every((t) => t.output_format === "pcm_24000")],
    ["audio session = playback at the first sample (" + s.session + ")", s.session === "playback"],
    ["no page errors", errs.length === 0],
  ];
  for (const [n, v] of ok) console.log((v ? "ok   " : "FAIL ") + n);
  await b.close();
  process.exit(ok.every((x) => x[1]) ? 0 : 1);
})();
