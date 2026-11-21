// A156: the built beta (site/beta) in a real browser against a pretend server. No request leaves the machine:
// the server's address is answered here, and the "sound" is a silent WAV made here (D180: 0 ElevenLabs).
//   node web/scripts/smoke.mjs [out-dir]        (from the repository root, after `npm run build` in web/)
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { mkdirSync } from 'node:fs';
import { extname, join, resolve } from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  ({ chromium } = await import('playwright'));
}

const site = resolve(new URL('../../site', import.meta.url).pathname);
const out = resolve(process.argv[2] ?? 'smoke-out');
mkdirSync(out, { recursive: true });

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
    if (body.action === 'start') return json(body.id === 'e1' || body.id === 'copy1' ? quizView(true) : textView(true));
    if (body.action === 'share_info') {
      if (!String(body.code).includes('abc12345')) return json({ error: { code: 'share_not_found', message: 'The link no longer works.' } }, 404);
      return json({ title: 'Cells and leaves', subject: 'Biology', grade: 'Year 8', items: 5, audio_ready: true });
    }
    if (body.action === 'import') {
      const copy = quizView(true);
      return json({ ...copy, drill: { id: 'copy1', title: 'Cells and leaves', audio_started: true }, items: copy.items.map((it) => ({ ...it, short: 'Sugar and oxygen.', long: 'A longer answer.' })), new_chars: 0 });
    }
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

const failures = [];
const check = (name, ok, detail = '') => {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}${detail ? ` (${detail})` : ''}`);
  if (!ok) failures.push(name);
};

const browser = await chromium.launch({ args: ['--autoplay-policy=user-gesture-required'] });

async function run(name, { locale, colorScheme, width = 393, height = 852, scale = 2 }, steps) {
  const context = await browser.newContext({ locale, colorScheme, viewport: { width, height }, deviceScaleFactor: scale, hasTouch: true, isMobile: true });
  await context.grantPermissions(['screen-wake-lock']).catch(() => undefined);
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  // The browser itself logs the pretend server's 402 (no credits): that one is part of the script.
  page.on('console', (m) => (m.type() === 'error' && !/status of 40[24]/.test(m.text()) ? errors.push(m.text()) : undefined));
  await page.route('https://xjczbzfkmbjdebwlccki.supabase.co/**', answer);
  await page.route('https://files.test/**', answer);
  const outside = [];
  page.on('request', (r) => {
    const host = new URL(r.url()).hostname;
    if (!['127.0.0.1', 'xjczbzfkmbjdebwlccki.supabase.co', 'files.test'].includes(host) && !r.url().startsWith('data:')) outside.push(r.url());
  });
  const shot = async (label) => {
    await page.waitForTimeout(450); // a sheet has come up before the picture is taken
    await page.screenshot({ path: join(out, `${name}-${label}.png`) });
  };
  await steps(page, shot);
  check(`${name}: no script errors`, errors.length === 0, errors.join(' | ').slice(0, 300));
  check(`${name}: nothing asked outside the pretend server`, outside.length === 0, outside.join(' ').slice(0, 200));
  await context.close();
}

await run('en-dark', { locale: 'en-US', colorScheme: 'dark' }, async (page, shot) => {
  await page.goto(`${base}/beta?test=smoke`);
  await page.getByTestId('credits').waitFor();
  await page.waitForFunction(() => document.querySelector('[data-testid=credits]').textContent.includes('1.2k'));
  check('English by default, credits as 1.2k', (await page.getByTestId('credits').textContent()) === '1.2k credits left');
  check('one New quiz button on the first screen, not two (A158)', (await page.getByRole('button', { name: 'New quiz' }).count()) === 1);
  check('the screen line shows the first time, with 10 m', (await page.getByTestId('screen-line').textContent()).includes('10 m (33 ft)'));
  await shot('1-first');
  await page.getByTestId('say-field').fill('Photosynthesis: carbon dioxide + water + light become sugar and oxygen. It happens in the chloroplasts.');
  await page.getByTestId('cost').waitFor();
  check('the cost is the server’s number', (await page.getByTestId('cost').textContent()) === '102 credits');
  await shot('2-text');
  await page.getByTestId('voice').click();
  await page.getByTestId('voices-sheet').waitFor();
  check('voices under review are not offered', (await page.getByTestId('voice-row').count()) === 2);
  check('the chosen voice is marked for VoiceOver too', (await page.getByTestId('voice-row').nth(0).getAttribute('aria-pressed')) === 'false');
  await shot('3-voices');
  await page.getByTestId('voice-row').nth(1).click();
  await page.getByTestId('sheet-done').click();
  check('the chosen voice is on the capsule', (await page.getByTestId('voice').textContent()) === 'Oliver');
  await page.getByTestId('play').click();
  await page.getByTestId('status').waitFor();
  await page.waitForFunction(() => document.querySelector('[data-testid=status]')?.textContent.includes('Playing in AirPods'), null, { timeout: 15000 });
  await page.waitForFunction(() => !document.querySelector('#sound').paused && document.querySelector('#sound').src.includes('files.test'));
  check('the sound plays on the page’s one audio element', true);
  // A headless browser may refuse Wake Lock; then the check says so instead of pretending.
  const lock = await page.evaluate(() => (navigator.wakeLock ? navigator.wakeLock.request('screen').then((l) => l.release().then(() => 'granted'), (e) => e.name) : 'missing'));
  if (lock === 'granted') check('the screen is kept on while it plays (Wake Lock)', (await page.locator('.playing-host').textContent()).includes('The screen stays on while it plays.'));
  else console.log(`skip the screen is kept on while it plays (this browser answers Wake Lock with: ${lock})`);
  check('the lock screen is told what plays (Media Session)', await page.evaluate(() => navigator.mediaSession.metadata?.artist === 'EarMind' && navigator.mediaSession.playbackState === 'playing'));
  await shot('4-playing');
  await page.waitForFunction(() => document.querySelector('[data-testid=sentence]').textContent.startsWith('It happens'), null, { timeout: 8000 });
  check('the sentence being read is the one shown', true);
  // D253: Download the sound. One MP3 of what plays, from the files the server already made.
  await page.getByTestId('download').click();
  await page.getByTestId('download-save').waitFor();
  const saved = await page.evaluate(async () => {
    const a = document.querySelector('[data-testid=download-save]');
    const blob = await (await fetch(a.href)).blob();
    return { name: a.getAttribute('download'), size: blob.size, type: blob.type };
  });
  check('Download the sound: a file to save, named after the text', saved.name === 'EarMind - Photosynthesis carbon dioxide.mp3' && saved.type === 'audio/mpeg' && saved.size > 20000, JSON.stringify(saved));
  await shot('4b-download');
  await page.getByTestId('pause').click();
  check('one press pauses', await page.evaluate(() => document.querySelector('#sound').paused));
  await page.getByTestId('pause').click();
  check('and goes on', await page.evaluate(() => !document.querySelector('#sound').paused));
  await page.getByTestId('stop').click();
  await page.getByTestId('play').waitFor();
  check('Stop: nothing plays', await page.evaluate(() => document.querySelector('#sound').paused && navigator.mediaSession.playbackState === 'none'));
  check('the text is under Recent', (await page.locator('.capsule.recent').count()) === 1);
  const save = calls.find((c) => c.fn === 'drill' && c.action === 'save');
  check('saved as a said text with the voice, started in one call', save.body.start === true && save.body.drill.said === true && save.body.drill.voice_id === 'v2' && save.body.lang === 'en');
  check('marked as test traffic, with the web’s language', save.headers['x-earmind-test'] === 'smoke' && save.headers['x-earmind-lang'] === 'en');
  await page.getByTestId('credits').click();
  await page.getByTestId('credits-sheet').waitFor();
  check('Credits: the number, and no purchases on the web', (await page.getByTestId('credits-number').textContent()) === '1,236' && (await page.getByTestId('no-purchases').textContent()) === 'Purchases come with the iOS app.');
  await shot('5-credits');
  await page.getByTestId('sheet-done').click();
  check('after the first time the line shows only while something plays', (await page.getByTestId('screen-line').count()) === 0);
  await page.getByTestId('settings').click();
  await page.getByRole('button', { name: 'Keep the screen on' }).click();
  await page.getByTestId('guide-sheet').waitFor();
  check('the guide names Auto-Lock', (await page.getByTestId('guide-sheet').textContent()).includes('Auto-Lock › Never'));
  await shot('6-guide');
  await page.getByTestId('sheet-done').click();

  // A quiz from text, with credits for five questions only.
  state.fits = 5;
  await page.getByTestId('new-quiz').click();
  await page.getByTestId('quiz-text').fill('Plants make sugar and oxygen from carbon dioxide, water and light. It happens in the chloroplasts, which hold chlorophyll.');
  await shot('7-new-quiz');
  await page.getByTestId('quiz-create').click();
  await page.getByTestId('quiz-right').waitFor();
  check('credits for five questions: the quiz gets five, and says so', (await page.getByTestId('quiz-note').textContent()) === 'Your credits cover 5 questions.' && (await page.locator('.questions li').count()) === 5);
  await shot('8-is-this-right');
  await page.getByTestId('quiz-right').click();
  await page.getByTestId('start-quiz').waitFor();
  check('saved without sound; the card says what Start costs', (await page.getByTestId('quiz').textContent()).includes('640 credits when you start'));
  await shot('9-quiz-card');
  await page.getByTestId('start-quiz').click();
  await page.getByTestId('player').waitFor();
  await page.waitForFunction(() => document.querySelector('#sound').src.includes('/q0.wav') && !document.querySelector('#sound').paused);
  check('Start quiz asks the first question', (await page.getByTestId('question-number').textContent()) === 'Question 1 of 5');
  await shot('10-question');
  await page.getByTestId('short').click();
  await page.waitForFunction(() => document.querySelector('#sound').src.includes('/a0.wav'));
  check('two presses: the short answer', (await page.getByTestId('phase').textContent()) === 'Short answer');
  await shot('11-answer');
  await page.waitForFunction(() => document.querySelector('[data-testid=question-number]').textContent === 'Question 2 of 5', null, { timeout: 8000 });
  check('the short answer ends where the server says, then the next question', true);
  await page.waitForFunction(() => document.querySelector('[data-testid=phase]').textContent === 'Think', null, { timeout: 8000 });
  await shot('12-think');
  await page.getByTestId('quiz-pause').click();
  check('three presses pause', (await page.getByTestId('phase').textContent()) === 'Paused');
  await page.getByTestId('end').click();
  check('End: back on the first screen, continues where it was', (await page.getByTestId('start-quiz').textContent()).includes('Continue · question 2'));
  // Open link: a quiz someone shared costs nothing.
  await page.getByTestId('open-link').click();
  await page.getByTestId('link-field').fill('nothing-here');
  await page.getByTestId('link-open').click();
  await page.getByTestId('link-error').waitFor();
  check('a dead link: the server\u2019s words, and what was pasted stays', (await page.getByTestId('link-error').textContent()) === 'The link no longer works.' && (await page.getByTestId('link-field').inputValue()) === 'nothing-here');
  await page.getByTestId('link-field').fill('https://earmind.vercel.app/p/abc12345');
  await page.getByTestId('link-open').click();
  await page.getByTestId('link-found').waitFor();
  await shot('13-open-link');
  await page.getByTestId('link-add').click();
  await page.waitForFunction(() => document.querySelectorAll('[data-testid=quiz]').length === 2);
  check('the shared quiz is added and costs nothing', !(await page.getByTestId('quiz').first().textContent()).includes('credits when you start') && (await page.getByTestId('quiz').first().textContent()).includes('Cells and leaves'));
  await shot('14-two-quizzes');
  const exam = calls.find((c) => c.fn === 'exam');
  check('the exam is asked for in the web’s language', exam.body.lang === 'en' && exam.body.answers === false);
});

await run('sv-light', { locale: 'sv-SE', colorScheme: 'light' }, async (page, shot) => {
  await page.goto(`${base}/beta?test=smoke`);
  await page.waitForFunction(() => document.querySelector('[data-testid=credits]')?.textContent.includes('1.2k'));
  check('a Swedish browser also starts in English (D253)', (await page.getByTestId('credits').textContent()) === '1.2k credits left' && (await page.evaluate(() => document.documentElement.lang)) === 'en');
  check('the EN/SV choice shows, with EN chosen', (await page.getByTestId('lang-en').getAttribute('aria-pressed')) === 'true' && (await page.getByTestId('lang-sv').isVisible()));
  await page.getByTestId('say-field').fill('Fotosyntes: koldioxid + vatten + ljus blir socker och syre.');
  await page.getByTestId('cost').waitFor();
  await page.getByTestId('lang-sv').click();
  await page.waitForFunction(() => document.querySelector('[data-testid=credits]')?.textContent.includes('1,2k'));
  check('SV changes everything to Swedish', (await page.getByTestId('credits').textContent()) === '1,2k krediter kvar' && (await page.evaluate(() => document.documentElement.lang)) === 'sv');
  check('what was typed comes along', (await page.getByTestId('say-field').inputValue()).startsWith('Fotosyntes'));
  check('the Swedish line says 10 meter', (await page.getByTestId('screen-line').textContent()).includes('10 meter'));
  await page.getByTestId('cost').waitFor();
  const last = calls[calls.length - 1];
  check('the server gets the chosen language', last.headers['x-earmind-lang'] === 'sv' && last.body.lang === 'sv', `${last.fn}:${last.action}`);
  await page.reload();
  await page.waitForFunction(() => document.querySelector('[data-testid=credits]')?.textContent.includes('1,2k'));
  check('the choice is kept the next time', (await page.evaluate(() => document.documentElement.lang)) === 'sv' && (await page.getByTestId('lang-sv').getAttribute('aria-pressed')) === 'true');
  await page.getByTestId('say-field').fill('Fotosyntes: koldioxid + vatten + ljus blir socker och syre.');
  await page.getByTestId('cost').waitFor();
  await shot('1-first');
  await page.getByTestId('settings').click();
  await shot('2-settings');
});

await run('small', { locale: 'en-GB', colorScheme: 'dark', width: 320, height: 568 }, async (page, shot) => {
  await page.goto(`${base}/beta?test=smoke`);
  await page.getByTestId('say-field').fill('A short line.');
  await page.getByTestId('cost').waitFor();
  await page.getByTestId('lang-sv').click();
  await page.getByTestId('cost').waitFor();
  check('320 wide in Swedish: nothing is wider than the screen', await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth));
  await shot('2-svenska');
  await page.getByTestId('lang-en').click();
  await page.getByTestId('cost').waitFor();
  check('320 wide: nothing is wider than the screen', await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth));
  await shot('1-first');
});

await browser.close();
server.close();
console.log(failures.length === 0 ? '\nAll checks passed.' : `\n${failures.length} failed: ${failures.join('; ')}`);
process.exit(failures.length === 0 ? 0 : 1);
