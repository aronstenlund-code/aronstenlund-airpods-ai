import type { DrillView } from './api/drill';
import type { QuestionTrack } from './core/questionPlayer';
import type { TextPart } from './core/textPlayer';

/// The server's view of a text as the player's parts. A part without a finished file is waited for (`url: null`).
export function textParts(view: DrillView): TextPart[] {
  return view.items.map((item) => {
    const file = item.audio?.text;
    const texts = item.sentences && item.sentences.length > 0 ? item.sentences : [item.text ?? item.long ?? ''];
    const ready = file !== undefined && file.status === 'done' && typeof file.url === 'string';
    const whole: [number, number][] = [[0, file?.duration_ms ?? 0]];
    const times = file?.sentences && file.sentences.length === texts.length ? file.sentences : whole;
    return { url: ready ? (file.url as string) : null, texts: times === whole ? [texts.join(' ')] : texts, times };
  });
}

/// The sound of question `index`: both files must be made before it can be asked.
export function questionTrack(view: DrillView, index: number): QuestionTrack | null {
  const audio = view.items[index]?.audio;
  const question = audio?.question;
  const long = audio?.long;
  if (question?.status !== 'done' || long?.status !== 'done' || !question.url || !long.url) return null;
  return { question: question.url, long: long.url, shortEndMs: long.short_end_ms ?? long.duration_ms ?? 0 };
}

/// "Gör ljudet …": every file is made, or one has failed for good.
export function soundIsComplete(view: DrillView): boolean {
  return view.audio.total > 0 && view.audio.done + (view.audio.failed ?? 0) >= view.audio.total;
}
