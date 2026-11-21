// T56 (Toby): the web beta (A156, D249) in the Safari engine (WebKit, iPhone size) and Chrome (Chromium, Pixel size).
//   node scripts/apptest/t56/beta.mjs <webkit|chromium> [out-dir] [--live https://earmind.vercel.app/beta]
// Local (default): the built site/ as Vercel serves it, against a pretend server and silent WAVs made here (from
// Angela's web/scripts/smoke.mjs, A156). No request leaves the machine (checked).
// Live (--live): the published page and the real server. D180, 0 ElevenLabs: run it ONLY in GitHub Actions. The
// server treats every request from GitHub's Actions IP ranges as test traffic (fake audio, and a guard that stops a
// test request before the ElevenLabs client: backend/supabase/functions/_shared/testmode.ts), and the user agent
// carries "Playwright", which the server also reads as a script. The page is opened
// without ?test, because a browser cannot send x-earmind-test until the server allows it in CORS (A156 §4.1). Any
// request to an ElevenLabs host is stopped here and fails the run. The script refuses --live outside Actions.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { mkdirSync, writeFileSync } from 'node:fs';
import { extname, join, resolve } from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
let pw;
try {
  pw = require('playwright');
} catch {
  pw = await import('playwright');
}
const args = process.argv.slice(2);
const liveAt = args.indexOf('--live');
const liveURL = liveAt >= 0 ? args.splice(liveAt, 2)[1] : null;
const live = liveURL !== null;
if (live && process.env.GITHUB_ACTIONS !== 'true') {
  console.error('--live runs only in GitHub Actions (D180: the server counts Actions IPs as test traffic).');
  process.exit(2);
}
const engine = args[0] ?? 'chromium';
if (!['webkit', 'chromium'].includes(engine)) throw new Error(`engine must be webkit or chromium, not ${engine}`);
const site = resolve(new URL('../../../site', import.meta.url).pathname);
const out = resolve(args[1] ?? `t56-out/${engine}${live ? '-live' : ''}`);
mkdirSync(out, { recursive: true });
// The phone each engine stands in for: Safari on an iPhone, Chrome on an Android phone.
const phone = engine === 'webkit' ? pw.devices['iPhone 15'] : pw.devices['Pixel 7'];

const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png' };
// The site as Vercel serves it (site/vercel.json: cleanUrls, no trailing slash): /beta is site/beta/index.html.
const server = createServer(async (req, res) => {
  const path = new URL(req.url, 'http://x').pathname;
  const file = extname(path) === '' ? join(site, path, 'index.html') : join(site, path);
  try {
    const body = await readFile(file);
    res.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end('not found');
  }
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}`;

function wav(seconds) {
  const n = Math.round(8000 * seconds);
  const b = Buffer.alloc(44 + n, 128);
  b.write('RIFF', 0);
  b.writeUInt32LE(36 + n, 4);
  b.write('WAVEfmt ', 8);
  b.writeUInt32LE(16, 16);
  b.writeUInt16LE(1, 20);
  b.writeUInt16LE(1, 22);
  b.writeUInt32LE(8000, 24);
  b.writeUInt32LE(8000, 28);
  b.writeUInt16LE(1, 32);
  b.writeUInt16LE(8, 34);
  b.write('data', 36);
  b.writeUInt32LE(n, 40);
  return b;
}

const calls = [];
const state = { statusAsked: 0, credits: 1236, fits: null };
const textView = (done) => ({
  drill: { id: 'd1', kind: 'text', audio_started: true, voice_name: 'Astrid' },
  items: [
    {
      id: 'p1',
      text: 'Photosynthesis: carbon dioxide + water + light become sugar and oxygen. It happens in the chloroplasts.',
      sentences: ['Photosynthesis: carbon dioxide + water + light become sugar and oxygen.', 'It happens in the chloroplasts.'],
      audio: { text: done ? { status: 'done', url: 'https://files.test/p1.wav', duration_ms: 3000, sentences: [[0, 1500], [1500, 3000]] } : { status: 'working' } },
    },
  ],
  audio: { done: done ? 1 : 0, total: 1 },
});
const quizItems = ['What does photosynthesis make?', 'Where does photosynthesis happen?', 'Which gas do plants take in?', 'What is chlorophyll?', 'Why are leaves green?'];
const quizView = (started) => ({
  drill: { id: 'e1', audio_started: started },
  items: quizItems.map((q, i) => ({
    id: `q${i}`,
    question: q,
    audio: started ? { question: { status: 'done', url: `https://files.test/q${i}.wav`, duration_ms: 1200 }, long: { status: 'done', url: `https://files.test/a${i}.wav`, duration_ms: 4000, short_end_ms: 1000 } } : undefined,
  })),
  audio: { done: started ? 10 : 0, total: 10, cost: 640 },
});

async function answer(route) {
  const req = route.request();
  const url = new URL(req.url());
  const cors = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' };
  if (req.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: cors });
  const json = (body, status = 200) => route.fulfill({ status, headers: { ...cors, 'content-type': 'application/json' }, body: JSON.stringify(body) });
  if (url.hostname === 'files.test') return route.fulfill({ status: 200, headers: { ...cors, 'content-type': 'audio/wav', 'accept-ranges': 'bytes' }, body: wav(url.pathname.startsWith('/a') ? 4 : url.pathname.startsWith('/q') ? 1.2 : 3) });
  if (url.pathname.startsWith('/auth/')) return json({ access_token: 'a.b.c', refresh_token: 'r', expires_in: 3600 });
  const fn = url.pathname.replace('/functions/v1/', '');
  const body = req.postData() ? JSON.parse(req.postData()) : {};
  calls.push({ fn, action: body.action ?? '', headers: req.headers(), body });
  if (fn === 'voices') {
    return json({
      default_voice: { name: 'Astrid' },
      catalog: [
        { voice_id: 'v1', name: 'Astrid', accent: 'Swedish', description: 'Calm and clear' },
        { voice_id: 'v2', name: 'Oliver', accent: 'British', description: 'Warm', preview_url: 'https://files.test/preview.wav' },
        { voice_id: 'v9', name: 'Hidden', review: true },
      ],
    });
  }
  if (fn === 'drill') {
    const quota = { limit: 1500, remaining: state.credits, resets_day: '2026-12-01' };
    if (body.action === 'quota') return json(quota);
    if (body.action === 'cost') return json({ cost: 102, remaining: state.credits, enough: true });
    if (body.action === 'save' && body.drill.said) return json(textView(false));
    if (body.action === 'save') return json(quizView(false));
    if (body.action === 'status') return json(body.id === 'e1' ? quizView(true) : textView((state.statusAsked += 1) >= 1));
    if (body.action === 'start') return json(body.id === 'e1' ? quizView(true) : textView(true));
    return json({ ok: true });
  }
  if (fn === 'exam') {
    if (body.action === 'drill') {
      if (state.fits !== null && body.questions > state.fits) {
        return json({ error: { code: 'quota_exceeded', message: 'Not enough credits for that many questions.' }, fits: state.fits, min_questions: 3 }, 402);
      }
      const n = Math.min(body.questions, quizItems.length);
      return json({ summary: { subject: 'Biology', grade: 'Year 8', covers: 'Photosynthesis and the parts of a leaf' }, notes: 'notes', items: quizItems.slice(0, n).map((q, i) => ({ id: `q${i}`, question: q })) });
    }
    return json({ items: body.items.map((it) => ({ ...it, short: 'Sugar and oxygen.', long: 'Photosynthesis makes sugar, which the plant uses for energy and growth, and oxygen, which it lets out through the leaves.' })) });
  }
  return json({});
}

const results = [];
const failures = [];
const notes = [];
const check = (name, ok, detail = '') => {
  console.log(`${ok ? 'ok  ' : 'FAIL'} [${engine}] ${name}${detail ? ` (${detail})` : ''}`);
  results.push({ name, ok, detail });
  if (!ok) failures.push(name);
};
const note = (text) => {
  console.log(`note [${engine}] ${text}`);
  notes.push(text);
};
// A wait that fails as a check (with the step's name) instead of throwing the whole run away.
const until = async (name, fn, page, timeout = 15000) => {
  try {
    await page.waitForFunction(fn, null, { timeout });
    return true;
  } catch {
    check(name, false, `waited ${timeout / 1000} s`);
    return false;
  }
};

const browser = await pw[engine].launch(engine === 'chromium' ? { args: ['--autoplay-policy=user-gesture-required'] } : {});
note(`browser ${engine} ${browser.version()}, as ${engine === 'webkit' ? 'iPhone 15' : 'Pixel 7'}, ${live ? `live: ${liveURL}` : 'local site/ with the pretend server'}`);
// Where the page is opened. Local: ?test=toby (x-earmind-test, checked below). Live: no ?test (see the top).
const page0 = live ? liveURL : `${base}/beta?test=toby`;
// Live: a word unique to this run in every text, because the server says 0 credits (and shows no cost) for a text
// it has already made (run 44916619787); a new text makes Spela and the quiz really go through the server.
const stamp = live ? ` ${process.env.GITHUB_RUN_ID ?? Date.now()}-${engine}` : '';
const hostsSeen = new Set();
const serverLog = [];
const elevenLabs = [];

async function run(name, { locale, colorScheme, viewport }, steps) {
  // Live: the phone's own user agent plus "Playwright/1.63", which the server's SCRIPT_UA reads as a script, so the
  // traffic is a test also if the Actions IP list were empty (D180; the page still sees an iPhone or Android phone).
  const userAgent = live ? `${phone.userAgent} Playwright/1.63` : phone.userAgent;
  const context = await browser.newContext({ ...phone, userAgent, locale, colorScheme, ...(viewport ? { viewport } : {}) });
  await context.grantPermissions(['screen-wake-lock']).catch(() => note(`${name}: this engine has no screen-wake-lock permission to grant`));
  // Count the page's own Wake Lock requests (D250) without changing what the browser answers.
  await context.addInitScript(() => {
    window.__t56Wake = { requests: 0, results: [] };
    const wl = navigator.wakeLock;
    if (!wl || typeof wl.request !== 'function') return;
    const original = wl.request.bind(wl);
    wl.request = (type) => {
      window.__t56Wake.requests += 1;
      return original(type).then(
        (l) => (window.__t56Wake.results.push('granted'), l),
        (e) => (window.__t56Wake.results.push(e?.name ?? 'error'), Promise.reject(e)),
      );
    };
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => (m.type() === 'error' && !/status of 402|402 \(/.test(m.text()) ? errors.push(m.text()) : undefined));
  if (!live) {
    await page.route('https://xjczbzfkmbjdebwlccki.supabase.co/**', answer);
    await page.route('https://files.test/**', answer);
  }
  // D180 belt and braces: nothing from the page may reach ElevenLabs (voice previews included).
  await page.route(/elevenlabs\.io|elevenlabs\.com|api\.elevenlabs/i, (route) => {
    elevenLabs.push(route.request().url());
    return route.abort();
  });
  if (live) {
    // What the real server answers (path and status only, never bodies or headers), so a stop can be read in the log.
    page.on('response', (r) => {
      const u = new URL(r.url());
      if (u.hostname.endsWith('.supabase.co')) {
        const action = (() => { try { return JSON.parse(r.request().postData() ?? '{}').action ?? ''; } catch { return ''; } })();
        serverLog.push(`${name} ${r.request().method()} ${u.pathname.replace('/functions/v1/', '')}${action ? ` ${action}` : ''} → ${r.status()}`);
      }
    });
    page.on('requestfailed', (r) => serverLog.push(`${name} FAILED ${r.method()} ${new URL(r.url()).hostname}${new URL(r.url()).pathname}: ${r.failure()?.errorText ?? '?'}`));
  }
  const outside = [];
  page.on('request', (r) => {
    if (r.url().startsWith('data:') || r.url().startsWith('blob:')) return;
    const host = new URL(r.url()).hostname;
    hostsSeen.add(host);
    if (!live && !['127.0.0.1', 'xjczbzfkmbjdebwlccki.supabase.co', 'files.test'].includes(host)) outside.push(r.url());
  });
  const shot = async (label) => {
    await page.waitForTimeout(450);
    await page.screenshot({ path: join(out, `${engine}-${name}-${label}.png`) });
  };
  try {
    await steps(page, shot);
  } catch (e) {
    check(`${name}: the steps ran to the end`, false, String(e).split('\n')[0].slice(0, 240));
    await shot('stopped').catch(() => undefined);
  }
  check(`${name}: no script errors`, errors.length === 0, errors.join(' | ').slice(0, 300));
  if (!live) check(`${name}: nothing asked outside the pretend server`, outside.length === 0, outside.join(' ').slice(0, 200));
  check(`${name}: no request to ElevenLabs (D180)`, elevenLabs.length === 0, elevenLabs.join(' ').slice(0, 200));
  await context.close();
}


// Krediter and Språk en → sv: the end of the English run (also when the live quiz was refused).
async function finishLive(page, shot) {
  await page.keyboard.press('Escape').catch(() => undefined);
  if ((await page.getByTestId('sheet-done').count()) > 0) await page.getByTestId('sheet-done').first().click().catch(() => undefined);
  // Krediter
  await page.getByTestId('credits').click();
  await page.getByTestId('credits-sheet').waitFor();
  const number = await text(page, 'credits-number');
  check('Credits: the number, and no purchases on the web', (live ? /^[\d,∞]+$/.test(number) : number === '1,236') && (await text(page, 'no-purchases')) === 'Purchases come with the iOS app.', `${number} / ${await text(page, 'no-purchases')}`);
  await shot('7-credits');
  await page.getByTestId('sheet-done').click();

  // Språk en → sv in Settings
  await page.getByTestId('settings').click();
  await shot('8-settings');
  await page.getByRole('button', { name: 'Svenska' }).click();
  if (await until('Settings › Svenska: the page is in Swedish', () => document.documentElement.lang === 'sv' && document.querySelector('[data-testid=credits]')?.textContent.includes('krediter'), page, 10000)) {
    check('Settings › Svenska: the page is in Swedish', true);
  }
  await shot('9-svenska');
}
const text = async (page, id) => ((await page.getByTestId(id).textContent()) ?? '').trim();

await run('en-dark', { locale: 'en-US', colorScheme: 'dark' }, async (page, shot) => {
  await page.goto(page0);
  // Välkommen: the web beta has no welcome screen in part 1; its first screen is Say in AirPods with the screen line.
  await page.getByTestId('credits').waitFor();
  await until('the credits capsule fills in', () => /\d/.test(document.querySelector('[data-testid=credits]').textContent), page, 20000);
  const capsule = await text(page, 'credits');
  check('English by default, credits left on the capsule', live ? /credits left$/.test(capsule) : capsule === '1.2k credits left', capsule);
  check('the screen line shows the first time, with 10 m (D250)', /10\s?m \(33\s?ft\)/u.test(await text(page, 'screen-line')), JSON.stringify(await text(page, 'screen-line')).slice(0, 220));
  await shot('1-first');

  // Säg → Spela (silent WAV from the pretend server)
  await page.getByTestId('say-field').fill(`Photosynthesis${stamp}: carbon dioxide + water + light become sugar and oxygen. It happens in the chloroplasts.`);
  await until('the cost shows under the field', () => !!document.querySelector('[data-testid=cost]'), page, 30000);
  if (live) await until('the server’s cost shows', () => /\d/.test(document.querySelector('[data-testid=cost]')?.textContent ?? ''), page, 20000);
  const cost = await text(page, 'cost');
  check('the cost is the server’s number', live ? /\d.*credits?$/.test(cost) : cost === '102 credits', cost);
  await page.getByTestId('voice').click();
  await page.getByTestId('voices-sheet').waitFor();
  const voiceRows = await page.getByTestId('voice-row').count();
  check(live ? 'the voices sheet lists voices' : 'voices under review are not offered', live ? voiceRows >= 1 : voiceRows === 2, `${voiceRows}`);
  if (voiceRows > 1) await page.getByTestId('voice-row').nth(1).click();
  await page.getByTestId('sheet-done').click();
  await shot('2-text');
  await page.getByTestId('play').click();
  await page.getByTestId('status').waitFor();
  if (await until('Spela: "Playing in AirPods"', () => document.querySelector('[data-testid=status]')?.textContent.includes('Playing in AirPods'), page)) check('Spela: "Playing in AirPods"', true);
  // The risk in Safari (A156 §2): one <audio> element, started inside the tap, then the server's files on it.
  if (await until('the sound plays on the page’s one audio element', () => !document.querySelector('#sound').paused && /^https:/.test(document.querySelector('#sound').src) && !document.querySelector('#sound').src.startsWith('data:'), page, live ? 60000 : 15000)) {
    check('the sound plays on the page’s one audio element', true);
  }
  const audioState = await page.evaluate(() => ({ elements: document.querySelectorAll('audio').length, time: document.querySelector('#sound')?.currentTime ?? -1 }));
  check('only one audio element on the page', audioState.elements === 1, `${audioState.elements}`);
  await page.waitForFunction((t0) => (document.querySelector('#sound')?.currentTime ?? -1) > t0, audioState.time, { timeout: 5000 }).catch(() => undefined);
  const moved = await page.evaluate(() => document.querySelector('#sound')?.currentTime ?? -1);
  check('the audio clock moves (it really plays)', moved > audioState.time, `${audioState.time.toFixed(2)} → ${moved.toFixed(2)} s`);
  const asked = await page.evaluate(() => ({ has: !!navigator.wakeLock, ...window.__t56Wake }));
  if (asked.has) check('Spela asks for Wake Lock (D250)', asked.requests >= 1, `requests ${asked.requests}, answers ${asked.results.join(',') || '-'}`);
  else note('this engine has no navigator.wakeLock, so the page cannot ask; the screen line must show instead');
  const lock = await page.evaluate(() => (navigator.wakeLock ? navigator.wakeLock.request('screen').then((l) => l.release().then(() => 'granted'), (e) => e.name) : 'missing'));
  note(`Wake Lock in this engine: ${lock}`);
  const playingLine = await page.locator('.playing-host').textContent().catch(() => '');
  if (lock === 'granted') check('Wake Lock held: "The screen stays on while it plays."', playingLine.includes('The screen stays on while it plays.'));
  else check('no Wake Lock: the screen line still shows while it plays (D250)', (await page.getByTestId('screen-line').count()) > 0 && (await text(page, 'screen-line')).includes('10 m'), playingLine.slice(0, 120));
  const media = await page.evaluate(() => ('mediaSession' in navigator ? { artist: navigator.mediaSession.metadata?.artist ?? null, state: navigator.mediaSession.playbackState } : null));
  if (media === null) note('Media Session: missing in this engine');
  else check('Media Session: EarMind, playing', media.artist === 'EarMind' && media.state === 'playing', JSON.stringify(media));
  await shot('3-playing');
  if (await until('the next sentence is shown when it is read', () => document.querySelector('[data-testid=sentence]').textContent.startsWith('It happens'), page, live ? 30000 : 8000)) {
    check('the next sentence is shown when it is read', true);
  }
  await page.getByTestId('pause').click();
  check('one press pauses', await page.evaluate(() => document.querySelector('#sound').paused));
  await page.getByTestId('pause').click();
  await page.waitForTimeout(300);
  check('and goes on', await page.evaluate(() => !document.querySelector('#sound').paused));
  await page.getByTestId('stop').click();
  await page.getByTestId('play').waitFor();
  check('Stop: nothing plays', await page.evaluate(() => document.querySelector('#sound').paused));
  check('the text is under Recent', (await page.locator('.capsule.recent').count()) === 1);
  const save = calls.find((c) => c.fn === 'drill' && c.action === 'save');
  if (!live) check('marked as test traffic (x-earmind-test: toby), web language en', save?.headers['x-earmind-test'] === 'toby' && save?.headers['x-earmind-lang'] === 'en', JSON.stringify({ t: save?.headers['x-earmind-test'], l: save?.headers['x-earmind-lang'] }));

  // Prov från text, with credits for five questions only
  state.fits = 5;
  await page.getByTestId('new-quiz').click();
  await page.getByTestId('quiz-text').fill(`Plants${stamp} make sugar and oxygen from carbon dioxide, water and light. It happens in the chloroplasts, which hold chlorophyll.`);
  await shot('4-new-quiz');
  await page.getByTestId('quiz-create').click();
  if (live) {
    // A156 §4.2: a new web account's credits may not cover three questions; then the server's words and no purchase.
    await page.waitForFunction(() => document.querySelector('[data-testid=quiz-right]') || document.querySelector('[data-testid=quiz-error]'), null, { timeout: 90000 }).catch(() => undefined);
    if ((await page.getByTestId('quiz-right').count()) === 0) {
      await shot('5-quiz-refused');
      const said = (await page.getByTestId('quiz-error').count()) > 0 ? await text(page, 'quiz-error') : '';
      const under = (await page.getByTestId('quiz-sheet').innerText().catch(() => '')).replace(/\s+/g, ' ');
      check('Prov från text refused: the server’s words in the sheet', said.length > 0, said.slice(0, 200) || 'no quiz-error and no questions after 90 s');
      check('Prov från text refused: "Purchases come with the iOS app." under them, no purchase', /Purchases come with the iOS app/.test(under) && !/Buy|Top up|Fyll på/i.test(under), under.slice(0, 300));
      note('Prov från text: the server made no quiz for a new web account (A156 §4.2), so the quiz player was not reached live.');
      return finishLive(page, shot);
    }
    check('Prov från text: "Is this right?" with questions', (await page.locator('.questions li').count()) >= 3, `${await page.locator('.questions li').count()} questions; ${await text(page, 'quiz-note').catch(() => '')}`);
  } else {
    await page.getByTestId('quiz-right').waitFor();
    check('credits for five questions: five, and it says so', (await text(page, 'quiz-note')) === 'Your credits cover 5 questions.' && (await page.locator('.questions li').count()) === 5);
  }
  await shot('5-is-this-right');
  await page.getByTestId('quiz-right').click();
  await page.getByTestId('start-quiz').waitFor();
  await page.getByTestId('start-quiz').click();
  await page.getByTestId('player').waitFor();
  if (await until('Start quiz: the first question plays', () => (document.querySelector('[data-testid=question-number]')?.textContent ?? '').startsWith('Question 1 of') && !document.querySelector('#sound').paused, page, live ? 120000 : 15000)) {
    check('Start quiz: the first question plays', true, await text(page, 'question-number'));
  }
  await shot('6-question');
  await page.getByTestId('short').click();
  if (await until('two presses: the short answer', () => document.querySelector('[data-testid=phase]')?.textContent === 'Short answer', page, live ? 30000 : 15000)) {
    check('two presses: the short answer', (await text(page, 'phase')) === 'Short answer');
  }
  if (await until('then question 2', () => (document.querySelector('[data-testid=question-number]')?.textContent ?? '').startsWith('Question 2 of'), page, live ? 60000 : 10000)) check('then question 2', true);
  await page.getByTestId('quiz-pause').click();
  check('three presses pause', (await text(page, 'phase')) === 'Paused');
  await page.getByTestId('end').click();
  check('End: Continue · question 2', (await text(page, 'start-quiz')).includes('Continue · question 2'));

  await finishLive(page, shot);
});

await run('sv-light', { locale: 'sv-SE', colorScheme: 'light' }, async (page, shot) => {
  await page.goto(page0);
  if (await until('Swedish for a Swedish browser (D251)', () => /krediter/.test(document.querySelector('[data-testid=credits]')?.textContent ?? ''), page, 20000)) {
    const sv = await text(page, 'credits');
    check('Swedish for a Swedish browser (D251)', (live ? /krediter kvar$/.test(sv) : sv === '1,2k krediter kvar') && (await page.evaluate(() => document.documentElement.lang)) === 'sv', sv);
  }
  check('the Swedish screen line says 10 meter', /10\smeter/u.test(await text(page, 'screen-line')), JSON.stringify(await text(page, 'screen-line')).slice(0, 160));
  await page.getByTestId('say-field').fill(`Fotosyntes${stamp}: koldioxid + vatten + ljus blir socker och syre.`);
  await until('the cost shows under the field', () => !!document.querySelector('[data-testid=cost]'), page, 30000);
  await shot('1-first');
});

await run('small', { locale: 'en-GB', colorScheme: 'dark', viewport: { width: 320, height: 568 } }, async (page, shot) => {
  await page.goto(page0);
  await page.getByTestId('say-field').fill(`A short line${stamp}.`);
  await until('the cost shows under the field', () => !!document.querySelector('[data-testid=cost]'), page, 30000);
  check('320 wide: nothing is wider than the screen', await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth));
  await shot('1-first');
});

await browser.close();
server.close();
if (live) note(`hosts the page asked: ${[...hostsSeen].sort().join(', ')}`);
for (const line of serverLog.slice(0, 80)) console.log(`server [${engine}] ${line}`);
writeFileSync(join(out, 'result.json'), JSON.stringify({ engine, live: liveURL, results, notes }, null, 2));
console.log(failures.length === 0 ? `\n[${engine}] all ${results.length} checks passed.` : `\n[${engine}] ${failures.length} of ${results.length} failed: ${failures.join('; ')}`);
process.exit(failures.length === 0 ? 0 : 1);
