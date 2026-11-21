import type { App } from '../app';
import { short } from '../core/credits';
import { thinkingSeconds } from '../core/questionPlayer';
import { addingStyle, capsule, chars, maxChars, maxStyleChars, parts } from '../core/said';
import type { KeyValue } from '../api/client';
import type { SavedExam, Store } from '../store';
import { clockText, grouped, type Lang, type Translate } from '../texts';
import { h, icon, Region } from './dom';
import { type Sheets, openSheet } from './sheets';

/// What the screens need from the browser, so they can be shown without one in a test.
export interface Platform {
  /// True when the browser has Screen Wake Lock at all.
  awakeSupported: boolean;
  /// True while the screen is being kept on.
  awakeHeld(): boolean;
  pageHidden(): boolean;
  nowPlaying(title: string, album: string, playing: boolean): void;
  nothingPlaying(): void;
  setLanguage(lang: Lang): void;
  /// A voice's sample, straight from a tap. A second call stops the first.
  preview(url: string | null): void;
}

export interface ViewDeps {
  app: App;
  store: Store;
  t: Translate;
  lang: Lang;
  platform: Platform;
  /// Small things only this screen remembers (the first-time line).
  flags: KeyValue;
}

const seenKey = 'earmind.beta.played';

/// The first screen: the same order as the iOS app's (Kelly, docs/design/webbeta.md §2).
export class View {
  /// Set by the browser layer (main.ts).
  stoppedByScreen = false;
  blocked = false;

  private readonly header: Region;
  private readonly notice: Region;
  private readonly cost: Region;
  private readonly sayError: Region;
  private readonly sayButtons: Region;
  private readonly sayExtras: Region;
  private readonly playing: Region;
  private readonly recents: Region;
  private readonly quizzes: Region;
  private readonly player: Region;
  private readonly live: HTMLElement;
  private readonly form: HTMLElement;
  private readonly field: HTMLTextAreaElement;
  private readonly style: HTMLInputElement;
  private readonly timeLeft: HTMLElement = h('span', { class: 'time', attrs: { 'data-testid': 'time-left' } });

  private sheets: Sheets;
  private costNow: number | null | 'asking' = null;
  private costTimer: number | null = null;
  private costAsked = 0;
  private editingRecents = false;
  private said = '';

  constructor(
    root: HTMLElement,
    private readonly deps: ViewDeps,
  ) {
    const { t } = deps;
    const region = (tag: keyof HTMLElementTagNameMap, cls: string): Region => new Region(h(tag, { class: cls }));
    this.header = region('header', 'top');
    this.notice = region('section', 'notice-host');
    this.cost = region('div', 'cost');
    this.sayError = region('div', 'say-error');
    this.sayButtons = region('div', 'say-buttons');
    this.sayExtras = region('div', 'say-extras');
    this.playing = region('div', 'playing-host');
    this.recents = region('section', 'recents');
    this.quizzes = region('section', 'quizzes');
    this.player = region('div', 'player-host');
    this.live = h('div', { class: 'visually-hidden', attrs: { 'aria-live': 'polite', role: 'status' } });

    this.field = h('textarea', {
      class: 'say-field',
      attrs: { rows: 3, placeholder: t('sayPrompt'), 'aria-label': t('sayLabel'), autocapitalize: 'sentences', 'data-testid': 'say-field' },
      oninput: () => this.typed(),
    });
    this.style = h('input', {
      class: 'style-field',
      attrs: { type: 'text', placeholder: t('stylePrompt'), 'aria-label': t('stylePrompt'), maxlength: maxStyleChars, enterkeyhint: 'done', 'data-testid': 'style-field' },
      oninput: () => this.typed(),
    });
    this.form = h('div', { class: 'say-form' }, this.field, this.sayExtras.el, this.cost.el, this.sayError.el, this.sayButtons.el);

    const sheetHost = h('div', { class: 'sheet-host' });
    this.sheets = openSheet(sheetHost, deps, () => this.render());

    root.replaceChildren(
      h(
        'main',
        { class: 'page' },
        this.header.el,
        this.notice.el,
        h('section', { class: 'card say', attrs: { 'aria-label': t('sayLabel') } }, this.form, this.playing.el),
        this.recents.el,
        this.quizzes.el,
        h('p', { class: 'about', text: t('about') }),
      ),
      h(
        'nav',
        { class: 'toolbar' },
        h('button', { class: 'text-button', attrs: { type: 'button', 'data-testid': 'new-quiz' }, onclick: () => this.newQuiz() }, icon('plus', 26), h('span', { text: t('newQuiz') })),
      ),
      sheetHost,
      this.player.el,
      this.live,
    );
    window.setInterval(() => this.tick(), 250);
  }

  // MARK: What the user does

  private typed(): void {
    this.field.style.height = 'auto';
    this.field.style.height = `${Math.min(this.field.scrollHeight, 260)}px`;
    this.costNow = parts(this.field.value).length === 0 ? null : 'asking';
    if (this.costTimer !== null) window.clearTimeout(this.costTimer);
    this.costTimer = window.setTimeout(() => void this.askCost(), 700);
    if (this.deps.app.sayError !== null) {
      this.deps.app.sayError = null;
      this.deps.app.sayOutOfCredits = false;
    }
    this.render();
  }

  private async askCost(): Promise<void> {
    const asked = (this.costAsked += 1);
    const text = this.field.value;
    if (parts(text).length === 0 || chars(text) > maxChars) return;
    const cost = await this.deps.app.cost(text, this.style.value);
    if (asked !== this.costAsked) return; // the text has changed since
    this.costNow = cost;
    this.render();
  }

  private play(): void {
    this.blocked = false;
    this.stoppedByScreen = false;
    this.said = this.field.value;
    this.deps.flags.setItem(seenKey, '1');
    void this.deps.app.say(this.field.value, this.style.value);
  }

  private putBack(id: string): void {
    const said = this.deps.store.said.find((s) => s.id === id);
    if (said === undefined) return;
    if (this.editingRecents) {
      void this.deps.app.removeSaid(id);
      return;
    }
    this.field.value = said.text;
    this.style.value = said.style ?? '';
    const voice = this.deps.app.voices.find((v) => v.voice_id === said.voiceID) ?? null;
    if (said.voiceID === null || voice !== null) this.deps.app.chooseVoice(voice);
    this.typed();
    this.field.focus();
  }

  private newQuiz(): void {
    this.deps.app.openDraft();
  }

  private press(press: 1 | 2 | 3): void {
    this.blocked = false;
    this.stoppedByScreen = false;
    this.deps.app.press(press);
    this.render();
  }

  private startQuiz(id: string): void {
    this.blocked = false;
    this.stoppedByScreen = false;
    this.deps.flags.setItem(seenKey, '1');
    void this.deps.app.startExam(id);
  }

  private tick(): void {
    const text = this.deps.app.text;
    if (text === null) return;
    this.deps.app.tick();
    const seconds = text.secondsLeft();
    if (seconds !== null) this.timeLeft.textContent = this.deps.t(text.paused ? 'leftPaused' : 'left', { t: clockText(seconds) });
  }

  // MARK: The screen

  render(): void {
    const { app, t, lang, store, platform } = this.deps;
    const left = app.creditsLeft;
    const decimal = lang === 'sv' ? ',' : '.';
    const active = app.text !== null || app.quiz !== null;

    this.header.show(`${left}`, () => [
      h(
        'button',
        { class: 'capsule credits', attrs: { type: 'button', 'data-testid': 'credits' }, onclick: () => this.sheets.open('credits') },
        left === null ? t('credits') : left === Number.MAX_SAFE_INTEGER ? t('credits') : t('creditsLeft', { n: short(left, decimal) }),
      ),
      h('span', { class: 'beta', text: t('beta') }),
      h('span', { class: 'spacer' }),
      h('button', { class: 'round', attrs: { type: 'button', 'aria-label': t('settings'), 'data-testid': 'settings' }, onclick: () => this.sheets.open('settings') }, icon('gear', 22)),
    ]);

    // D250: the line shows the first time and whenever something plays.
    const firstTime = this.deps.flags.getItem(seenKey) === null;
    this.notice.show(`${firstTime || active}`, () =>
      firstTime || active
        ? [
            h(
              'div',
              { class: 'notice', attrs: { 'data-testid': 'screen-line' } },
              h('h2', { text: t('screenTitle') }),
              h('p', { text: t('screenLine') }),
              h('button', { class: 'link', attrs: { type: 'button' }, onclick: () => this.sheets.open('guide') }, h('span', { text: t('screenHow') }), icon('chevron', 14)),
            ),
          ]
        : [],
    );

    this.renderSay(left);
    this.renderPlaying();

    this.recents.show(JSON.stringify([store.said.map((s) => s.id), this.editingRecents]), () =>
      store.said.length === 0
        ? []
        : [
            h(
              'div',
              { class: 'section-head' },
              h('h2', { text: t('recent') }),
              h('button', {
                class: 'link small',
                text: this.editingRecents ? t('done') : t('remove'),
                attrs: { type: 'button' },
                onclick: () => {
                  this.editingRecents = !this.editingRecents;
                  this.render();
                },
              }),
            ),
            h(
              'div',
              { class: 'capsules' },
              ...store.said.map((s) =>
                h(
                  'button',
                  {
                    class: `capsule recent${this.editingRecents ? ' removing' : ''}`,
                    attrs: {
                      type: 'button',
                      'aria-label': this.editingRecents ? `${t('remove')}: ${capsule(s.text)}` : t('recentPuts', { text: [capsule(s.text), s.style ?? s.voiceName].filter(Boolean).join(', ') }),
                    },
                    onclick: () => this.putBack(s.id),
                  },
                  this.editingRecents ? icon('close', 14) : null,
                  h('span', { text: capsule(s.text) }),
                ),
              ),
            ),
          ],
    );
    if (store.said.length === 0) this.editingRecents = false;

    this.renderQuizzes(left);
    this.renderPlayer();
    this.sheets.render();

    // The lock screen and the AirPods' owner see what plays.
    if (app.text !== null && app.saidPlaying !== null) platform.nowPlaying(capsule(app.saidPlaying.text), t('sayLabel'), !app.text.paused);
    else if (app.quiz !== null && app.examPlaying !== null) platform.nowPlaying(t('question', { n: app.quiz.index + 1, m: app.quiz.count }), app.examPlaying.title, !app.quiz.paused);
    else platform.nothingPlaying();
  }

  private renderSay(left: number | null): void {
    const { app, t, lang, store } = this.deps;
    const text = this.field.value;
    const has = parts(text).length > 0;
    const length = chars(text);
    const tooLong = length > maxChars;
    const settings = store.settings;
    const voiceName = settings.voiceName ?? app.defaultVoiceName ?? t('voiceAuto');
    this.form.hidden = app.text !== null;

    this.sayExtras.show(JSON.stringify([has, voiceName, this.style.value === '']), () =>
      has
        ? [
            h(
              'div',
              { class: 'style-row' },
              h(
                'button',
                { class: 'capsule on-card', attrs: { type: 'button', 'aria-label': t('voiceLabel', { name: voiceName }), 'data-testid': 'voice' }, onclick: () => this.sheets.open('voices') },
                voiceName,
              ),
              this.style,
            ),
            this.style.value === ''
              ? h(
                  'div',
                  { class: 'capsules suggestions' },
                  ...t('styleSuggestions')
                    .split('|')
                    .map((word) =>
                      h('button', {
                        class: 'capsule on-card quiet',
                        text: word,
                        attrs: { type: 'button' },
                        onclick: () => {
                          this.style.value = addingStyle(word, this.style.value);
                          this.typed();
                        },
                      }),
                    ),
                )
              : null,
          ]
        : [],
    );

    const cost = this.costNow;
    this.cost.show(JSON.stringify([has, cost, left, tooLong, length]), () => {
      if (!has) return [];
      if (tooLong) return [h('p', { class: 'warn-text', text: t('tooLong', { n: grouped(length, lang), m: grouped(maxChars, lang) }) })];
      if (cost === null || cost === 'asking') return [h('p', { class: 'quiet-text', text: ' ' })];
      if (cost === 0) return [h('p', { class: 'quiet-text', text: t('costFree') })];
      if (left !== null && cost > left) {
        return [
          h('p', { class: 'warn-text', attrs: { 'data-testid': 'cost' }, text: t('costShort', { n: grouped(cost, lang), m: grouped(left, lang) }) }),
          h('p', { class: 'quiet-text', text: t('creditsBuy') }),
        ];
      }
      return [h('p', { class: 'quiet-text', attrs: { 'aria-label': t('costLabel', { n: cost }), 'data-testid': 'cost' }, text: t('cost', { n: grouped(cost, lang) }) })];
    });

    this.sayError.show(JSON.stringify([app.sayError, app.sayOutOfCredits]), () =>
      app.sayError === null
        ? []
        : [h('p', { class: 'warn-text', attrs: { role: 'alert', 'data-testid': 'say-error' }, text: app.sayError }), app.sayOutOfCredits ? h('p', { class: 'quiet-text', text: t('creditsBuy') }) : null],
    );

    const minutes = settings.minutes;
    this.sayButtons.show(JSON.stringify([has && !tooLong, app.sayBusy, minutes]), () => [
      h(
        'button',
        { class: 'round on-card', attrs: { type: 'button', 'aria-label': t('durationLabel', { n: minutes }), 'data-testid': 'duration' }, onclick: () => this.sheets.open('duration') },
        icon('clock', 22),
      ),
      h(
        'button',
        {
          class: 'main-button on-card',
          attrs: { type: 'button', disabled: !has || tooLong || app.sayBusy, 'data-testid': 'play' },
          onclick: () => this.play(),
        },
        app.sayBusy ? h('span', { class: 'spinner' }) : icon('play', 18),
        h('span', { text: app.sayBusy ? t('making') : minutes >= 60 ? t('playForHour') : t('playFor', { n: minutes }) }),
      ),
    ]);
  }

  private screenLine(): HTMLElement {
    const { t, platform } = this.deps;
    return h('p', { class: 'quiet-text', text: platform.awakeSupported && platform.awakeHeld() ? t('screenKept') : platform.awakeSupported ? ' ' : t('screenNotKept') });
  }

  /// "It stopped because the screen turned off. Play again?" and "The browser stopped the sound.".
  private stoppedLine(): HTMLElement | null {
    const { t } = this.deps;
    if (!this.stoppedByScreen && !this.blocked) return null;
    return h(
      'div',
      { class: 'stopped', attrs: { role: 'alert' } },
      h('p', { text: this.blocked ? t('blocked') : t('screenStopped') }),
      h('button', { class: 'capsule on-card', text: t('play'), attrs: { type: 'button', 'data-testid': 'play-again' }, onclick: () => this.press(1) }),
    );
  }

  private renderPlaying(): void {
    const { app, t, platform } = this.deps;
    const text = app.text;
    if (text === null) {
      this.playing.show('none', () => []);
      return;
    }
    const progress = app.soundProgress;
    const waiting = text.phase === 'waiting';
    const voice = app.saidPlaying?.voiceName ?? null;
    const sentence = this.sentenceNow();
    const key = JSON.stringify([text.phase, text.paused, text.position, text.lap, voice, waiting ? progress : null, sentence, platform.awakeHeld(), this.stoppedByScreen, this.blocked]);
    this.playing.show(key, () => {
      const seconds = text.secondsLeft();
      this.timeLeft.textContent = seconds === null ? '' : t(text.paused ? 'leftPaused' : 'left', { t: clockText(seconds) });
      const status = waiting ? (progress !== null && progress.total > 1 ? t('makingCount', { n: progress.done, m: progress.total }) : t('making')) : [t('playing'), voice].filter(Boolean).join(' · ');
      return [
        h('p', { class: `status${waiting || text.paused ? ' still' : ''}`, attrs: { 'data-testid': 'status' } }, h('span', { class: 'dot' }), h('span', { text: status })),
        h('p', { class: 'now', attrs: { 'data-testid': 'sentence' }, text: sentence }),
        this.stoppedLine(),
        h(
          'div',
          { class: 'transport' },
          h(
            'button',
            { class: 'big-round', attrs: { type: 'button', 'aria-label': text.paused ? t('resume') : t('pause'), 'data-testid': 'pause' }, onclick: () => this.press(1) },
            icon(text.paused ? 'play' : 'pause', 26),
          ),
          h('div', { class: 'time-block' }, this.timeLeft, text.lap > 0 ? h('span', { class: 'quiet-text', text: t('round', { n: text.lap + 1 }) }) : null),
          h('button', { class: 'round ghost', attrs: { type: 'button', 'aria-label': t('previousSentence') }, onclick: () => this.press(3) }, icon('previous', 20)),
          h('button', { class: 'round ghost', attrs: { type: 'button', 'aria-label': t('nextSentence') }, onclick: () => this.press(2) }, icon('next', 20)),
          h('button', { class: 'link on-card', text: t('stop'), attrs: { type: 'button', 'data-testid': 'stop' }, onclick: () => app.stopAll() }),
        ),
        this.screenLine(),
        h('p', { class: 'quiet-text hint', text: t('pressesText') }),
      ];
    });
    this.announce(waiting ? t('making') : text.paused ? t('paused') : t('playing'));
  }

  private sentenceNow(): string {
    const text = this.deps.app.text;
    if (text === null) return '';
    const lines = parts(this.said);
    return this.deps.app.sentence(text.position) ?? lines[text.position.part] ?? '';
  }

  private perRound(count: number): number {
    return Math.max(1, Math.round((count * (thinkingSeconds(count) + 7)) / 60));
  }

  private quizCard(exam: SavedExam, left: number | null, first: boolean): HTMLElement {
    const { app, t, lang } = this.deps;
    const busy = app.examBusy === exam.id;
    const error = app.examError?.id === exam.id ? app.examError.message : null;
    const count = exam.questions.length;
    const short = !exam.started && exam.cost !== null && left !== null && exam.cost > left;
    return h(
      'article',
      { class: `card quiz${first ? ' next' : ''}`, attrs: { 'data-testid': 'quiz' } },
      first ? h('p', { class: 'quiet-text', text: t('nextQuiz') }) : null,
      h(
        'div',
        { class: 'quiz-head' },
        h('h3', { text: exam.title }),
        h('button', { class: 'round ghost', attrs: { type: 'button', 'aria-label': `${t('quizDelete')}: ${exam.title}` }, onclick: () => this.sheets.confirm(t('quizDeleteAsk'), t('remove'), () => void app.deleteExam(exam.id)) }, icon('trash', 20)),
      ),
      h('p', { class: 'quiet-text', text: `${t('quizQuestions', { n: count })} · ${t('quizPerRound', { n: this.perRound(count) })}` }),
      !exam.started && exam.cost !== null && exam.cost > 0
        ? h('p', { class: short ? 'warn-text' : 'quiet-text', text: short ? t('costShort', { n: grouped(exam.cost, lang), m: grouped(left ?? 0, lang) }) : t('quizCostAtStart', { n: grouped(exam.cost, lang) }) })
        : null,
      short ? h('p', { class: 'quiet-text', text: t('creditsBuy') }) : null,
      error !== null ? h('p', { class: 'warn-text', attrs: { role: 'alert' }, text: error }) : null,
      h(
        'button',
        { class: 'main-button tinted', attrs: { type: 'button', disabled: busy, 'data-testid': 'start-quiz' }, onclick: () => this.startQuiz(exam.id) },
        busy ? h('span', { class: 'spinner' }) : icon('play', 18),
        h('span', { text: busy ? t('making') : exam.started && exam.index > 0 ? t('quizContinueAt', { n: exam.index + 1 }) : t('quizStart') }),
      ),
      first ? h('p', { class: 'quiet-text', text: t('quizNoMic') }) : null,
    );
  }

  private renderQuizzes(left: number | null): void {
    const { app, t, store } = this.deps;
    const exams = store.exams;
    const key = JSON.stringify([exams.map((e) => [e.id, e.started, e.index, e.cost]), app.examBusy, app.examError, left]);
    this.quizzes.show(key, () => {
      if (exams.length === 0) {
        return [
          h(
            'article',
            { class: 'card quiz empty' },
            h('h3', { text: t('newQuiz') }),
            h('p', { class: 'quiet-text', text: t('quizLine') }),
            h('button', { class: 'main-button tinted', attrs: { type: 'button' }, onclick: () => this.newQuiz() }, icon('plus', 20), h('span', { text: t('newQuiz') })),
          ),
        ];
      }
      const [first, ...others] = exams;
      return [this.quizCard(first, left, true), others.length > 0 ? h('h2', { class: 'list-title', text: t('otherQuizzes') }) : null, ...others.map((e) => this.quizCard(e, left, false))];
    });
  }

  /// The quiz while it plays: its own screen, like the app's.
  private renderPlayer(): void {
    const { app, t, platform } = this.deps;
    const quiz = app.quiz;
    const exam = app.examPlaying;
    if (quiz === null || exam === null) {
      this.player.show('none', () => []);
      this.player.el.hidden = true;
      return;
    }
    this.player.el.hidden = false;
    const phase = quiz.phase;
    const item = exam.questions[quiz.index];
    const progress = app.soundProgress;
    const key = JSON.stringify([phase, quiz.paused, quiz.lap, phase.kind === 'waiting' ? progress : null, platform.awakeHeld(), this.stoppedByScreen, this.blocked]);
    this.player.show(key, () => {
      const answering = phase.kind === 'answer';
      const label = quiz.paused
        ? t('paused')
        : phase.kind === 'waiting'
          ? progress !== null
            ? t('makingCount', { n: progress.done, m: progress.total })
            : t('making')
          : phase.kind === 'thinking'
            ? t('think')
            : answering
              ? t(phase.answer === 'long' ? 'longAnswer' : 'shortAnswer')
              : ' ';
      const body = answering ? (phase.answer === 'long' ? item?.long : item?.short) : item?.question;
      return [
        h(
          'div',
          { class: 'player', attrs: { role: 'dialog', 'aria-modal': 'true', 'aria-label': exam.title, 'data-testid': 'player' } },
          h(
            'div',
            { class: 'player-top' },
            h('div', {}, h('p', { class: 'status' }, h('span', { class: 'dot' }), h('span', { text: t('playing') })), h('h2', { attrs: { 'data-testid': 'question-number' }, text: t('question', { n: quiz.index + 1, m: quiz.count }) }), quiz.lap > 0 ? h('p', { class: 'quiet-text', text: t('round', { n: quiz.lap + 1 }) }) : null),
            h('button', { class: 'link on-card', text: t('end'), attrs: { type: 'button', 'data-testid': 'end' }, onclick: () => app.stopAll() }),
          ),
          h(
            'div',
            { class: 'player-middle' },
            h('p', { class: 'phase', attrs: { 'data-testid': 'phase' }, text: label }),
            phase.kind === 'thinking' && !quiz.paused ? h('div', { class: 'think-bar' }, h('div', { class: 'think-fill', attrs: { style: `animation-duration:${quiz.thinkingMs}ms` } })) : null,
            h('p', { class: `player-text${answering ? ' answer' : ''}`, attrs: { 'data-testid': 'player-text' }, text: body ?? '' }),
            this.stoppedLine(),
          ),
          h(
            'div',
            { class: 'player-bottom' },
            h(
              'div',
              { class: 'answers' },
              h('button', { class: 'main-button on-card', attrs: { type: 'button', 'data-testid': 'long' }, onclick: () => this.press(1) }, h('span', { text: quiz.paused ? t('resume') : t('longAnswer') })),
              h('button', { class: 'main-button card-tint', attrs: { type: 'button', 'data-testid': 'short', disabled: quiz.paused }, onclick: () => this.press(2) }, h('span', { text: t('shortAnswer') })),
              h('button', { class: 'round on-card-ghost', attrs: { type: 'button', 'aria-label': quiz.paused ? t('resume') : t('pause'), 'data-testid': 'quiz-pause' }, onclick: () => this.press(3) }, icon(quiz.paused ? 'play' : 'pause', 22)),
            ),
            this.screenLine(),
            h('p', { class: 'quiet-text hint', text: t('pressesQuiz') }),
          ),
        ),
      ];
    });
    this.announce(quiz.paused ? t('paused') : t('question', { n: quiz.index + 1, m: quiz.count }));
  }

  private announced = '';
  private announce(text: string): void {
    if (text === this.announced) return;
    this.announced = text;
    this.live.textContent = text;
  }
}
