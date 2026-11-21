/// D253 "Download the sound": the server keeps one MP3 per part (a paragraph, a question, an answer). MP3 is a row of
/// frames that each stand on their own, so the parts become one file by putting their frames after each other. What
/// is not sound is taken away first: tags (ID3) and the opening frame that only says how long that one file is
/// (Xing/Info), which would make a player show the first part's length for the whole file.

const bitratesV1 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
const bitratesV2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
const rates: Record<number, number[]> = { 3: [44100, 48000, 32000], 2: [22050, 24000, 16000], 0: [11025, 12000, 8000] };

/// The length in bytes of the Layer III frame that starts at `at`; null when no frame starts there.
function frameLength(bytes: Uint8Array, at: number): number | null {
  if (at + 4 > bytes.length || bytes[at] !== 0xff || (bytes[at + 1] & 0xe0) !== 0xe0) return null;
  const version = (bytes[at + 1] >> 3) & 3;
  const layer = (bytes[at + 1] >> 1) & 3;
  if (version === 1 || layer !== 1) return null;
  const bitrate = (version === 3 ? bitratesV1 : bitratesV2)[bytes[at + 2] >> 4];
  const rate = rates[version]?.[(bytes[at + 2] >> 2) & 3];
  if (!bitrate || !rate) return null;
  const padding = (bytes[at + 2] >> 1) & 1;
  return Math.floor(((version === 3 ? 144 : 72) * bitrate * 1000) / rate) + padding;
}

function has(bytes: Uint8Array, at: number, text: string): boolean {
  if (at < 0 || at + text.length > bytes.length) return false;
  for (let i = 0; i < text.length; i += 1) if (bytes[at + i] !== text.charCodeAt(i)) return false;
  return true;
}

/// The sound of one file: without tags and without a Xing/Info frame. Bytes that are not MP3 come back untouched.
function soundOf(bytes: Uint8Array): Uint8Array {
  let start = 0;
  let end = bytes.length;
  while (has(bytes, start, 'ID3') && start + 10 <= end) {
    const size = ((bytes[start + 6] & 0x7f) << 21) | ((bytes[start + 7] & 0x7f) << 14) | ((bytes[start + 8] & 0x7f) << 7) | (bytes[start + 9] & 0x7f);
    start += 10 + size + ((bytes[start + 5] & 0x10) !== 0 ? 10 : 0);
  }
  if (start >= end) return bytes;
  if (end - start >= 128 && has(bytes, end - 128, 'TAG')) end -= 128;
  const first = frameLength(bytes, start);
  if (first !== null && start + first <= end) {
    // The header sits a little into the frame (after the side information: 9, 17 or 32 bytes).
    for (let at = start + 4; at < Math.min(start + 44, start + first - 4); at += 1) {
      if (has(bytes, at, 'Xing') || has(bytes, at, 'Info')) {
        start += first;
        break;
      }
    }
  }
  return bytes.subarray(start, end);
}

export function joinMp3(files: Uint8Array[]): Uint8Array {
  const sounds = files.map(soundOf);
  const joined = new Uint8Array(sounds.reduce((n, s) => n + s.length, 0));
  let at = 0;
  for (const sound of sounds) {
    joined.set(sound, at);
    at += sound.length;
  }
  return joined;
}

/// "EarMind - Biology.mp3": letters and digits of any language, without the signs a phone's files will not take.
export function fileName(title: string): string {
  const clean = title
    .replace(/[^\p{L}\p{N} ._'-]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .replace(/^[ .]+|[ .]+$/g, '')
    .slice(0, 60)
    .trim();
  return clean.length === 0 ? 'EarMind.mp3' : `EarMind - ${clean}.mp3`;
}
