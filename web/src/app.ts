import { ApiError, OfflineError } from './api/client';
import type { DrillApi, DrillView, Question, ShareInfo, Voice } from './api/drill';
import type { ExamApi, QuestionsReply } from './api/exam';
import { creditsLeft, type Quota } from './core/credits';
import { QuestionPlayer, thinkingSeconds } from './core/questionPlayer';
import { cleanStyle, parts, title } from './core/said';
import type { Clock, Press, Sound } from './core/sound';
import { TextPlayer, type TextPosition } from './core/textPlayer';
import { newID, type SavedExam, type SavedSaid, type Store } from './store';
import type { Translate } from './texts';
import { questionTrack, soundIsComplete, textParts } from './tracks';

export interface Awake {
  keep(): Promise<void>;
  release(): Promise<void>;
}

export interface Deps {
  drill: DrillApi;
  exam: ExamApi;
  sound: Sound;
  clock: Clock;
  store: Store;
  awake: Awake;
  t: Translate;
}

/// Nytt prov, step by step. Nothing is saved before "Looks right".
export type ExamDraft =
  | { stage: 'closed' }
  | { stage: 'write'; error: string | null }
  | { stage: 'making' }
  | { stage: 'check'; reply: QuestionsReply; count: number; note: string | null; error: string | null; busy: boolean }
  | { stage: 'answering' };

/// Open link: a quiz someone shared (the app's "Har du fått ett prov?").
export type LinkDraft =
  | { stage: 'closed' }
  | { stage: 'ask'; error: string | null; busy: boolean }
  | { stage: 'found'; code: string; info: ShareInfo; error: string | null; busy: boolean };

/// Everything the beta does, without a screen: the screens read this and call it (ui.ts), and the tests run it with
/// a scripted server and a sound that only remembers what it was asked.
export class App {
  onChange: (() => void) | null = null;

  quota: Quota | null = null;
  voices: Voice[] = [];
  defaultVoiceName: string | null = null;

  /// "Säg i AirPods".
  sayBusy = false;
  sayError: string | null = null;
  sayOutOfCredits = false;
  text: TextPlayer | null = null;
  saidPlaying: SavedSaid | null = null;

  /// Exams.
  draft: ExamDraft = { stage: 'closed' };
  link: LinkDraft = { stage: 'closed' };
  quiz: QuestionPlayer | null = null;
  examPlaying: SavedExam | null = null;
  examBusy: string | null = null;
  examError: { id: string; message: string } | null = null;

  static readonly pollMs = 2_500;
  static readonly defaultQuestions = 12;
  static readonly minQuestions = 3;

  private view: DrillView | null = null;
  private stopFollowing: (() => void) | null = null;
  /// Each Play and each Start exam is a new attempt: an answer that comes after a newer one is thrown away.
  private attempt = 0;

  constructor(private readonly deps: Deps) {}

  get isPlaying(): boolean {
    return (this.text?.isRunning ?? false) || (this.quiz?.isRunning ?? false);
  }

  get creditsLeft(): number | null {
    return creditsLeft(this.quota);
  }

  /// The account, the credits and the voices. A beta without the server still shows what it is; it just cannot play.
  async init(): Promise<void> {
    await Promise.all([
      this.refreshQuota(),
      this.deps.drill
        .voices()
        .then((v) => {
          this.voices = v.catalog;
          this.defaultVoiceName = v.defaultName;
        })
        .catch(() => undefined),
    ]);
    this.changed();
  }

  async refreshQuota(): Promise<void> {
    try {
      this.quota = await this.deps.drill.quota();
    } catch {
      /* the capsule keeps what it showed */
    }
    this.changed();
  }

  chooseVoice(voice: Voice | null): void {
    this.deps.store.setSettings({ voiceID: voice?.voice_id ?? null, voiceName: voice?.name ?? null });
    this.changed();
  }

  chooseMinutes(minutes: number): void {
    this.deps.store.setSettings({ minutes });
    this.changed();
  }

  /// What this text would cost now, from the server; null when it cannot say (the Play button still works).
  async cost(text: string, style: string): Promise<number | null> {
    if (parts(text).length === 0) return null;
    const settings = this.deps.store.settings;
    const sound = cleanStyle(style);
    if (this.deps.store.findSaid(text, sound, settings.voiceID)?.serverID) return 0; // said before: free
    try {
      const reply = await this.deps.drill.costOfSaid({ clientID: newID(), text, title: title(text), style: sound, voiceID: settings.voiceID });
      return reply.cost;
    } catch {
      return null;
    }
  }

  // MARK: Säg i AirPods

  /// Play. Called straight from the tap: the first thing it does is start the page's audio (silently), which is what
  /// lets the browser play the sound when it arrives a few seconds later.
  async say(text: string, style: string): Promise<void> {
    if (parts(text).length === 0 || this.sayBusy) return;
    this.stopAll();
    const mine = (this.attempt += 1);
    const { sound, store, drill, awake, clock } = this.deps;
    sound.silence();
    void awake.keep();
    this.sayBusy = true;
    this.sayError = null;
    this.sayOutOfCredits = false;
    this.changed();

    const settings = store.settings;
    const how = cleanStyle(style);
    let saved = store.findSaid(text, how, settings.voiceID);
    try {
      let view: DrillView | null = null;
      if (saved?.serverID) {
        // The same text with the same sound: the server has it, and starting it again costs nothing.
        view = await drill.start(saved.serverID).catch((error: unknown) => {
          if (error instanceof ApiError && error.status === 404) return null; // gone on the server: said anew
          throw error;
        });
      }
      if (view === null) {
        if (saved !== null) store.forgetSaid(saved.id); // the old one led nowhere
        const id = newID();
        view = await drill.saveSaid({ clientID: id, text, title: title(text), style: how, voiceID: settings.voiceID });
        if (view.drill.audio_started === false) view = await drill.start(view.drill.id);
        saved = { id, serverID: view.drill.id, text, style: how, voiceID: settings.voiceID, voiceName: settings.voiceName, at: clock.now() };
      }
      if (mine !== this.attempt) return; // stopped, or a newer Play, while the server worked
      const kept: SavedSaid = { ...(saved as SavedSaid), serverID: view.drill.id, voiceName: view.drill.voice_name ?? settings.voiceName ?? this.defaultVoiceName, at: clock.now() };
      store.keepSaid(kept);
      this.view = view;
      this.follow(view.drill.id);
      const player = new TextPlayer(() => (this.view === null ? [] : textParts(this.view)), sound, clock, settings.minutes);
      player.onChange = () => {
        if (player.phase === 'done' && this.text === player) {
          // The chosen minutes are over: the card is the field again and the screen may sleep.
          player.onChange = null;
          this.text = null;
          this.saidPlaying = null;
          sound.stop();
          this.rest();
        }
        this.changed();
      };
      this.text = player;
      this.saidPlaying = kept;
      player.start();
      void this.refreshQuota();
    } catch (error) {
      if (mine !== this.attempt) return;
      sound.stop();
      this.rest();
      this.sayOutOfCredits = error instanceof ApiError && error.isOutOfCredits;
      this.sayError = this.words(error);
    } finally {
      if (mine === this.attempt) {
        this.sayBusy = false;
        this.changed();
      }
    }
  }

  // MARK: Exams

  openDraft(): void {
    this.draft = { stage: 'write', error: null };
    this.changed();
  }

  closeDraft(): void {
    this.draft = { stage: 'closed' };
    this.changed();
  }

  /// Make questions. The server says no before it makes anything when the credits do not cover the exam, and how
  /// many questions fit (K109, K110): at least three fit, the exam gets that many; fewer, no exam is proposed.
  async makeQuestions(text: string, count: number): Promise<void> {
    if (text.trim().length === 0) return;
    this.draft = { stage: 'making' };
    this.changed();
    try {
      let note: string | null = null;
      let asked = count;
      let reply: QuestionsReply;
      try {
        reply = await this.deps.exam.questions(text, asked);
      } catch (error) {
        const fits = error instanceof ApiError && error.status === 402 ? Number(error.body.fits) : NaN;
        const least = error instanceof ApiError ? Number(error.body.min_questions ?? App.minQuestions) : App.minQuestions;
        if (!Number.isFinite(fits) || fits < least || fits >= asked) throw error;
        asked = fits;
        note = this.deps.t('quizFits', { n: fits });
        reply = await this.deps.exam.questions(text, asked);
      }
      if (reply.quota) this.quota = reply.quota;
      this.draft = { stage: 'check', reply, count: asked, note, error: null, busy: false };
    } catch (error) {
      this.draft = { stage: 'write', error: this.words(error) };
    }
    this.changed();
  }

  /// "Something is wrong": the same again with the user's line. The text is not sent twice.
  async correct(correction: string): Promise<void> {
    const draft = this.draft;
    if (draft.stage !== 'check' || draft.busy || correction.trim().length === 0) return;
    this.draft = { ...draft, busy: true, error: null };
    this.changed();
    try {
      const reply = await this.deps.exam.corrected(draft.reply.notes, correction.trim(), draft.count);
      this.draft = { ...draft, reply, busy: false, error: null };
    } catch (error) {
      this.draft = { ...draft, busy: false, error: this.words(error) };
    }
    this.changed();
  }

  /// "Looks right": the answers are written and the exam is saved, without sound. Start exam makes the sound.
  async acceptExam(): Promise<void> {
    const draft = this.draft;
    if (draft.stage !== 'check' || draft.busy) return;
    this.draft = { stage: 'answering' };
    this.changed();
    try {
      const questions: Question[] = await this.deps.exam.answers(draft.reply);
      const id = newID();
      const name = draft.reply.summary.subject || this.deps.t('newQuiz');
      const view = await this.deps.drill.saveExam({ clientID: id, title: name, subject: draft.reply.summary.subject, grade: draft.reply.summary.grade, covers: draft.reply.summary.covers, questions });
      this.deps.store.keepExam({ id, serverID: view.drill.id, title: name, subject: draft.reply.summary.subject, questions, cost: view.audio.cost ?? view.cost ?? null, started: false, index: 0, at: this.deps.clock.now() });
      this.draft = { stage: 'closed' };
    } catch (error) {
      this.draft = { ...draft, error: this.words(error), busy: false };
    }
    this.changed();
  }

  // MARK: Open link

  openLink(): void {
    this.link = { stage: 'ask', error: null, busy: false };
    this.changed();
  }

  closeLink(): void {
    this.link = { stage: 'closed' };
    this.changed();
  }

  /// What was pasted, a link or the code itself: the server reads either, and says what the link holds.
  async lookUp(pasted: string): Promise<void> {
    const code = pasted.trim();
    if (code.length === 0 || (this.link.stage === 'ask' && this.link.busy)) return;
    this.link = { stage: 'ask', error: null, busy: true };
    this.changed();
    try {
      const info = await this.deps.drill.shareInfo(code);
      this.link = { stage: 'found', code, info, error: null, busy: false };
    } catch (error) {
      this.link = { stage: 'ask', error: this.words(error), busy: false };
    }
    this.changed();
  }

  /// The shared quiz becomes the user's own. Its sound is the original's: no credits are counted.
  async addShared(): Promise<void> {
    const link = this.link;
    if (link.stage !== 'found' || link.busy) return;
    this.link = { ...link, busy: true, error: null };
    this.changed();
    try {
      const view = await this.deps.drill.importShared(link.code);
      if (view.drill.kind === 'text') {
        // A text to read aloud, not questions: the beta has no screen for those yet, so the copy is not kept.
        void this.deps.drill.remove(view.drill.id).catch(() => undefined);
        this.link = { ...link, busy: false, error: this.deps.t('linkIsText') };
        this.changed();
        return;
      }
      const questions: Question[] = view.items.map((item) => ({ id: item.id, question: item.question ?? '', short: item.short ?? '', long: item.long ?? '' }));
      const name = view.drill.title || link.info.title || this.deps.t('newQuiz');
      this.deps.store.keepExam({ id: newID(), serverID: view.drill.id, title: name, subject: link.info.subject ?? '', questions, cost: 0, started: view.drill.audio_started !== false, index: 0, at: this.deps.clock.now() });
      this.link = { stage: 'closed' };
    } catch (error) {
      this.link = { ...link, busy: false, error: this.words(error) };
    }
    this.changed();
  }

  /// Start exam. Called straight from the tap, like Play.
  async startExam(id: string): Promise<void> {
    const exam = this.deps.store.exams.find((e) => e.id === id);
    if (exam === undefined || exam.serverID === null || this.examBusy !== null) return;
    this.stopAll();
    const mine = (this.attempt += 1);
    const { sound, store, drill, awake, clock } = this.deps;
    sound.silence();
    void awake.keep();
    this.examBusy = id;
    this.examError = null;
    this.changed();
    try {
      const view = await drill.start(exam.serverID);
      if (mine !== this.attempt) return;
      const started = store.changeExam(id, { started: true, cost: 0 }) ?? exam;
      this.view = view;
      this.follow(view.drill.id);
      const count = view.items.length;
      const player = new QuestionPlayer(count, (index) => (this.view === null ? null : questionTrack(this.view, index)), sound, clock, thinkingSeconds(count) * 1000);
      player.onChange = () => {
        if (player.isRunning) store.changeExam(id, { index: player.index });
        this.changed();
      };
      this.quiz = player;
      this.examPlaying = started;
      player.start(Math.min(started.index, Math.max(0, count - 1)));
      void this.refreshQuota();
    } catch (error) {
      if (mine !== this.attempt) return;
      sound.stop();
      this.rest();
      this.examError = { id, message: this.words(error) };
    } finally {
      if (mine === this.attempt) {
        this.examBusy = null;
        this.changed();
      }
    }
  }

  async deleteExam(id: string): Promise<void> {
    const exam = this.deps.store.exams.find((e) => e.id === id);
    if (exam === undefined) return;
    if (this.examPlaying?.id === id) this.stopAll();
    this.deps.store.forgetExam(id);
    this.changed();
    if (exam.serverID !== null) await this.deps.drill.remove(exam.serverID).catch(() => undefined);
    void this.refreshQuota();
  }

  // MARK: While something plays

  /// A press on the AirPods, or the same thing tapped on the screen.
  press(press: Press): void {
    if (this.quiz?.isRunning) this.quiz.press(press);
    else if (this.text !== null && this.text.phase !== 'idle') this.text.press(press);
  }

  /// Stop, or Quit: nothing plays, the screen may sleep again.
  stopAll(): void {
    this.attempt += 1;
    this.text?.stop();
    this.quiz?.stop();
    this.text = null;
    this.quiz = null;
    this.saidPlaying = null;
    this.examPlaying = null;
    this.sayBusy = false;
    this.examBusy = null;
    this.rest();
    this.changed();
  }

  /// The sound stopped without anyone asking (the screen went dark, a call, the browser said no): the player is
  /// paused where it was, so one press or one tap goes on from the same word.
  interrupted(): void {
    if (this.text !== null && this.text.isRunning && !this.text.paused) this.text.togglePause();
    else if (this.quiz !== null && this.quiz.isRunning && !this.quiz.paused) this.quiz.press(3);
    this.changed();
  }

  /// A capsule under Recent is taken away, here and on the server.
  async removeSaid(id: string): Promise<void> {
    const said = this.deps.store.said.find((s) => s.id === id);
    if (said === undefined) return;
    if (this.saidPlaying?.id === id) this.stopAll();
    this.deps.store.forgetSaid(id);
    this.changed();
    if (said.serverID !== null) await this.deps.drill.remove(said.serverID).catch(() => undefined);
  }

  /// "Forget this browser": nothing plays, and the texts and quizzes kept here are gone (on the server too).
  async forgetEverything(): Promise<void> {
    this.stopAll();
    const ids = [...this.deps.store.said, ...this.deps.store.exams].map((x) => x.serverID).filter((x): x is string => x !== null);
    this.deps.store.clear();
    this.changed();
    await Promise.all(ids.map((id) => this.deps.drill.remove(id).catch(() => undefined)));
  }

  /// Called by the screen while sound plays, so the sentence being read is the one shown.
  tick(): void {
    this.text?.tick();
  }

  private rest(): void {
    this.stopFollowing?.();
    this.stopFollowing = null;
    void this.deps.awake.release();
  }

  /// "Gör ljudet …": asks the server how far it has come until every file is made. Each answer also brings links
  /// that are good for another hour.
  private follow(id: string): void {
    this.stopFollowing?.();
    let live = true;
    let cancel: (() => void) | null = null;
    const again = (): void => {
      cancel = this.deps.clock.after(App.pollMs, () => {
        void (async () => {
          if (!live) return;
          try {
            const view = await this.deps.drill.status(id);
            if (!live) return;
            this.view = view;
            this.changed();
            if (soundIsComplete(view)) return;
          } catch {
            /* asked again in a moment */
          }
          if (live) again();
        })();
      });
    };
    if (this.view === null || !soundIsComplete(this.view)) again();
    this.stopFollowing = () => {
      live = false;
      cancel?.();
    };
  }

  /// The sentence being read, as the server split it; null before the server has answered.
  sentence(at: TextPosition): string | null {
    if (this.view === null) return null;
    const part = textParts(this.view)[at.part];
    return part?.texts[at.sentence] ?? part?.texts[0] ?? null;
  }

  /// How far the sound has come ("3 of 8"), while it is being made.
  get soundProgress(): { done: number; total: number } | null {
    if (this.view === null || soundIsComplete(this.view)) return null;
    return { done: this.view.audio.done, total: this.view.audio.total };
  }

  private words(error: unknown): string {
    if (error instanceof OfflineError) return this.deps.t('errorOffline');
    if (error instanceof ApiError && error.message.trim().length > 0) return error.message;
    return this.deps.t('errorGeneric');
  }

  private changed(): void {
    this.onChange?.();
  }
}
