/// "Säg i AirPods" (A115, D203): a free text read aloud exactly as written. The rules are the iOS app's
/// (`SaidText`, `Drill.cleanStyle` in Lumen/Core/Repetition/Drill.swift), so a text costs and sounds the same.

export const maxChars = 40_000;
export const maxStyleChars = 80;

/// How long the text goes round (A124): 10 minutes to an hour in steps of five.
export const repeats: number[] = Array.from({ length: 11 }, (_, i) => 10 + i * 5);
export const defaultRepeat = 10;

export function repeatMinutes(stored: unknown): number {
  return typeof stored === 'number' && repeats.includes(stored) ? stored : defaultRepeat;
}

/// One part per line that has something on it.
export function parts(text: string): string[] {
  return text
    .split(/\r\n|\r|\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
}

/// The characters that are read aloud (what the credits are counted on).
export function chars(text: string): number {
  return parts(text).reduce((sum, part) => sum + Array.from(part).length, 0);
}

/// The server's count while a text is still being written: per line, every run of blanks is one space.
export function creditEstimate(text: string): number {
  return parts(text).reduce((sum, part) => sum + Array.from(part.replace(/\s+/g, ' ')).length, 0);
}

/// The first words, as the title of the text ("Klorofyllet i bladen fångar ljuset …").
export function title(text: string, fallback = 'Text'): string {
  const first = parts(text)[0];
  if (first === undefined) return fallback;
  const words = first.split(' ').slice(0, 5).join(' ');
  const cut = words.length > 32 ? words.slice(0, 31) + '…' : words;
  return cut.length < first.length && !cut.endsWith('…') ? cut + ' …' : cut;
}

/// "Hur ska det låta?": trimmed, one line, at most 80 characters; nothing when it is empty.
export function cleanStyle(style: string | null | undefined): string | null {
  const flat = (style ?? '').replace(/\s+/g, ' ').trim();
  if (flat.length === 0) return null;
  return Array.from(flat).slice(0, maxStyleChars).join('');
}

/// A tap on a suggestion writes the word into the style: added after a comma, never twice.
export function addingStyle(word: string, to: string): string {
  const current = to.trim();
  if (current.length === 0) return word;
  const has = current.toLowerCase().split(',').map((w) => w.trim()).includes(word.toLowerCase());
  return has ? current : `${current}, ${word.toLowerCase()}`;
}

/// The capsule under the field: the beginning of a said text, at most about 24 characters.
export function capsule(text: string): string {
  const flat = parts(text).join(' ');
  return flat.length > 24 ? flat.slice(0, 23).trim() + '…' : flat;
}

/// Two texts are the same text when their parts are (blank lines and outer spaces do not matter).
export function sameText(a: string, b: string): boolean {
  const x = parts(a);
  const y = parts(b);
  return x.length === y.length && x.every((part, i) => part === y[i]);
}
