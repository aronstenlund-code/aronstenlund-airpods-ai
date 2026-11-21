import { describe, expect, it } from 'vitest';
import { base64, level, to16k } from '../src/listen/pcm';
import { audioMessage, readScribe, scribeUrl, streamedSeconds } from '../src/listen/scribe';
import { takeSentences } from '../src/listen/sentences';
import { EventReader } from '../src/listen/sse';

describe('the microphone\'s sound for Scribe', () => {
  it('48 kHz becomes 16 kHz, 16-bit', () => {
    const samples = new Float32Array(48_000).fill(0.5);
    const out = to16k(samples, 48_000);
    expect(out.length).toBe(16_000);
    expect(out[0]).toBe(Math.round(0.5 * 0x7fff));
    expect(to16k(new Float32Array([2, 2, 2, -2, -2, -2]), 48_000)).toEqual(new Int16Array([0x7fff, -0x8000])); // never past the ends
    expect(to16k(new Float32Array(441), 44_100).length).toBe(160);
    expect(to16k(new Float32Array(0), 48_000).length).toBe(0);
  });

  it('is sent as base64 of little-endian samples', () => {
    expect(base64(new Int16Array([1, -1]))).toBe(btoa(String.fromCharCode(1, 0, 255, 255)));
    expect(JSON.parse(audioMessage('QUJD', true))).toEqual({ message_type: 'input_audio_chunk', audio_base_64: 'QUJD', commit: true, sample_rate: 16000 });
  });

  it('knows how loud a block is, for the mark on the screen', () => {
    expect(level(new Float32Array(100))).toBe(0);
    expect(level(new Float32Array(100).fill(0.5))).toBeCloseTo(0.5);
  });
});

describe('the Scribe socket', () => {
  const reply = { token: 'tok', ws_url: 'wss://stt.example/v1/realtime', model_id: 'scribe_v2_realtime', extra_query: 'enable_logging=false&filter_background_audio=true' };

  it('is opened as the app opens it: the page\'s language, Scribe\'s own pause detection', () => {
    const url = new URL(scribeUrl(reply, 'en') as string);
    expect(url.origin + url.pathname).toBe('wss://stt.example/v1/realtime');
    expect(Object.fromEntries(url.searchParams)).toEqual({
      model_id: 'scribe_v2_realtime',
      token: 'tok',
      language_code: 'eng',
      audio_format: 'pcm_16000',
      commit_strategy: 'vad',
      vad_silence_threshold_secs: '0.60',
      vad_threshold: '0.15',
      min_speech_duration_ms: '100',
      min_silence_duration_ms: '100',
      enable_logging: 'false',
      filter_background_audio: 'true',
    });
    expect(new URL(scribeUrl(reply, 'sv') as string).searchParams.get('language_code')).toBe('swe');
  });

  it('test traffic gets no socket (D180)', () => {
    expect(scribeUrl({ fake: true, token: null, ws_url: null, transcript: 'x' }, 'en')).toBeNull();
  });

  it('reads what Scribe says', () => {
    expect(readScribe('{"message_type":"partial_transcript","text":" what is "}')).toEqual({ kind: 'partial', text: 'what is' });
    expect(readScribe('{"message_type":"committed_transcript","text":"What is a cell?"}')).toEqual({ kind: 'final', text: 'What is a cell?' });
    expect(readScribe('{"type":"committed_transcript_with_timestamps","text":"Hi"}')).toEqual({ kind: 'final', text: 'Hi' });
    expect(readScribe('{"message_type":"quota_exceeded"}')).toEqual({ kind: 'error', code: 'quota_exceeded' });
    expect(readScribe('{"message_type":"session_started"}')).toEqual({ kind: 'other' });
    expect(readScribe('not json')).toEqual({ kind: 'other' });
  });

  it('reports the seconds it streamed, at most an hour', () => {
    expect(streamedSeconds(16_000 * 90)).toBe(90);
    expect(streamedSeconds(16_000 * 99_999)).toBe(3600);
  });
});

describe('the answer as it arrives', () => {
  it('events are read whole, however the text is cut', () => {
    const reader = new EventReader();
    expect(reader.feed('event: meta\ndata: {"is_question":true}\n\nevent: del')).toEqual([{ event: 'meta', data: { is_question: true } }]);
    expect(reader.feed('ta\ndata: {"text":"A cell "}\n\nevent: delta\r\ndata: {"text":"is small."}\r\n\r\n')).toEqual([
      { event: 'delta', data: { text: 'A cell ' } },
      { event: 'delta', data: { text: 'is small.' } },
    ]);
    expect(reader.feed('event: done\ndata: not json\n\n')).toEqual([]);
  });

  it('is spoken sentence by sentence, as soon as one is finished', () => {
    expect(takeSentences('A cell is small. It has a', false)).toEqual({ sentences: ['A cell is small.'], rest: ' It has a' });
    expect(takeSentences(' It has a core.', true)).toEqual({ sentences: ['It has a core.'], rest: '' });
    expect(takeSentences('Is it? Yes! Good', true).sentences).toEqual(['Is it?', 'Yes!', 'Good']);
  });

  it('a number or an abbreviation ends no sentence', () => {
    expect(takeSentences('Pi is 3.14 roughly. ', false).sentences).toEqual(['Pi is 3.14 roughly.']);
    expect(takeSentences('Pi is 3.', false)).toEqual({ sentences: [], rest: 'Pi is 3.' }); // "14" may still come
    expect(takeSentences('Det är t.ex. en cell. ', false).sentences).toEqual(['Det är t.ex. en cell.']);
    expect(takeSentences('Use e.g. a leaf. ', false).sentences).toEqual(['Use e.g. a leaf.']);
  });

  it('nothing spoken is longer than the server takes (500)', () => {
    const long = `${'word '.repeat(150).trim()}.`;
    const { sentences } = takeSentences(long, true);
    expect(sentences.length).toBe(2);
    expect(sentences.every((s) => s.length <= 500)).toBe(true);
    expect(sentences.join(' ')).toBe(long);
  });
});
