import type { Quota } from '../core/credits';
import { cleanStyle, parts } from '../core/said';
import type { Client } from './client';

/// A file the server makes: `pending`, `working`, `done` or `failed`; `url` is a signed link, good for an hour.
export interface AudioFile {
  status: string;
  url?: string;
  duration_ms?: number;
  short_end_ms?: number;
  sentences?: [number, number][];
}

export interface DrillItemView {
  id: string;
  position?: number;
  question?: string;
  short?: string;
  long?: string;
  part?: string;
  text?: string;
  sentences?: string[];
  audio?: { question?: AudioFile; long?: AudioFile; text?: AudioFile };
}

export interface DrillView {
  drill: {
    id: string;
    title?: string;
    kind?: string;
    audio_started?: boolean;
    voice_id?: string;
    voice_name?: string;
  };
  items: DrillItemView[];
  audio: { done: number; total: number; failed?: number; cost?: number };
  cost?: number;
  quota?: Quota;
  audio_unavailable?: boolean;
}

export interface ShareInfo {
  title?: string;
  subject?: string;
  grade?: string;
  items?: number;
  audio_ready?: boolean;
}

export interface Voice {
  voice_id: string;
  name: string;
  accent?: string;
  language?: string;
  description?: string;
  preview_url?: string;
  review?: boolean;
}

export interface Question {
  id?: string;
  question: string;
  short: string;
  long: string;
}

/// A text for "Säg i AirPods": one part per line, read exactly as written, never an exam on Start (`said`).
export interface SaidDraft {
  clientID: string;
  text: string;
  title: string;
  style: string | null;
  voiceID: string | null;
}

export function saidBody(draft: SaidDraft, lang: string): Record<string, unknown> {
  const info: Record<string, unknown> = {
    title: draft.title,
    subject: '',
    grade: '',
    covers: '',
    long_words: 90,
    kind: 'text',
    said: true,
    client_id: draft.clientID,
  };
  const style = cleanStyle(draft.style);
  if (style !== null) info.style = style;
  if (draft.voiceID !== null) info.voice_id = draft.voiceID;
  // K100: saved and started in one call (no `defer_audio`, `start: true`).
  return { action: 'save', drill: info, items: parts(draft.text).map((text) => ({ kind: 'para', text })), start: true, lang };
}

export interface ExamDraft {
  clientID: string;
  title: string;
  subject: string;
  grade: string;
  covers: string;
  questions: Question[];
}

/// A new exam is saved without sound (`defer_audio`): Start exam asks for it, and that is when credits are counted.
export function examBody(draft: ExamDraft, lang: string): Record<string, unknown> {
  return {
    action: 'save',
    drill: {
      title: draft.title,
      subject: draft.subject,
      grade: draft.grade,
      covers: draft.covers.slice(0, 400),
      long_words: 90,
      client_id: draft.clientID,
    },
    items: draft.questions.map((q) => ({ question: q.question, short: q.short, long: q.long })),
    defer_audio: true,
    lang,
  };
}

/// The `/drill` and `/voices` calls the beta uses (backend/README.md, "Repetitionsläget").
export class DrillApi {
  constructor(private readonly client: Client) {}

  saveSaid(draft: SaidDraft): Promise<DrillView> {
    return this.client.call<DrillView>('drill', saidBody(draft, this.client.lang));
  }

  saveExam(draft: ExamDraft): Promise<DrillView> {
    return this.client.call<DrillView>('drill', examBody(draft, this.client.lang));
  }

  start(id: string): Promise<DrillView> {
    return this.client.call<DrillView>('drill', { action: 'start', id });
  }

  status(id: string): Promise<DrillView> {
    return this.client.call<DrillView>('drill', { action: 'status', id });
  }

  /// K47: what a shared link holds, for the screen before it is added. `code` may be the whole link.
  shareInfo(code: string): Promise<ShareInfo> {
    return this.client.call<ShareInfo>('drill', { action: 'share_info', code });
  }

  /// The user's own copy of a shared quiz. Its sound is the original's, so it costs nothing.
  importShared(code: string): Promise<DrillView> {
    return this.client.call<DrillView>('drill', { action: 'import', code });
  }

  remove(id: string): Promise<unknown> {
    return this.client.call('drill', { action: 'delete', id });
  }

  quota(): Promise<Quota> {
    return this.client.call<Quota>('drill', { action: 'quota' });
  }

  /// What saving and starting this text would cost now (K92); nothing is saved or counted.
  async costOfSaid(draft: SaidDraft): Promise<{ cost: number; remaining?: number; enough?: boolean }> {
    const body = saidBody(draft, this.client.lang);
    return this.client.call('drill', { ...body, action: 'cost', start: undefined });
  }

  async voices(): Promise<{ catalog: Voice[]; defaultName: string | null }> {
    const reply = await this.client.call<{ catalog?: Voice[]; default_voice?: { name?: string } }>('voices');
    // K114: the voices of the user's language first, then the others, each in the server's order.
    const own = (voice: Voice): number => ((voice.language ?? '').toLowerCase().startsWith(this.client.lang) ? 0 : 1);
    return {
      catalog: (reply.catalog ?? []).filter((voice) => voice.review !== true).sort((a, b) => own(a) - own(b)),
      defaultName: reply.default_voice?.name ?? null,
    };
  }
}
