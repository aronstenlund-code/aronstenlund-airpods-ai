import type { Quota } from '../core/credits';
import type { Client } from './client';
import type { Question } from './drill';

export interface ExamSummary {
  subject: string;
  grade: string;
  covers: string;
}

export interface QuestionsReply {
  summary: ExamSummary;
  notes: string;
  items: { id: string; question: string }[];
  quota?: Quota;
}

/// `/exam`: the material becomes questions and answers (K45). Nothing is stored there.
export class ExamApi {
  constructor(private readonly client: Client) {}

  /// The questions first (about five seconds); the answers come with `answers`.
  questions(text: string, count: number): Promise<QuestionsReply> {
    return this.client.call<QuestionsReply>('exam', {
      action: 'drill',
      text,
      questions: count,
      answers: false,
      lang: this.client.lang,
    });
  }

  /// The same again with the user's correction ("it is about chapter 4, not 5"). The text is not sent twice.
  corrected(notes: string, correction: string, count: number): Promise<QuestionsReply> {
    return this.client.call<QuestionsReply>('exam', {
      action: 'drill',
      text: notes,
      correction,
      questions: count,
      answers: false,
      lang: this.client.lang,
    });
  }

  async answers(reply: QuestionsReply): Promise<Question[]> {
    const data = await this.client.call<{ items: Question[] }>('exam', {
      action: 'drill_answers',
      items: reply.items,
      notes: reply.notes,
      subject: reply.summary.subject,
      grade: reply.summary.grade,
      lang: this.client.lang,
    });
    return data.items;
  }
}
