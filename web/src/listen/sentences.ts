/// An answer is spoken sentence by sentence (one `/tts` call each, the next fetched while one plays), as in the app
/// (Lumen/Core/Answer/SentenceSplitter.swift). `/tts` takes at most 500 characters.

export const maxSpoken = 500;

const abbreviations = /(?:^|[\s(])(?:t\.ex|bl\.a|dvs|ca|osv|m\.m|e\.g|i\.e|etc|mr|mrs|dr|vs|nr|kl|st|[a-zåäö])$/i;

/// Cuts the sentences that are finished off the front of `text`. `done` means no more text is coming, so what is
/// left is a sentence too. A full stop inside a number ("3.14") or after an abbreviation ("t.ex.") ends nothing.
export function takeSentences(text: string, done: boolean): { sentences: string[]; rest: string } {
  const sentences: string[] = [];
  let start = 0;
  for (let i = 0; i < text.length; i += 1) {
    const c = text[i];
    if (c !== '.' && c !== '!' && c !== '?' && c !== '…') continue;
    const next = text[i + 1];
    if (next === undefined && !done) break; // more may come: "3." may become "3.14"
    if (next !== undefined && !/\s/.test(next)) continue;
    if (c === '.' && abbreviations.test(text.slice(start, i))) continue;
    const sentence = text.slice(start, i + 1).trim();
    if (sentence.length > 0) sentences.push(...fitting(sentence));
    start = i + 1;
  }
  let rest = text.slice(start);
  if (done) {
    if (rest.trim().length > 0) sentences.push(...fitting(rest.trim()));
    rest = '';
  }
  return { sentences, rest };
}

/// A sentence longer than `/tts` takes is cut between words.
function fitting(sentence: string): string[] {
  if (sentence.length <= maxSpoken) return [sentence];
  const pieces: string[] = [];
  let piece = '';
  for (const word of sentence.split(/\s+/)) {
    if (piece.length > 0 && piece.length + 1 + word.length > maxSpoken) {
      pieces.push(piece);
      piece = '';
    }
    piece = piece.length === 0 ? word.slice(0, maxSpoken) : `${piece} ${word}`;
  }
  if (piece.length > 0) pieces.push(piece);
  return pieces;
}
