import { describe, expect, it } from 'vitest';
import { Client } from '../src/api/client';
import { DrillApi, type DrillView } from '../src/api/drill';
import { ExamApi } from '../src/api/exam';
import { App } from '../src/app';
import { Store } from '../src/store';
import { translator } from '../src/texts';
import { FakeClock, FakeSound, MemoryStorage, RoutedServer, type Scripted } from './fakes';

const ok = (body: unknown): Scripted => ({ status: 200, body });

function textView(id: string, done: boolean): DrillView {
  return {
    drill: { id, kind: 'text', audio_started: true, voice_name: 'Alice' },
    items: [
      {
        id: 'p1',
        text: 'One. Two.',
        sentences: ['One.', 'Two.'],
        audio: { text: done ? { status: 'done', url: 'https://files/p1.mp3', duration_ms: 2000, sentences: [[0, 1000], [1000, 2000]] } : { status: 'working' } },
      },
    ],
    audio: { done: done ? 1 : 0, total: 1 },
  };
}

function examView(id: string, started: boolean, questions = 3): DrillView {
  return {
    drill: { id, audio_started: started },
    items: Array.from({ length: questions }, (_, i) => ({
      id: `q${i}`,
      audio: started
        ? { question: { status: 'done', url: `https://files/q${i}.mp3`, duration_ms: 1000 }, long: { status: 'done', url: `https://files/a${i}.mp3`, duration_ms: 9000, short_end_ms: 2000 } }
        : undefined,
    })),
    audio: { done: started ? questions * 2 : 0, total: questions * 2, cost: 600 },
  };
}

class FakeAwake {
  log: string[] = [];
  async keep(): Promise<void> {
    this.log.push('keep');
  }
  async release(): Promise<void> {
    this.log.push('release');
  }
  get on(): boolean {
    return this.log[this.log.length - 1] === 'keep';
  }
}

/// The sound files as bytes, and the saved file as a pretend link.
class FakeFiles {
  asked: string[] = [];
  links: { name: string; bytes: number[] }[] = [];
  forgotten: string[] = [];
  failing = false;
  async bytes(url: string): Promise<Uint8Array> {
    this.asked.push(url);
    if (this.failing) throw new Error('offline');
    return new TextEncoder().encode(`[${url.split('/').pop()}]`);
  }
  link(bytes: Uint8Array, name: string): string {
    this.links.push({ name, bytes: [...bytes] });
    return `blob:${this.links.length}`;
  }
  forget(url: string): void {
    this.forgotten.push(url);
  }
}

function make(answer: ConstructorParameters<typeof RoutedServer>[0], storage = new MemoryStorage()) {
  const server = new RoutedServer(answer);
  const clock = new FakeClock();
  const client = new Client({ projectURL: 'https://example.supabase.co', publishableKey: 'pk' }, server.fetch, storage, () => clock.now(), 'web', 'en');
  const sound = new FakeSound();
  const awake = new FakeAwake();
  const store = new Store(storage);
  const files = new FakeFiles();
  const app = new App({ drill: new DrillApi(client), exam: new ExamApi(client), sound, clock, store, awake, files, t: translator('en') });
  return { app, server, clock, sound, awake, store, storage, files };
}

/// Lets what is waiting on the server run.
const settle = async (): Promise<void> => {
  for (let i = 0; i < 20; i += 1) await Promise.resolve();
  await new Promise((r) => setTimeout(r, 0));
};

describe('Säg i AirPods on the web', () => {
  it('Play starts the page audio at once, saves and starts in one call, and reads when the file is made', async () => {
    const { app, server, clock, sound, awake, store } = make((_fn, action, _b, nth) => {
      if (action === 'save') return ok(textView('d1', false));
      if (action === 'status') return ok(textView('d1', nth >= 1));
      if (action === 'quota') return ok({ limit: 1500, remaining: 1400 });
      return ok({});
    });
    const playing = app.say('One. Two.', ' calm ');
    expect(sound.log).toEqual(['silence']); // straight from the tap, before the server has answered
    expect(app.sayBusy).toBe(true);
    await playing;
    await settle();
    const save = server.calls.find((c) => c.action === 'save')!.body;
    expect(save.start).toBe(true);
    expect((save.drill as Record<string, unknown>).said).toBe(true);
    expect((save.drill as Record<string, unknown>).style).toBe('calm');
    expect(app.text?.phase).toBe('waiting'); // "Gör ljudet …"
    expect(app.soundProgress).toEqual({ done: 0, total: 1 });
    expect(awake.on).toBe(true);
    expect(store.said[0].serverID).toBe('d1');

    clock.advance(App.pollMs); // first status: still working
    await settle();
    clock.advance(App.pollMs); // second status: done
    await settle();
    clock.advance(2_000); // the player looks again
    expect(sound.last).toBe('play https://files/p1.mp3 0');
    expect(app.text?.phase).toBe('playing');
    expect(app.soundProgress).toBeNull();
    const asked = server.names().filter((n) => n === 'drill:status').length;
    clock.advance(60_000);
    await settle();
    expect(server.names().filter((n) => n === 'drill:status').length).toBe(asked); // every file is made: no more asking
  });

  it('the same text with the same sound is started again, not saved again', async () => {
    const storage = new MemoryStorage();
    const first = make((_fn, action) => (action === 'save' ? ok(textView('d1', true)) : ok({})), storage);
    await first.app.say('One. Two.', '');
    first.app.stopAll();
    const again = make((_fn, action) => (action === 'start' ? ok(textView('d1', true)) : ok({})), storage);
    await again.app.say('  One. Two.  \n\n', '');
    expect(again.server.names().filter((n) => n.startsWith('drill:s'))).toEqual(['drill:start']);
    expect(again.store.said.length).toBe(1);
    expect(again.app.text?.phase).toBe('playing');
  });

  it('a text the server no longer has is said anew', async () => {
    const storage = new MemoryStorage();
    const first = make((_fn, action) => (action === 'save' ? ok(textView('d1', true)) : ok({})), storage);
    await first.app.say('One. Two.', '');
    first.app.stopAll();
    const again = make((_fn, action) => {
      if (action === 'start') return { status: 404, body: { error: { code: 'not_found', message: 'gone' } } };
      if (action === 'save') return ok(textView('d2', true));
      return ok({});
    }, storage);
    await again.app.say('One. Two.', '');
    expect(again.store.said.map((s) => s.serverID)).toEqual(['d2']);
    expect(again.app.sayError).toBeNull();
  });

  it('out of credits: the server\'s words, nothing plays, the screen may sleep', async () => {
    const { app, sound, awake } = make((_fn, action) =>
      action === 'save' ? { status: 402, body: { error: { code: 'quota_exceeded', message: 'This text costs 900 credits. You have 120.' } } } : ok({}),
    );
    await app.say('One. Two.', '');
    expect(app.sayError).toBe('This text costs 900 credits. You have 120.');
    expect(app.sayOutOfCredits).toBe(true);
    expect(app.text).toBeNull();
    expect(app.sayBusy).toBe(false);
    expect(sound.last).toBe('stop');
    expect(awake.on).toBe(false);
  });

  it('Stop while the server works: the late answer starts nothing', async () => {
    let release: (v: Scripted) => void = () => undefined;
    const held = new Promise<Scripted>((r) => (release = r));
    const server = { pending: held };
    const { app, sound } = make((_fn, action) => (action === 'save' ? ({ status: 200, body: textView('d1', true), wait: server.pending } as Scripted) : ok({})));
    const playing = app.say('One. Two.', '');
    app.stopAll();
    release(ok({}));
    await playing;
    await settle();
    expect(app.text).toBeNull();
    expect(app.sayBusy).toBe(false);
    expect(sound.log.some((l) => l.startsWith('play'))).toBe(false);
  });

  it('presses reach the text: one pauses and goes on', async () => {
    const { app, sound } = make((_fn, action) => (action === 'save' ? ok(textView('d1', true)) : ok({})));
    await app.say('One. Two.', '');
    app.press(1);
    expect(app.text?.paused).toBe(true);
    expect(sound.last).toBe('pause');
    app.press(1);
    expect(app.text?.paused).toBe(false);
  });

  it('the cost is the server\'s number, and a text said before is free', async () => {
    const { app, store } = make((_fn, action) => (action === 'cost' ? ok({ cost: 340, remaining: 1500, enough: true }) : ok(textView('d1', true))));
    expect(await app.cost('One. Two.', '')).toBe(340);
    expect(await app.cost('   ', '')).toBeNull();
    await app.say('One. Two.', '');
    expect(store.said.length).toBe(1);
    expect(await app.cost('One. Two.', '')).toBe(0);
  });
});

describe('an exam from text on the web', () => {
  const questions = (n: number) => ({ summary: { subject: 'Biology', grade: '8', covers: 'Cells' }, notes: 'notes', items: Array.from({ length: n }, (_, i) => ({ id: `q${i}`, question: `Q${i}?` })) });
  const answers = (n: number) => ({ items: Array.from({ length: n }, (_, i) => ({ id: `q${i}`, question: `Q${i}?`, short: 's', long: 'l' })) });

  it('questions, Looks right, saved without sound; Start exam makes the sound and asks', async () => {
    const { app, server, sound, store, awake, clock } = make((fn, action) => {
      if (fn === 'exam' && action === 'drill') return ok(questions(3));
      if (fn === 'exam' && action === 'drill_answers') return ok(answers(3));
      if (action === 'save') return ok(examView('e1', false));
      if (action === 'start') return ok(examView('e1', true));
      return ok({});
    });
    app.openDraft();
    await app.makeQuestions('Cells are small.', 12);
    expect(app.draft.stage).toBe('check');
    await app.acceptExam();
    expect(app.draft.stage).toBe('closed');
    const save = server.calls.find((c) => c.action === 'save')!.body;
    expect(save.defer_audio).toBe(true);
    expect(store.exams[0]).toMatchObject({ serverID: 'e1', title: 'Biology', cost: 600, started: false });
    expect(sound.log.some((l) => l.startsWith('play'))).toBe(false);

    const starting = app.startExam(store.exams[0].id);
    expect(sound.last).toBe('silence');
    await starting;
    expect(sound.last).toBe('play https://files/q0.mp3 0');
    expect(awake.on).toBe(true);
    expect(store.exams[0].started).toBe(true);
    app.press(2); // the short answer
    expect(sound.last).toBe('play https://files/a0.mp3 0-2000');
    sound.end();
    expect(sound.last).toBe('play https://files/q1.mp3 0');
    expect(store.exams[0].index).toBe(1); // goes on from here next time
    sound.end();
    clock.advance(6_000); // three questions: six seconds to think
    expect(sound.last).toBe('play https://files/q2.mp3 0');
    app.stopAll();
    expect(awake.on).toBe(false);
    expect(app.quiz).toBeNull();
  });

  it('credits for fewer questions: the exam gets as many as fit, and says so', async () => {
    const { app, server } = make((fn, action, body) => {
      if (fn === 'exam' && action === 'drill') {
        if (body.questions === 12) return { status: 402, body: { error: { code: 'quota_exceeded', message: 'Not enough credits for 12 questions.' }, fits: 5, min_questions: 3 } };
        return ok(questions(Number(body.questions)));
      }
      return ok({});
    });
    await app.makeQuestions('Cells are small.', 12);
    expect(server.calls.filter((c) => c.fn === 'exam').map((c) => c.body.questions)).toEqual([12, 5]);
    expect(app.draft).toMatchObject({ stage: 'check', count: 5, note: 'Your credits cover 5 questions.' });
  });

  it('credits for fewer than three: no exam, the server\'s words', async () => {
    const { app, server } = make((fn, action) =>
      fn === 'exam' && action === 'drill' ? { status: 402, body: { error: { code: 'quota_exceeded', message: 'An exam needs at least 3 questions. Your credits cover 2.' }, fits: 2, min_questions: 3 } } : ok({}),
    );
    await app.makeQuestions('Cells are small.', 12);
    expect(server.calls.filter((c) => c.fn === 'exam').length).toBe(1);
    expect(app.draft).toEqual({ stage: 'write', error: 'An exam needs at least 3 questions. Your credits cover 2.' });
  });

  it('"Something is wrong" sends the notes and the line, not the text again', async () => {
    const { app, server } = make((fn, action) => (fn === 'exam' && action === 'drill' ? ok(questions(3)) : ok({})));
    await app.makeQuestions('A long text about cells.', 3);
    await app.correct('It is about chapter 4.');
    const second = server.calls.filter((c) => c.fn === 'exam')[1].body;
    expect(second.text).toBe('notes');
    expect(second.correction).toBe('It is about chapter 4.');
    expect(app.draft.stage).toBe('check');
  });

  it('Start exam refused for credits: the server\'s words on that exam, nothing plays', async () => {
    const { app, store, sound, awake } = make((fn, action) => {
      if (fn === 'exam' && action === 'drill') return ok(questions(3));
      if (fn === 'exam') return ok(answers(3));
      if (action === 'save') return ok(examView('e1', false));
      if (action === 'start') return { status: 402, body: { error: { code: 'quota_exceeded', message: 'This exam costs 600 credits. You have 100.' } } };
      return ok({});
    });
    await app.makeQuestions('Cells.', 3);
    await app.acceptExam();
    const id = store.exams[0].id;
    await app.startExam(id);
    expect(app.examError).toEqual({ id, message: 'This exam costs 600 credits. You have 100.' });
    expect(app.quiz).toBeNull();
    expect(app.examBusy).toBeNull();
    expect(awake.on).toBe(false);
    expect(sound.log.some((l) => l.startsWith('play'))).toBe(false);
  });

  it('Delete takes it away here and on the server', async () => {
    const { app, store, server } = make((fn, action) => {
      if (fn === 'exam' && action === 'drill') return ok(questions(3));
      if (fn === 'exam') return ok(answers(3));
      if (action === 'save') return ok(examView('e1', false));
      return ok({});
    });
    await app.makeQuestions('Cells.', 3);
    await app.acceptExam();
    await app.deleteExam(store.exams[0].id);
    expect(store.exams).toEqual([]);
    expect(server.calls.find((c) => c.action === 'delete')?.body.id).toBe('e1');
  });
});

describe('Open link: a quiz someone shared', () => {
  const shared = (): DrillView => ({
    drill: { id: 'copy1', title: 'Cells', audio_started: true },
    items: [0, 1, 2].map((i) => ({
      id: `q${i}`,
      question: `Q${i}?`,
      short: `s${i}`,
      long: `l${i}`,
      audio: { question: { status: 'done', url: `https://files/q${i}.mp3`, duration_ms: 1000 }, long: { status: 'done', url: `https://files/a${i}.mp3`, duration_ms: 9000, short_end_ms: 2000 } },
    })),
    audio: { done: 6, total: 6 },
  });

  it('shows what the link holds, then adds it as the user\'s own quiz for nothing', async () => {
    const { app, server, store, sound } = make((_fn, action) => {
      if (action === 'share_info') return ok({ title: 'Cells', subject: 'Biology', grade: '8', items: 3, audio_ready: true });
      if (action === 'import') return ok({ ...shared(), new_chars: 0 });
      if (action === 'start') return ok(shared());
      return ok({});
    });
    app.openLink();
    await app.lookUp('  https://earmind.vercel.app/p/abc12345  ');
    expect(app.link).toMatchObject({ stage: 'found', code: 'https://earmind.vercel.app/p/abc12345', info: { title: 'Cells', items: 3 } });
    expect(server.calls.find((c) => c.action === 'share_info')?.body.code).toBe('https://earmind.vercel.app/p/abc12345');
    await app.addShared();
    expect(app.link.stage).toBe('closed');
    expect(store.exams[0]).toMatchObject({ serverID: 'copy1', title: 'Cells', cost: 0, started: true });
    expect(store.exams[0].questions.map((q) => q.short)).toEqual(['s0', 's1', 's2']);
    await app.startExam(store.exams[0].id);
    expect(sound.last).toBe('play https://files/q0.mp3 0');
  });

  it('a dead link: the server\'s words, nothing is added', async () => {
    const { app, store } = make((_fn, action) => (action === 'share_info' ? { status: 404, body: { error: { code: 'share_not_found', message: 'The link no longer works.' } } } : ok({})));
    app.openLink();
    await app.lookUp('abc12345');
    expect(app.link).toEqual({ stage: 'ask', error: 'The link no longer works.', busy: false });
    expect(store.exams).toEqual([]);
  });

  it('nothing pasted asks nothing of the server', async () => {
    const { app, server } = make(() => ok({}));
    app.openLink();
    await app.lookUp('   ');
    expect(server.calls.length).toBe(0);
  });

  it('a shared text is not a quiz: said, not added as one', async () => {
    const { app, store } = make((_fn, action) => {
      if (action === 'share_info') return ok({ title: 'Notes', items: 4, audio_ready: true });
      if (action === 'import') return ok({ drill: { id: 't1', kind: 'text', title: 'Notes' }, items: [{ id: 'p', text: 'One.' }], audio: { done: 1, total: 1 } });
      return ok({});
    });
    app.openLink();
    await app.lookUp('abc12345');
    await app.addShared();
    expect(store.exams).toEqual([]);
    expect(app.link).toMatchObject({ stage: 'found', error: 'This link is a text to read aloud. The beta can only open quizzes with questions for now.' });
  });
});

describe('Download the sound (D253)', () => {
  const said = (text: string): string => new TextDecoder().decode(new Uint8Array(JSON.parse(text) as number[]));

  it('a text: asks the server for fresh links, fetches every part once and offers one MP3', async () => {
    const { app, server, files } = make((_fn, action) => (action === 'save' || action === 'status' ? ok(textView('d1', true)) : ok({})));
    await app.say('One. Two.', '');
    expect(app.download).toEqual({ stage: 'idle' });
    await app.prepareDownload();
    expect(server.names()).toContain('drill:status'); // the links are good for an hour: fresh ones for the download
    expect(files.asked).toEqual(['https://files/p1.mp3']);
    expect(app.download).toEqual({ stage: 'ready', url: 'blob:1', name: 'EarMind - One. Two.mp3' });
    expect(said(JSON.stringify(files.links[0].bytes))).toBe('[p1.mp3]');
    await app.prepareDownload(); // already there: nothing is fetched twice
    expect(files.asked.length).toBe(1);
  });

  it('a quiz: every question followed by its long answer, in order', async () => {
    const { app, store, files } = make((fn, action) => {
      if (fn === 'exam' && action === 'drill') return ok({ summary: { subject: 'Biology', grade: '8', covers: 'Cells' }, notes: 'n', items: [0, 1, 2].map((i) => ({ id: `q${i}`, question: `Q${i}?` })) });
      if (fn === 'exam') return ok({ items: [0, 1, 2].map((i) => ({ id: `q${i}`, question: `Q${i}?`, short: 's', long: 'l' })) });
      if (action === 'save') return ok(examView('e1', false));
      return ok(examView('e1', true));
    });
    await app.makeQuestions('Cells.', 3);
    await app.acceptExam();
    await app.startExam(store.exams[0].id);
    await app.prepareDownload();
    expect(files.asked.map((u) => u.split('/').pop())).toEqual(['q0.mp3', 'a0.mp3', 'q1.mp3', 'a1.mp3', 'q2.mp3', 'a2.mp3']);
    expect(said(JSON.stringify(files.links[0].bytes))).toBe('[q0.mp3][a0.mp3][q1.mp3][a1.mp3][q2.mp3][a2.mp3]');
    expect(app.download).toMatchObject({ stage: 'ready', name: 'EarMind - Biology.mp3' });
  });

  it('not while the sound is still being made', async () => {
    const { app, files } = make((_fn, action) => (action === 'save' || action === 'status' ? ok(textView('d1', false)) : ok({})));
    await app.say('One. Two.', '');
    await app.prepareDownload();
    expect(files.asked).toEqual([]);
    expect(app.download).toEqual({ stage: 'idle' });
  });

  it('a file that cannot be fetched: says so, and a new try starts over', async () => {
    const { app, files } = make((_fn, action) => (action === 'save' || action === 'status' ? ok(textView('d1', true)) : ok({})));
    await app.say('One. Two.', '');
    files.failing = true;
    await app.prepareDownload();
    expect(app.download).toEqual({ stage: 'failed' });
    files.failing = false;
    await app.prepareDownload();
    expect(app.download.stage).toBe('ready');
  });

  it('Stop takes the file away again', async () => {
    const { app, files } = make((_fn, action) => (action === 'save' || action === 'status' ? ok(textView('d1', true)) : ok({})));
    await app.say('One. Two.', '');
    await app.prepareDownload();
    app.stopAll();
    expect(app.download).toEqual({ stage: 'idle' });
    expect(files.forgotten).toEqual(['blob:1']);
  });
});

describe('small things the others asked for', () => {
  it('the voices of the user\'s language come first (Kevin K114)', async () => {
    const { app } = make((fn) =>
      fn === 'voices'
        ? ok({ catalog: [{ voice_id: 's1', name: 'Saga', language: 'sv' }, { voice_id: 'e1', name: 'Niki', language: 'en' }, { voice_id: 'x', name: 'Any' }, { voice_id: 'e2', name: 'Chris', language: 'en-GB' }], default_voice: { name: 'Adam' } })
        : ok({ limit: 1500, remaining: 1500 }),
    );
    await app.init();
    expect(app.voices.map((v) => v.name)).toEqual(['Niki', 'Chris', 'Saga', 'Any']);
  });

  it('a server that cannot be reached with the network up is not blamed on the connection (Oscar O94)', async () => {
    const storage = new MemoryStorage();
    const clock = new FakeClock();
    const dead = async (): Promise<Response> => {
      throw new TypeError('Failed to fetch');
    };
    const client = new Client({ projectURL: 'https://example.supabase.co', publishableKey: 'pk' }, dead, storage, () => clock.now(), 'web', 'en');
    const base = { drill: new DrillApi(client), exam: new ExamApi(client), sound: new FakeSound(), clock, store: new Store(storage), awake: new FakeAwake(), files: new FakeFiles(), t: translator('en') };
    const up = new App({ ...base, online: () => true });
    await up.say('One.', '');
    expect(up.sayError).toBe('EarMind couldn\u2019t be reached right now. Try again in a moment.');
    const down = new App({ ...base, online: () => false });
    await down.say('One.', '');
    expect(down.sayError).toBe('The sound couldn\u2019t be loaded. Check your connection.');
  });

  it('Play stops listening first: one thing at a time', async () => {
    const storage = new MemoryStorage();
    const server = new RoutedServer((_fn, action) => (action === 'save' ? ok(textView('d1', true)) : ok({})));
    const clock = new FakeClock();
    const client = new Client({ projectURL: 'https://example.supabase.co', publishableKey: 'pk' }, server.fetch, storage, () => clock.now(), 'web', 'en');
    let stopped = 0;
    const app = new App({ drill: new DrillApi(client), exam: new ExamApi(client), sound: new FakeSound(), clock, store: new Store(storage), awake: new FakeAwake(), files: new FakeFiles(), t: translator('en'), stopListening: () => (stopped += 1) });
    await app.say('One. Two.', '');
    expect(stopped).toBe(1);
  });
});

describe('the model behind EarMind is out of credits, busy or down (O97)', () => {
  const down = (code: string, status = 503): Scripted => ({ status, body: { error: { code, message: 'LLM credits exhausted', fallback: true } } });
  const own = 'EarMind can\u2019t answer right now. Try again in a while.';

  it('Play: our own short words, never the server\'s technical ones; nothing is started, so nothing is counted', async () => {
    const { app, server, sound } = make((_fn, action) => (action === 'save' ? down('provider_quota') : ok({})));
    await app.say('One. Two.', '');
    expect(app.sayError).toBe(own);
    expect(app.sayOutOfCredits).toBe(false); // the user's credits are not what ran out
    expect(app.text).toBeNull();
    expect(server.names().filter((n) => n === 'drill:start' || n === 'drill:status')).toEqual([]);
    expect(sound.log.some((l) => l.startsWith('play'))).toBe(false);
  });

  it('New quiz: the same words, and no quiz is saved', async () => {
    const { app, server, store } = make((fn, action) => (fn === 'exam' && action === 'drill' ? down('provider_busy') : ok({})));
    await app.makeQuestions('Cells are small.', 12);
    expect(app.draft).toEqual({ stage: 'write', error: own });
    expect(server.names()).not.toContain('drill:save');
    expect(store.exams).toEqual([]);
  });

  it('the answers cannot be written: the questions stay, nothing is saved', async () => {
    const { app, server } = make((fn, action) => {
      if (fn === 'exam' && action === 'drill') return ok({ summary: { subject: 'Biology', grade: '8', covers: 'Cells' }, notes: 'n', items: [0, 1, 2].map((i) => ({ id: `q${i}`, question: `Q${i}?` })) });
      if (fn === 'exam') return down('provider_unavailable', 502);
      return ok({});
    });
    await app.makeQuestions('Cells.', 3);
    await app.acceptExam();
    expect(app.draft).toMatchObject({ stage: 'check', error: own });
    expect(server.names()).not.toContain('drill:save');
  });

  it('Start quiz: the same words on that quiz', async () => {
    const { app, store } = make((fn, action) => {
      if (fn === 'exam' && action === 'drill') return ok({ summary: { subject: 'Biology', grade: '8', covers: 'Cells' }, notes: 'n', items: [0, 1, 2].map((i) => ({ id: `q${i}`, question: `Q${i}?` })) });
      if (fn === 'exam') return ok({ items: [0, 1, 2].map((i) => ({ id: `q${i}`, question: `Q${i}?`, short: 's', long: 'l' })) });
      if (action === 'save') return ok(examView('e1', false));
      if (action === 'start') return down('provider_unconfigured');
      return ok({});
    });
    await app.makeQuestions('Cells.', 3);
    await app.acceptExam();
    await app.startExam(store.exams[0].id);
    expect(app.examError?.message).toBe(own);
    expect(app.quiz).toBeNull();
  });

  it('in Swedish when Swedish is chosen', () => {
    expect(translator('sv')('errorProvider')).toBe('EarMind kan inte svara just nu. Försök igen om en stund.');
  });
});

