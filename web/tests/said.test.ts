import { describe, expect, it } from 'vitest';
import * as said from '../src/core/said';
import { creditsLeft, short, thousands } from '../src/core/credits';

// The same rules as the iOS app (SaidText, Drill.cleanStyle, CreditText), so a text costs and sounds the same.
describe('a said text', () => {
  it('is one part per line that has something on it', () => {
    expect(said.parts('  Första raden. \n\n\nAndra raden.\r\n   \nTredje.')).toEqual(['Första raden.', 'Andra raden.', 'Tredje.']);
    expect(said.parts('   \n ')).toEqual([]);
  });

  it('counts the characters that are read, not the blank lines', () => {
    expect(said.chars('abc\n\n de ')).toBe(5);
    expect(said.chars('åäö')).toBe(3);
    expect(said.creditEstimate('a   b\n c\td ')).toBe(6);
  });

  it('gets its title from its first words', () => {
    // As in the app: at most 32 characters, cut with "…" (SaidText.title).
    expect(said.title('Klorofyllet i bladen fångar ljuset. Växten gör socker.')).toBe('Klorofyllet i bladen fångar lju…');
    expect(said.title('Bladen fångar ljuset. Växten gör socker av vatten.')).toBe('Bladen fångar ljuset. Växten gör …');
    expect(said.title('Kort text')).toBe('Kort text');
    expect(said.title('   ')).toBe('Text');
    const long = said.title('Enormtlångtordsomintetarslutnågongångalls och mer text här efter');
    expect(Array.from(long)).toHaveLength(32);
    expect(long.endsWith('…')).toBe(true);
  });

  it('keeps the style to one line of at most 80 characters', () => {
    expect(said.cleanStyle('  lugnt \n och   tydligt ')).toBe('lugnt och tydligt');
    expect(said.cleanStyle('   ')).toBeNull();
    expect(said.cleanStyle(null)).toBeNull();
    expect(said.cleanStyle('x'.repeat(200))?.length).toBe(80);
  });

  it('adds a suggested word once', () => {
    expect(said.addingStyle('Lugnt', '')).toBe('Lugnt');
    expect(said.addingStyle('Glatt', 'Lugnt')).toBe('Lugnt, glatt');
    expect(said.addingStyle('Lugnt', 'lugnt, glatt')).toBe('lugnt, glatt');
  });

  it('goes round for 10 minutes to an hour, in steps of five', () => {
    expect(said.repeats[0]).toBe(10);
    expect(said.repeats[said.repeats.length - 1]).toBe(60);
    expect(said.repeatMinutes(25)).toBe(25);
    expect(said.repeatMinutes(7)).toBe(10);
    expect(said.repeatMinutes('x')).toBe(10);
  });

  it('is the same text whatever the blank lines', () => {
    expect(said.sameText('a\n\nb', ' a \nb')).toBe(true);
    expect(said.sameText('a\nb', 'a b')).toBe(false);
    expect(said.capsule('Klorofyllet i bladen fångar ljuset')).toBe('Klorofyllet i bladen få…');
  });
});

describe('credits', () => {
  it('are what the server says is left', () => {
    expect(creditsLeft({ limit: 1500, remaining: 756 })).toBe(756);
    expect(creditsLeft({ limit: 1500, used: 744 })).toBe(756);
    expect(creditsLeft({ limit: 15, left: 3 })).toBe(3);
    expect(creditsLeft({ limit: 1500, remaining: -4 })).toBe(0);
    expect(creditsLeft(null)).toBeNull();
    expect(creditsLeft({ limit: 0, unlimited: true })).toBeGreaterThan(1e12);
  });

  it('are written so the number never breaks and never promises too much', () => {
    expect(thousands(1909)).toBe('1 909');
    expect(thousands(120)).toBe('120');
    expect(short(1500, ',')).toBe('1,5k');
    expect(short(1500, '.')).toBe('1.5k');
    expect(short(1499, ',')).toBe('1,4k');
    expect(short(2000, ',')).toBe('2k');
    expect(short(88, ',')).toBe('88');
  });
});
