/// The microphone's sound as Scribe wants it: 16 kHz, mono, 16-bit little endian, base64 (backend/README.md, D44).

export const scribeRate = 16_000;

/// The browser's samples (-1…1 at its own rate, usually 44.1 or 48 kHz) as 16-bit samples at 16 kHz. Each new sample
/// is the mean of the ones it replaces, which keeps speech clear without a filter of its own.
export function to16k(samples: Float32Array, fromRate: number): Int16Array {
  if (fromRate <= 0 || samples.length === 0) return new Int16Array(0);
  const step = fromRate / scribeRate;
  const out = new Int16Array(Math.floor(samples.length / step));
  for (let i = 0; i < out.length; i += 1) {
    const from = Math.floor(i * step);
    const to = Math.max(from + 1, Math.min(samples.length, Math.floor((i + 1) * step)));
    let sum = 0;
    for (let j = from; j < to; j += 1) sum += samples[j];
    const mean = Math.max(-1, Math.min(1, sum / (to - from)));
    out[i] = Math.round(mean < 0 ? mean * 0x8000 : mean * 0x7fff);
  }
  return out;
}

export function base64(samples: Int16Array): string {
  const bytes = new Uint8Array(samples.buffer, samples.byteOffset, samples.byteLength);
  let binary = '';
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}

/// How loud a block is (0…1, root mean square): the screen's "it hears you" mark, never stored or sent.
export function level(samples: Float32Array): number {
  if (samples.length === 0) return 0;
  let sum = 0;
  for (let i = 0; i < samples.length; i += 1) sum += samples[i] * samples[i];
  return Math.sqrt(sum / samples.length);
}
