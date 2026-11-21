import { describe, expect, it } from 'vitest';
import { fileName, joinMp3 } from '../src/core/mp3';

/// One MPEG-1 Layer III frame, 64 kbit/s, 44.1 kHz, no padding: 208 bytes. `mark` fills it, `tag` is written where a
/// Xing/Info header sits in a mono frame.
function frame(mark: number, tag: string | null = null): Uint8Array {
  const bytes = new Uint8Array(208).fill(mark);
  bytes.set([0xff, 0xfb, 0x50, 0xc4]); // sync, MPEG-1 Layer III, 64 kbit/s 44.1 kHz, mono
  if (tag !== null) bytes.set([...tag].map((c) => c.charCodeAt(0)), 4 + 17);
  return bytes;
}

function id3v2(payload: number): Uint8Array {
  const bytes = new Uint8Array(10 + payload).fill(7);
  bytes.set([0x49, 0x44, 0x33, 4, 0, 0, 0, 0, (payload >> 7) & 0x7f, payload & 0x7f]);
  return bytes;
}

function id3v1(): Uint8Array {
  const bytes = new Uint8Array(128).fill(9);
  bytes.set([0x54, 0x41, 0x47]);
  return bytes;
}

const cat = (...parts: Uint8Array[]): Uint8Array => {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of parts) {
    out.set(p, at);
    at += p.length;
  }
  return out;
};

describe('one MP3 from the parts (D253: Download the sound)', () => {
  it('plain files are joined end to end, in order', () => {
    const joined = joinMp3([cat(frame(1), frame(2)), cat(frame(3))]);
    expect(joined).toEqual(cat(frame(1), frame(2), frame(3)));
  });

  it('tags are taken away, so no player stops at one in the middle', () => {
    const joined = joinMp3([cat(id3v2(30), frame(1), id3v1()), cat(id3v2(300), frame(2), id3v1())]);
    expect(joined).toEqual(cat(frame(1), frame(2)));
  });

  it('a first frame that only says how long that one file is (Xing/Info) is left out', () => {
    const joined = joinMp3([cat(id3v2(12), frame(0, 'Info'), frame(1)), cat(frame(0, 'Xing'), frame(2))]);
    expect(joined).toEqual(cat(frame(1), frame(2)));
  });

  it('bytes that are not MP3 at all are kept as they are (never lose sound)', () => {
    const odd = new Uint8Array([1, 2, 3, 4, 5]);
    expect(joinMp3([odd, frame(1)])).toEqual(cat(odd, frame(1)));
    expect(joinMp3([])).toEqual(new Uint8Array(0));
  });

  it('the file is named after what it is, without signs a phone will not take', () => {
    expect(fileName('Photosynthesis: carbon dioxide + water')).toBe('EarMind - Photosynthesis carbon dioxide water.mp3');
    expect(fileName('  Åk 8 / biologi?  ')).toBe('EarMind - Åk 8 biologi.mp3');
    expect(fileName('***')).toBe('EarMind.mp3');
    expect(fileName('x'.repeat(200)).length).toBeLessThanOrEqual(80);
  });
});
