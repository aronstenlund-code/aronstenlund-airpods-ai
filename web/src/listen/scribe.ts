/// Scribe v2 Realtime as the iOS app uses it (Lumen/Core/Transcription/ScribeProvider.swift). The server hands out a
/// single-use token (`GET /stt-token`); the page opens the socket itself, so no key is ever in the browser.

export interface SttToken {
  token: string | null;
  ws_url: string | null;
  model_id?: string;
  expires_in?: number;
  extra_query?: string;
  /// D180: test traffic gets no socket, only this sentence, so no ElevenLabs credit is ever used by a test.
  fake?: boolean;
  transcript?: string;
}

/// The pause that ends a turn in the ordinary mode (the app's ModeSettings: 1.0 s).
export const turnPause = 1.0;

/// The socket's address. Scribe's own voice detection commits a sentence after `pause - 0.4` s of silence (never
/// under 0.3 s), as in the app. The token is in the address: it is never logged.
export function scribeUrl(reply: SttToken, lang: 'en' | 'sv', pause = turnPause): string | null {
  if (!reply.token || !reply.ws_url) return null;
  const silence = Math.min(3, Math.max(0.2, Math.max(0.3, pause - 0.4)));
  const query = new URLSearchParams({
    model_id: reply.model_id ?? 'scribe_v2_realtime',
    token: reply.token,
    language_code: lang === 'sv' ? 'swe' : 'eng',
    audio_format: 'pcm_16000',
    commit_strategy: 'vad',
    vad_silence_threshold_secs: silence.toFixed(2),
    vad_threshold: '0.15',
    min_speech_duration_ms: '100',
    min_silence_duration_ms: '100',
  });
  const extra = (reply.extra_query ?? '').replace(/^[?&]+/, '');
  return `${reply.ws_url}?${query.toString()}${extra ? `&${extra}` : ''}`;
}

/// One block of sound for the socket. `commit` asks Scribe to finish the sentence now.
export function audioMessage(audioBase64: string, commit = false): string {
  return JSON.stringify({ message_type: 'input_audio_chunk', audio_base_64: audioBase64, commit, sample_rate: 16_000 });
}

/// Without sound for about 20 s Scribe ends the session: a quarter of a second of silence every 8 s keeps it.
export const keepAliveMs = 8_000;
export const keepAliveSamples = 4_000;
/// What is sent with a commit by hand: 200 ms of silence.
export const commitSamples = 3_200;

export type ScribeEvent = { kind: 'partial'; text: string } | { kind: 'final'; text: string } | { kind: 'error'; code: string } | { kind: 'other' };

/// What the socket said. Anything that names an error, a quota or a limit ends the listening.
export function readScribe(raw: string): ScribeEvent {
  let message: Record<string, unknown>;
  try {
    message = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return { kind: 'other' };
  }
  const type = String(message.message_type ?? message.type ?? '');
  const text = typeof message.text === 'string' ? message.text.trim() : '';
  if (type === 'partial_transcript') return { kind: 'partial', text };
  if (type === 'committed_transcript' || type === 'committed_transcript_with_timestamps') return { kind: 'final', text };
  if (/error|quota|limit|invalid/i.test(type)) return { kind: 'error', code: type };
  return { kind: 'other' };
}

/// What the page tells the server when it stops: the seconds it streamed (never more than an hour).
export function streamedSeconds(samples: number): number {
  return Math.min(3600, Math.max(0, Math.round(samples / 16_000)));
}
