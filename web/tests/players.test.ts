import { describe, expect, it } from 'vitest';
import { pressFor } from '../src/core/sound';
import { QuestionPlayer, thinkingSeconds, type QuestionTrack } from '../src/core/questionPlayer';
import { nextSentence, previousSentence, sentenceAt, TextPlayer, type TextPart } from '../src/core/textPlayer';
import { FakeClock, FakeSound } from './fakes';

describe('AirPods presses in a browser', () => {
  it('one press is play or pause, two the next track, three the previous', () => {
    expect(pressFor('play')).toBe(1);
    expect(pressFor('pause')).toBe(1);
    expect(pressFor('nexttrack')).toBe(2);
    expect(pressFor('previoustrack')).toBe(3);
    expect(pressFor('seekto')).toBeNull();
  });
});

const tracks: QuestionTrack[] = [0, 1, 2].map((i) => ({ question: `q${i}.mp3`, long: `a${i}.mp3`, shortEndMs: 1200 + i }));

function questions(ready = [true, true, true]): { player: QuestionPlayer; sound: FakeSound; clock: FakeClock } {
  const sound = new FakeSound();
  const clock = new FakeClock();
  const player = new QuestionPlayer(3, (i) => (ready[i] ? tracks[i] : null), sound, clock, 6_000);
  return { player, sound, clock };
}

describe('the exam player (the app\'s rules, D142)', () => {
  it('asks, waits the thinking time, and goes on to the next question without a press', () => {
    const { player, sound, clock } = questions();
    player.start();
    expect(player.phase).toEqual({ kind: 'question', index: 0 });
    expect(sound.last).toBe('play q0.mp3 0');
    sound.end();
    expect(player.phase).toEqual({ kind: 'thinking', index: 0 });
    expect(sound.last).toBe('silence'); // the page stays the one the presses go to
    clock.advance(5_999);
    expect(player.phase.kind).toBe('thinking');
    clock.advance(1);
    expect(player.phase).toEqual({ kind: 'question', index: 1 });
  });

  it('one press gives the long answer, two the short one, then the next question', () => {
    const { player, sound } = questions();
    player.start();
    player.press(1); // during the question
    expect(player.phase).toEqual({ kind: 'answer', index: 0, answer: 'long' });
    expect(sound.last).toBe('play a0.mp3 0');
    sound.end();
    expect(player.phase).toEqual({ kind: 'question', index: 1 });
    sound.end();
    player.press(2); // during the thinking time
    expect(sound.last).toBe('play a1.mp3 0-1201'); // the short answer is the start of the long file
    player.press(1); // during an answer: that kind of answer from the start
    expect(player.phase).toEqual({ kind: 'answer', index: 1, answer: 'long' });
  });

  it('three presses pause, and any press goes on from the same place', () => {
    const { player, sound, clock } = questions();
    player.start();
    player.press(3);
    expect(player.paused).toBe(true);
    expect(sound.last).toBe('pause');
    sound.end(); // nothing moves while paused
    expect(player.phase.kind).toBe('question');
    player.press(2);
    expect(player.paused).toBe(false);
    expect(sound.last).toBe('resume');

    sound.end(); // thinking
    clock.advance(2_000);
    player.press(3);
    clock.advance(60_000); // the thinking time stands still
    expect(player.phase).toEqual({ kind: 'thinking', index: 0 });
    player.press(1); // goes on, does not answer
    expect(player.phase.kind).toBe('thinking');
    clock.advance(3_999);
    expect(player.phase.kind).toBe('thinking');
    clock.advance(1);
    expect(player.phase).toEqual({ kind: 'question', index: 1 });
  });

  it('starts again after the last question and never ends by itself', () => {
    const { player, sound, clock } = questions();
    player.start(2);
    sound.end();
    clock.advance(6_000);
    expect(player.phase).toEqual({ kind: 'question', index: 0 });
    expect(player.lap).toBe(1);
    player.stop();
    expect(player.phase.kind).toBe('idle');
    expect(sound.onEnded).toBeNull();
  });

  it('waits in silence for a question whose sound is not made yet', () => {
    const ready = [true, false, true];
    const { player, sound, clock } = questions(ready);
    player.start();
    sound.end();
    clock.advance(6_000);
    expect(player.phase).toEqual({ kind: 'waiting', index: 1 });
    player.press(1); // nothing to answer yet
    expect(player.phase.kind).toBe('waiting');
    ready[1] = true;
    clock.advance(QuestionPlayer.retryMs);
    expect(player.phase).toEqual({ kind: 'question', index: 1 });
  });

  it('thinks 6 s up to 20 questions and 4 s from 40', () => {
    expect(thinkingSeconds(5)).toBe(6);
    expect(thinkingSeconds(30)).toBe(5);
    expect(thinkingSeconds(60)).toBe(4);
  });
});

const text: TextPart[] = [
  { url: 'p0.mp3', texts: ['Ett.', 'Två.', 'Tre.'], times: [[0, 900], [900, 2000], [2000, 3100]] },
  { url: 'p1.mp3', texts: ['Fyra.'], times: [[0, 800]] },
];

function reading(minutes: number | null, parts = text): { player: TextPlayer; sound: FakeSound; clock: FakeClock } {
  const sound = new FakeSound();
  const clock = new FakeClock();
  return { player: new TextPlayer(() => parts, sound, clock, minutes), sound, clock };
}

describe('the text player (Säg i AirPods)', () => {
  it('knows which sentence a moment in the file is', () => {
    expect(sentenceAt(text[0].times, 0)).toBe(0);
    expect(sentenceAt(text[0].times, 899)).toBe(0);
    expect(sentenceAt(text[0].times, 900)).toBe(1);
    expect(sentenceAt(text[0].times, 99_999)).toBe(2);
    expect(nextSentence(text, { part: 0, sentence: 2 })).toEqual({ part: 1, sentence: 0 });
    expect(nextSentence(text, { part: 1, sentence: 0 })).toBeNull();
    expect(previousSentence(text, { part: 1, sentence: 0 })).toEqual({ part: 0, sentence: 2 });
    expect(previousSentence(text, { part: 0, sentence: 0 })).toEqual({ part: 0, sentence: 0 });
  });

  it('reads the parts in order and goes round until the minutes are over', () => {
    const { player, sound, clock } = reading(10);
    player.start();
    expect(sound.last).toBe('play p0.mp3 0');
    sound.end();
    expect(sound.last).toBe('play p1.mp3 0');
    clock.advance(9 * 60_000);
    sound.end(); // the last part, with time left: once more
    expect(player.lap).toBe(1);
    expect(sound.last).toBe('play p0.mp3 0');
    clock.advance(2 * 60_000);
    sound.end();
    sound.end(); // the time is over when the last part ends
    expect(player.phase).toBe('done');
    player.press(1); // "Börja om"
    expect(player.phase).toBe('playing');
  });

  it('one press pauses and goes on, and the time left stands still meanwhile', () => {
    const { player, sound, clock } = reading(10);
    player.start();
    clock.advance(60_000);
    expect(player.secondsLeft()).toBe(540);
    player.press(1);
    expect(player.paused).toBe(true);
    expect(sound.last).toBe('pause');
    clock.advance(5 * 60_000);
    expect(player.secondsLeft()).toBe(540);
    player.press(1);
    expect(sound.last).toBe('resume');
    expect(player.secondsLeft()).toBe(540);
  });

  it('two presses is the next sentence, three the previous one', () => {
    const { player, sound } = reading(null);
    player.start();
    sound.position = 950; // in the second sentence
    player.press(2);
    expect(player.position).toEqual({ part: 0, sentence: 2 });
    expect(sound.last).toBe('play p0.mp3 2000');
    player.press(2); // the last sentence of the part: the next part's first
    expect(sound.last).toBe('play p1.mp3 0');
    player.press(3);
    expect(sound.last).toBe('play p0.mp3 2000');
    player.press(3);
    expect(sound.last).toBe('play p0.mp3 900');
  });

  it('plays once without a time, and waits for sound that is not made yet', () => {
    const parts: TextPart[] = [{ url: null, texts: ['Ett.'], times: [[0, 900]] }];
    const { player, sound, clock } = reading(null, parts);
    player.start();
    expect(player.phase).toBe('waiting');
    expect(sound.last).toBe('silence');
    parts[0] = { ...parts[0], url: 'p0.mp3' };
    clock.advance(TextPlayer.retryMs);
    expect(player.phase).toBe('playing');
    sound.end();
    expect(player.phase).toBe('done');
    expect(player.secondsLeft()).toBeNull();
  });
});
