import type { SttToken } from '../listen/scribe';
import { EventReader, type ServerEvent } from '../listen/sse';
import type { Client } from './client';

export interface AnswerRequest {
  fragment: string;
  recent: { q: string; a: string }[];
}

/// What listening asks of the server (backend/README.md): a single-use Scribe token, the answer as a stream of
/// events, and each sentence as sound. K114: on the web the tokens and `/tts` have daily caps (429 `web_daily_cap`).
export class ListenApi {
  constructor(private readonly client: Client) {}

  token(): Promise<SttToken> {
    return this.client.call<SttToken>('stt-token');
  }

  /// The seconds the page streamed, when it stops (the server's usage row; no sound, no text).
  report(seconds: number): Promise<unknown> {
    return this.client.call('stt-token', { seconds });
  }

  /// A finished turn, as the app sends it in the ordinary mode: `mode: "tutor"`; the server decides whether it was
  /// a question (`meta.is_question`) and says nothing when it was not. `lang` also steers how numbers are read (K115).
  async answer(request: AnswerRequest, onEvent: (event: ServerEvent) => void, signal: AbortSignal): Promise<void> {
    const lang = this.client.lang;
    const response = await this.client.raw(
      'answer',
      { fragment: request.fragment.slice(0, 1000), mode: 'tutor', language: lang, lang, length: 'adaptive', context: { recent_qa: request.recent.slice(-3).map((qa) => ({ q: qa.q.slice(0, 400), a: qa.a.slice(0, 1500) })) } },
      '',
      signal,
    );
    const reader = new EventReader();
    const body = response.body;
    if (body === null) {
      for (const event of reader.feed(`${await response.text()}\n\n`)) onEvent(event);
      return;
    }
    const stream = body.getReader();
    const decoder = new TextDecoder();
    for (;;) {
      const { done, value } = await stream.read();
      if (done) break;
      for (const event of reader.feed(decoder.decode(value, { stream: true }))) onEvent(event);
    }
    for (const event of reader.feed('\n\n')) onEvent(event);
  }

  /// One sentence as MP3 (at most 500 characters). Test traffic gets a second of silence (D180).
  async speak(text: string, voiceID: string | null, signal: AbortSignal): Promise<Uint8Array> {
    const body: Record<string, unknown> = { text, language: this.client.lang, output_format: 'mp3_44100_64' };
    if (voiceID !== null) body.voice_id = voiceID;
    const response = await this.client.raw('tts', body, '', signal);
    return new Uint8Array(await response.arrayBuffer());
  }
}
