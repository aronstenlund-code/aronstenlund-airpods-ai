import type { Question } from './api/drill';
import type { KeyValue } from './api/client';
import { repeatMinutes, sameText } from './core/said';

/// A text that has been said ("Senaste"): the same text with the same sound is the same one on the server.
export interface SavedSaid {
  id: string;
  serverID: string | null;
  text: string;
  style: string | null;
  voiceID: string | null;
  voiceName: string | null;
  at: number;
}

export interface SavedExam {
  id: string;
  serverID: string | null;
  title: string;
  subject: string;
  questions: Question[];
  /// What Start exam will cost (the server's number); null before it is known.
  cost: number | null;
  started: boolean;
  /// Where it was left: the question to go on from.
  index: number;
  at: number;
}

export interface Settings {
  minutes: number;
  voiceID: string | null;
  voiceName: string | null;
}

interface Shape {
  said: SavedSaid[];
  exams: SavedExam[];
  settings: Settings;
}

/// What this browser remembers (localStorage): the texts said, the exams and the choices. The account is anonymous
/// and lives in the same storage, so clearing the site's data starts over.
export class Store {
  static readonly key = 'earmind.beta.v1';
  static readonly keptSaid = 12;

  private data: Shape;

  constructor(private readonly storage: KeyValue) {
    this.data = Store.read(storage);
  }

  private static read(storage: KeyValue): Shape {
    const empty: Shape = { said: [], exams: [], settings: { minutes: repeatMinutes(null), voiceID: null, voiceName: null } };
    try {
      const raw = storage.getItem(Store.key);
      if (raw === null) return empty;
      const parsed = JSON.parse(raw) as Partial<Shape>;
      return {
        said: Array.isArray(parsed.said) ? parsed.said : [],
        exams: Array.isArray(parsed.exams) ? parsed.exams : [],
        settings: {
          minutes: repeatMinutes(parsed.settings?.minutes),
          voiceID: parsed.settings?.voiceID ?? null,
          voiceName: parsed.settings?.voiceName ?? null,
        },
      };
    } catch {
      return empty;
    }
  }

  private write(): void {
    try {
      this.storage.setItem(Store.key, JSON.stringify(this.data));
    } catch {
      /* storage is full or switched off: the beta still works for this visit */
    }
  }

  get said(): SavedSaid[] {
    return this.data.said;
  }

  get exams(): SavedExam[] {
    return this.data.exams;
  }

  get settings(): Settings {
    return this.data.settings;
  }

  setSettings(change: Partial<Settings>): void {
    this.data.settings = { ...this.data.settings, ...change };
    this.write();
  }

  /// The text that was said before with this sound, if any: saying it again costs nothing.
  findSaid(text: string, style: string | null, voiceID: string | null): SavedSaid | null {
    return this.data.said.find((s) => sameText(s.text, text) && s.style === style && s.voiceID === voiceID) ?? null;
  }

  /// Newest first; the oldest fall off the end.
  keepSaid(said: SavedSaid): void {
    this.data.said = [said, ...this.data.said.filter((s) => s.id !== said.id)].slice(0, Store.keptSaid);
    this.write();
  }

  forgetSaid(id: string): void {
    this.data.said = this.data.said.filter((s) => s.id !== id);
    this.write();
  }

  /// The texts and the quizzes are gone; the choices (voice, minutes) stay.
  clear(): void {
    this.data.said = [];
    this.data.exams = [];
    this.write();
  }

  keepExam(exam: SavedExam): void {
    this.data.exams = [exam, ...this.data.exams.filter((e) => e.id !== exam.id)];
    this.write();
  }

  changeExam(id: string, change: Partial<SavedExam>): SavedExam | null {
    const exam = this.data.exams.find((e) => e.id === id);
    if (exam === undefined) return null;
    Object.assign(exam, change);
    this.write();
    return exam;
  }

  forgetExam(id: string): void {
    this.data.exams = this.data.exams.filter((e) => e.id !== id);
    this.write();
  }
}

/// An id for a new text or exam: a UUID, the same one sent again if a save has to be repeated (K88).
export function newID(): string {
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  const hex = (n: number): string => Array.from({ length: n }, () => Math.floor(Math.random() * 16).toString(16)).join('');
  return `${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}`;
}
