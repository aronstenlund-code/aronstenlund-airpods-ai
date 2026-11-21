import { describe, expect, it } from 'vitest';
import { ApiError } from '../src/api/client';
import type { AnswerRequest } from '../src/api/listen';
import type { SttToken } from '../src/listen/scribe';
import { ListenSession, type Line } from '../src/listen/session';
import type { ServerEvent } from '../src/listen/sse';
import { translator } from '../src/texts';
import { FakeClock, FakeSound } from './fakes';

class FakeMic {
  on = false;
  refuse = false;
  private block: ((samples: Int16Array, level: number) => void) | null = null;
  async start(onBlock: (samples: Int16Array, level: number) => void): Promise<void> {
    if (this.refuse) throw new Error('NotAllowedError');
    this.on = true;
    this.block = onBlock;
  }
  stop(): void {
    this.on = false;
    this.block = null;
  }
  speak(samples = 1600): void {
    this.block?.(new Int16Array(samples).fill(100), 0.2);
  }
}

class FakeLine implements Line {
  sent: Record<string, unknown>[] = [];
  open = true;
  onMessage: ((raw: string) => void) | null = null;
  onClose: (() => void) | null = null;
  constructor(readonly url: string) {}
  send(text: string): void {
    this.sent.push(JSON.parse(text) as Record<string, unknown>);
  }
  close(): void {
    this.open = false;
  }
  say(type: string, text: string): void {
    this.onMessage?.(JSON.stringify({ message_type: type, text }));
  }
}

type Script = (request: AnswerRequest, emit: (event: ServerEvent) => void, signal: AbortSignal) => Promise<void>;

function make(options: { token?: SttToken | Error; answer?: Script; speak?: (text: string) => Promise<Uint8Array> } = {}) {
  const clock = new FakeClock();
  const sound = new FakeSound();
  const mic = new FakeMic();
  const lines: FakeLine[] = [];
  const asked: AnswerRequest[] = [];
  const spoken: string[] = [];
  const reported: number[] = [];
  const awake: string[] = [];
  const links: string[] = [];
  const forgotten: string[] = [];
  let tokens = 0;
  const session = new ListenSession({
    api: {
      token: async () => {
        tokens += 1;
        const token = options.token ?? { token: `tok${tokens}`, ws_url: 'wss://stt.example/rt', model_id: 'scribe_v2_realtime' };
        if (token instanceof Error) throw token;
        return token;
      },
      report: async (seconds) => {
        reported.push(seconds);
      },
      answer: async (request, emit, signal) => {
        asked.push(request);
        await (options.answer ?? (async (_r, e) => {
          e({ event: 'meta', data: { is_question: true } });
          e({ event: 'delta', data: { text: 'A cell is small. ' } });
          e({ event: 'delta', data: { text: 'It has a core.' } });
          e({ event: 'done', data: { answered: true } });
        }))(request, emit, signal);
      },
      speak: async (text) => {
        spoken.push(text);
        return options.speak ? options.speak(text) : new Uint8Array([1, 2, 3]);
      },
    },
    mic,
    open: (url) => {
      const line = new FakeLine(url);
      lines.push(line);
      return line;
    },
    sound,
    files: {
      link: () => {
        links.push(`blob:${links.length + 1}`);
        return links[links.length - 1];
      },
      forget: (url) => {
        forgotten.push(url);
      },
    },
    clock,
    awake: {
      keep: async () => {
        awake.push('keep');
      },
      release: async () => {
        awake.push('release');
      },
    },
    lang: 'en',
    voiceID: () => 'v2',
    t: translator('en'),
    stopOthers: () => undefined,
  });
  return { session, clock, sound, mic, lines, asked, spoken, reported, awake, links, forgotten, tokens: () => tokens };
}

const settle = async (): Promise<void> => {
  for (let i = 0; i < 30; i += 1) await Promise.resolve();
  await new Promise((r) => setTimeout(r, 0));
};

describe('listening on the web (A156 part 2)', () => {
  it('Start: the page audio at once, the screen kept on, the microphone, a token, the socket', async () => {
    const { session, sound, mic, lines, awake } = make();
    const starting = session.start();
    expect(sound.log).toEqual(['silence']); // straight from the tap
    expect(session.phase).toBe('starting');
    await starting;
    expect(session.phase).toBe('listening');
    expect(mic.on).toBe(true);
    expect(awake).toEqual(['keep']);
    expect(lines[0].url).toContain('token=tok1');
    expect(lines[0].url).toContain('language_code=eng');
    mic.speak();
    expect(lines[0].sent[0]).toMatchObject({ message_type: 'input_audio_chunk', commit: false, sample_rate: 16000 });
  });

  it('a turn that ends is sent, answered and read sentence by sentence; nothing is sent from the microphone meanwhile', async () => {
    const { session, clock, sound, mic, lines, asked, spoken, forgotten } = make();
    await session.start();
    lines[0].say('partial_transcript', 'what is');
    expect(session.heard).toBe('what is');
    lines[0].say('committed_transcript', 'What is a cell?');
    clock.advance(ListenSession.turnWaitMs);
    await settle();
    expect(asked[0].fragment).toBe('What is a cell?');
    expect(session.phase).toBe('answering');
    expect(session.answer).toBe('A cell is small. It has a core.');
    expect(spoken).toEqual(['A cell is small.', 'It has a core.']);
    expect(sound.last).toBe('play blob:1 0');
    const before = lines[0].sent.length;
    mic.speak();
    expect(lines[0].sent.length).toBe(before); // half duplex: the answer is never heard as a question
    sound.end();
    await settle();
    expect(sound.last).toBe('play blob:2 0');
    sound.end();
    await settle();
    expect(session.phase).toBe('listening');
    expect(sound.last).toBe('silence');
    expect(forgotten).toEqual(['blob:1', 'blob:2']);
    mic.speak();
    expect(lines[0].sent.length).toBe(before + 1);
    // The next question carries the last one, so "and how big is it?" has something to point at.
    lines[0].say('committed_transcript', 'And how big is it?');
    clock.advance(ListenSession.turnWaitMs);
    await settle();
    expect(asked[1].recent).toEqual([{ q: 'What is a cell?', a: 'A cell is small. It has a core.' }]);
  });

  it('speech that goes on holds the turn; an unfinished sentence waits longer', async () => {
    const { session, clock, lines, asked } = make();
    await session.start();
    lines[0].say('committed_transcript', 'What is');
    clock.advance(200);
    lines[0].say('partial_transcript', 'the difference'); // still talking
    clock.advance(1_000);
    await settle();
    expect(asked.length).toBe(0);
    lines[0].say('committed_transcript', 'the difference between');
    clock.advance(ListenSession.turnWaitMs);
    await settle();
    expect(asked.length).toBe(0); // "between …" is not finished
    lines[0].say('committed_transcript', 'a plant cell and an animal cell?');
    clock.advance(ListenSession.turnWaitMs);
    await settle();
    expect(asked.map((a) => a.fragment)).toEqual(['What is the difference between a plant cell and an animal cell?']);
    expect(session.isOn).toBe(true);
  });

  it('not a question: nothing is shown, nothing is said, it keeps listening', async () => {
    const { session, clock, lines, spoken, sound } = make({
      answer: async (_r, emit) => {
        emit({ event: 'meta', data: { is_question: false } });
        emit({ event: 'delta', data: { text: 'ignored' } });
        emit({ event: 'done', data: { answered: false } });
      },
    });
    await session.start();
    lines[0].say('committed_transcript', 'I think it will rain.');
    clock.advance(ListenSession.turnWaitMs);
    await settle();
    expect(spoken).toEqual([]);
    expect(session.answer).toBe('');
    expect(session.question).toBeNull();
    expect(session.phase).toBe('listening');
    expect(sound.log.some((l) => l.startsWith('play'))).toBe(false);
  });

  it('one press stops the answer and the page listens again', async () => {
    const { session, clock, lines, sound } = make();
    await session.start();
    lines[0].say('committed_transcript', 'What is a cell?');
    clock.advance(ListenSession.turnWaitMs);
    await settle();
    session.press();
    expect(session.phase).toBe('listening');
    expect(sound.last).toBe('silence');
    sound.end(); // a late end of the stopped sentence starts nothing
    await settle();
    expect(sound.last).toBe('silence');
  });

  it('Stop: microphone off, socket closed, screen released, the seconds reported', async () => {
    const { session, mic, lines, awake, reported, sound } = make();
    await session.start();
    mic.speak(16_000 * 3);
    session.stop();
    expect(session.phase).toBe('off');
    expect(mic.on).toBe(false);
    expect(lines[0].open).toBe(false);
    expect(awake).toEqual(['keep', 'release']);
    expect(sound.last).toBe('stop');
    expect(reported).toEqual([3]);
    lines[0].say('committed_transcript', 'late words');
    expect(session.heard).toBe('');
  });

  it('the microphone refused: says so, nothing is asked of the server', async () => {
    const { session, mic, tokens, awake } = make();
    mic.refuse = true;
    await session.start();
    expect(session.phase).toBe('off');
    expect(session.error).toContain('microphone');
    expect(tokens()).toBe(0);
    expect(awake).toEqual(['keep', 'release']);
  });

  it('the web\'s daily cap: the server\'s words (K114)', async () => {
    const { session, mic } = make({ token: new ApiError(429, 'web_daily_cap', 'The web beta has listened a lot today. Try again tomorrow.') });
    await session.start();
    expect(session.error).toBe('The web beta has listened a lot today. Try again tomorrow.');
    expect(session.phase).toBe('off');
    expect(mic.on).toBe(false);
  });

  it('test traffic: no socket, one pretend sentence, so no ElevenLabs credit is used (D180)', async () => {
    const { session, clock, lines, asked } = make({ token: { fake: true, token: null, ws_url: null, transcript: 'Det här är en testtranskription.' } });
    await session.start();
    expect(lines.length).toBe(0);
    expect(session.phase).toBe('listening');
    clock.advance(ListenSession.fakeAfterMs + ListenSession.turnWaitMs);
    await settle();
    expect(asked[0].fragment).toBe('Det här är en testtranskription.');
  });

  it('a socket that ends after a while is opened again with a new token; one that ends at once is a fault', async () => {
    const a = make();
    await a.session.start();
    a.clock.advance(ListenSession.reopenAfterMs + 1_000);
    a.lines[0].onClose?.();
    await settle();
    expect(a.tokens()).toBe(2);
    expect(a.lines.length).toBe(2);
    expect(a.session.phase).toBe('listening');

    const b = make();
    await b.session.start();
    b.lines[0].onClose?.();
    await settle();
    expect(b.tokens()).toBe(1); // no token after token
    expect(b.session.phase).toBe('off');
    expect(b.session.error).toBe('Listening stopped. Try again in a moment.');
  });

  it('silence is kept alive, so Scribe does not end the session while an answer is read', async () => {
    const { session, clock, lines } = make();
    await session.start();
    clock.advance(8_000);
    expect(lines[0].sent.length).toBe(1);
    expect(String(lines[0].sent[0].audio_base_64).length).toBeGreaterThan(1000);
    session.stop();
    clock.advance(60_000);
    expect(lines[0].sent.length).toBe(1);
  });

  it('speech that cannot be made: the text stays, the page goes on', async () => {
    const { session, clock, lines } = make({ speak: async () => Promise.reject(new ApiError(429, 'web_daily_cap', 'The web beta has read a lot aloud today.')) });
    await session.start();
    lines[0].say('committed_transcript', 'What is a cell?');
    clock.advance(ListenSession.turnWaitMs);
    await settle();
    expect(session.answer).toBe('A cell is small. It has a core.');
    expect(session.error).toBe('The web beta has read a lot aloud today.');
    expect(session.phase).toBe('listening');
  });

  it('an answer the server takes back is not shown or said', async () => {
    const { session, clock, lines, sound } = make({
      answer: async (_r, emit) => {
        emit({ event: 'meta', data: { is_question: true } });
        emit({ event: 'delta', data: { text: 'Wrong thing. ' } });
        emit({ event: 'done', data: { retract: true } });
      },
    });
    await session.start();
    lines[0].say('committed_transcript', 'What is a cell?');
    clock.advance(ListenSession.turnWaitMs);
    await settle();
    expect(session.answer).toBe('');
    expect(session.phase).toBe('listening');
    expect(sound.last).toBe('silence');
  });

  it('a hidden page ends the listening and says why: the page never listens where it cannot be seen', async () => {
    const { session, mic, lines } = make();
    await session.start();
    session.halt('Listening stopped because the page was hidden or the screen turned off.');
    expect(session.phase).toBe('off');
    expect(mic.on).toBe(false);
    expect(lines[0].open).toBe(false);
    expect(session.error).toBe('Listening stopped because the page was hidden or the screen turned off.');
  });

  it('a pass ends by itself after 30 minutes, says so, and reports its seconds (Kevin K117)', async () => {
    const { session, clock, mic, lines, reported, awake } = make();
    await session.start();
    mic.speak(16_000 * 5);
    clock.advance(ListenSession.maxMs - 1_000);
    expect(session.phase).toBe('listening');
    clock.advance(1_000);
    expect(session.phase).toBe('off');
    expect(session.error).toBe('Listening stopped after 30 minutes. Start again to go on.');
    expect(mic.on).toBe(false);
    expect(lines[0].open).toBe(false);
    expect(awake[awake.length - 1]).toBe('release');
    expect(reported.length).toBe(1);
    expect(reported[0]).toBeGreaterThanOrEqual(5);
  });

  it('a pass that was stopped does not end a later one early', async () => {
    const { session, clock } = make();
    await session.start();
    clock.advance(20 * 60_000);
    session.stop();
    await session.start();
    clock.advance(15 * 60_000); // 35 minutes after the first start, 15 into the second
    expect(session.phase).toBe('listening');
    expect(session.error).toBeNull();
  });
});
