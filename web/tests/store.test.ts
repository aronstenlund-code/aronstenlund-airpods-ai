import { describe, expect, it } from 'vitest';
import type { DrillView } from '../src/api/drill';
import { newID, Store } from '../src/store';
import { questionTrack, soundIsComplete, textParts } from '../src/tracks';
import { MemoryStorage } from './fakes';

const said = (id: string, text: string, at: number) => ({ id, serverID: `srv-${id}`, text, style: null, voiceID: null, voiceName: null, at });

describe('what the browser remembers', () => {
  it('keeps the newest twelve said texts, and finds the same text with the same sound again', () => {
    const storage = new MemoryStorage();
    const store = new Store(storage);
    for (let i = 0; i < 15; i += 1) store.keepSaid(said(`t${i}`, `Text ${i}`, i));
    expect(store.said).toHaveLength(Store.keptSaid);
    expect(store.said[0].id).toBe('t14');
    expect(store.findSaid(' Text 14 \n', null, null)?.id).toBe('t14');
    expect(store.findSaid('Text 14', 'lugnt', null)).toBeNull(); // another sound is another text
    expect(store.findSaid('Text 0', null, null)).toBeNull(); // fell off the end
    // A new visit reads the same.
    expect(new Store(storage).said[0].id).toBe('t14');
  });

  it('keeps the choices, and falls back to 10 minutes for a time that is not on offer', () => {
    const storage = new MemoryStorage();
    const store = new Store(storage);
    expect(store.settings).toEqual({ minutes: 10, voiceID: null, voiceName: null });
    store.setSettings({ minutes: 25, voiceID: 'v1', voiceName: 'Astrid' });
    expect(new Store(storage).settings).toEqual({ minutes: 25, voiceID: 'v1', voiceName: 'Astrid' });
    storage.setItem(Store.key, JSON.stringify({ settings: { minutes: 7 } }));
    expect(new Store(storage).settings.minutes).toBe(10);
    storage.setItem(Store.key, 'not json');
    expect(new Store(storage).exams).toEqual([]);
  });

  it('remembers where an exam was left', () => {
    const store = new Store(new MemoryStorage());
    store.keepExam({ id: 'e1', serverID: null, title: 'Bio', subject: 'Biologi', questions: [], cost: null, started: false, index: 0, at: 1 });
    store.changeExam('e1', { serverID: 'srv', started: true, index: 3 });
    expect(store.exams[0]).toMatchObject({ serverID: 'srv', started: true, index: 3 });
    expect(store.changeExam('nope', { index: 1 })).toBeNull();
    store.forgetExam('e1');
    expect(store.exams).toEqual([]);
  });

  it('makes ids the server takes as client_id (UUIDs)', () => {
    expect(newID()).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/);
    expect(newID()).not.toBe(newID());
  });
});

describe('the server\'s files as the players\' tracks', () => {
  const text: DrillView = {
    drill: { id: 'd1', kind: 'text' },
    audio: { done: 1, total: 2 },
    items: [
      { id: 'i1', text: 'Ett. Två.', sentences: ['Ett.', 'Två.'], audio: { text: { status: 'done', url: 'https://x/1.mp3', duration_ms: 2000, sentences: [[0, 900], [900, 2000]] } } },
      { id: 'i2', text: 'Tre.', audio: { text: { status: 'working' } } },
    ],
  };

  it('a text part without a finished file is waited for', () => {
    const parts = textParts(text);
    expect(parts[0]).toEqual({ url: 'https://x/1.mp3', texts: ['Ett.', 'Två.'], times: [[0, 900], [900, 2000]] });
    expect(parts[1].url).toBeNull();
    expect(parts[1].texts).toEqual(['Tre.']);
    expect(soundIsComplete(text)).toBe(false);
    expect(soundIsComplete({ ...text, audio: { done: 1, total: 2, failed: 1 } })).toBe(true);
  });

  it('a part whose sentence times do not match its sentences plays as one', () => {
    const odd: DrillView = { ...text, items: [{ id: 'i1', text: 'Ett. Två.', sentences: ['Ett.', 'Två.'], audio: { text: { status: 'done', url: 'u', duration_ms: 2000, sentences: [[0, 2000]] } } }] };
    expect(textParts(odd)[0]).toEqual({ url: 'u', texts: ['Ett. Två.'], times: [[0, 2000]] });
  });

  it('a question needs both its files; the short answer ends where the server says', () => {
    const view: DrillView = {
      drill: { id: 'd2' },
      audio: { done: 3, total: 4 },
      items: [
        { id: 'q1', audio: { question: { status: 'done', url: 'q1' }, long: { status: 'done', url: 'a1', duration_ms: 9000, short_end_ms: 2100 } } },
        { id: 'q2', audio: { question: { status: 'done', url: 'q2' }, long: { status: 'pending' } } },
      ],
    };
    expect(questionTrack(view, 0)).toEqual({ question: 'q1', long: 'a1', shortEndMs: 2100 });
    expect(questionTrack(view, 1)).toBeNull();
    expect(questionTrack(view, 7)).toBeNull();
  });
});
