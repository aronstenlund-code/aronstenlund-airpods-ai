import type { Voice } from '../api/drill';
import { App } from '../app';
import { repeats } from '../core/said';
import { dayText, grouped } from '../texts';
import { h, icon } from './dom';
import type { ViewDeps } from './view';

export type SheetName = 'credits' | 'guide' | 'voices' | 'duration' | 'settings';

export interface Sheets {
  open(name: SheetName): void;
  confirm(question: string, action: string, run: () => void): void;
  /// Called with every change: shows the sheet that should be up (New quiz follows the app's draft).
  render(): void;
}

const questionChoices = [3, 5, 8, 10, 12, 15, 20, 25, 30];

/// The sheets that come up from the bottom, one at a time, as in the app.
export function openSheet(host: HTMLElement, deps: ViewDeps, changed: () => void): Sheets {
  const { app, t, lang, store, platform } = deps;
  let name: SheetName | null = null;
  let asking: { question: string; action: string; run: () => void } | null = null;
  let shown = '';
  let opener: Element | null = null;
  // New quiz: what has been typed stays while the server works, and comes back if it says no.
  let quizText = '';
  let quizCount = App.defaultQuestions;
  let correcting = false;
  // Open link: what was pasted stays while the server looks.
  let linkText = '';

  const close = (): void => {
    platform.preview(null);
    if (asking !== null) asking = null;
    else if (name !== null) name = null;
    else if (app.link.stage !== 'closed') app.closeLink();
    else if (app.draft.stage !== 'closed') {
      correcting = false;
      app.closeDraft();
    }
    changed();
  };

  host.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') close();
  });

  const sheet = (title: string, body: (Node | null)[], options: { done?: string; bottom?: Node | null; testid?: string } = {}): HTMLElement =>
    h(
      'div',
      { class: 'sheet-back', onclick: (event) => (event.target === event.currentTarget ? close() : undefined) },
      h(
        'div',
        { class: 'sheet', attrs: { role: 'dialog', 'aria-modal': 'true', 'aria-label': title, tabindex: -1, 'data-testid': options.testid ?? 'sheet' } },
        h('div', { class: 'sheet-top' }, h('span', { class: 'spacer' }), h('h2', { text: title }), h('button', { class: 'link strong', text: options.done ?? t('done'), attrs: { type: 'button', 'data-testid': 'sheet-done' }, onclick: close })),
        h('div', { class: 'sheet-body' }, ...body),
        options.bottom ? h('div', { class: 'sheet-bottom' }, options.bottom) : null,
      ),
    );

  const row = (left: string, right: string): HTMLElement => h('div', { class: 'row' }, h('span', { text: left }), h('span', { class: 'quiet-text', text: right }));

  const credits = (): HTMLElement => {
    const left = app.creditsLeft;
    const quota = app.quota;
    const day = quota?.resets_day ?? quota?.resets ?? null;
    const dayWords = day === null ? null : dayText(day, lang);
    return sheet(
      t('credits'),
      [
        left === null
          ? h('p', { class: 'quiet-text center', text: t('creditsUnknown') })
          : h('div', { class: 'big-number' }, h('strong', { attrs: { 'data-testid': 'credits-number' }, text: left === Number.MAX_SAFE_INTEGER ? '∞' : grouped(left, lang) }), h('span', { text: t('creditsBig') })),
        quota !== null && quota.unlimited !== true ? h('p', { class: 'quiet-text center', text: t('creditsMonthly', { n: grouped(quota.limit, lang) }) }) : null,
        h('h3', { class: 'group-title', text: t('creditsHow') }),
        h('div', { class: 'group' }, row(t('creditsRow1'), t('creditsRow1v')), row(t('creditsRow2'), '0'), row(t('creditsRow3'), '0')),
        dayWords !== null ? h('p', { class: 'quiet-text', text: t('creditsNew', { day: dayWords }) }) : null,
        h('p', { class: 'buy-line', attrs: { 'data-testid': 'no-purchases' }, text: t('creditsBuy') }),
      ],
      { testid: 'credits-sheet' },
    );
  };

  const guide = (): HTMLElement =>
    sheet(
      t('screenTitle'),
      [
        h('p', { text: t('guideIntro') }),
        h('div', { class: 'group pad' }, h('h3', { text: t('guideIphone') }), h('p', { text: t('guideIphoneSteps') }), h('p', { class: 'quiet-text', text: t('guideLowPower') })),
        h('div', { class: 'group pad' }, h('h3', { text: t('guideAndroid') }), h('p', { text: t('guideAndroidSteps') })),
        h('p', { class: 'quiet-text', text: t('guideAfter') }),
      ],
      { testid: 'guide-sheet' },
    );

  let previewing: string | null = null;
  const voices = (): HTMLElement => {
    const chosen = store.settings.voiceID;
    const pick = (voice: Voice | null): void => {
      app.chooseVoice(voice);
      changed();
    };
    const line = (voice: Voice): string => [voice.accent, voice.description].filter(Boolean).join(' · ');
    return sheet(
      t('voice'),
      [
        app.voices.length === 0 ? h('p', { class: 'quiet-text', text: t('voicesNone') }) : null,
        h(
          'div',
          { class: 'group' },
          h(
            'button',
            { class: 'row tappable', attrs: { type: 'button', 'aria-pressed': chosen === null }, onclick: () => pick(null) },
            h('span', { text: app.defaultVoiceName === null ? t('voiceAuto') : `${t('voiceAuto')} · ${app.defaultVoiceName}` }),
            chosen === null ? icon('check', 20) : null,
          ),
          ...app.voices.map((voice) =>
            h(
              'div',
              { class: 'row voice' },
              voice.preview_url
                ? h(
                    'button',
                    {
                      class: 'round small',
                      attrs: { type: 'button', 'aria-label': t('voicePreview', { name: voice.name }) },
                      onclick: () => {
                        previewing = previewing === voice.voice_id ? null : voice.voice_id;
                        platform.preview(previewing === null ? null : (voice.preview_url as string));
                        changed();
                      },
                    },
                    icon(previewing === voice.voice_id ? 'pause' : 'play', 16),
                  )
                : h('span', { class: 'round small empty' }),
              h(
                'button',
                { class: 'voice-pick', attrs: { type: 'button', 'aria-pressed': chosen === voice.voice_id, 'data-testid': 'voice-row' }, onclick: () => pick(voice) },
                h('span', { class: 'voice-name', text: voice.name }),
                line(voice) ? h('span', { class: 'quiet-text', text: line(voice) }) : null,
              ),
              chosen === voice.voice_id ? icon('check', 20) : null,
            ),
          ),
        ),
        h('p', { class: 'quiet-text', text: t('voicesNote') }),
      ],
      { testid: 'voices-sheet' },
    );
  };

  const duration = (): HTMLElement =>
    sheet(t('durationTitle'), [
      h(
        'div',
        { class: 'group' },
        ...repeats.map((minutes) =>
          h(
            'button',
            {
              class: 'row tappable',
              attrs: { type: 'button', 'aria-pressed': store.settings.minutes === minutes },
              onclick: () => {
                app.chooseMinutes(minutes);
                name = null;
                changed();
              },
            },
            h('span', { text: minutes >= 60 ? t('durationHour') : t('durationMin', { n: minutes }) }),
            store.settings.minutes === minutes ? icon('check', 20) : null,
          ),
        ),
      ),
    ]);

  const settings = (): HTMLElement =>
    sheet(t('settings'), [
      h('h3', { class: 'group-title', text: t('language') }),
      h(
        'div',
        { class: 'group' },
        ...(['en', 'sv'] as const).map((code) =>
          h('button', { class: 'row tappable', attrs: { type: 'button', 'aria-pressed': lang === code, lang: code }, onclick: () => platform.setLanguage(code) }, h('span', { text: t(code === 'en' ? 'english' : 'swedish') }), lang === code ? icon('check', 20) : null),
        ),
      ),
      h(
        'div',
        { class: 'group' },
        h(
          'button',
          {
            class: 'row tappable',
            attrs: { type: 'button' },
            onclick: () => {
              name = 'guide';
              changed();
            },
          },
          h('span', { text: t('screenTitle') }),
          icon('chevron', 16),
        ),
      ),
      h('h3', { class: 'group-title', text: t('privacyTitle') }),
      h('p', { class: 'quiet-text', text: t('privacyLine') }),
      h(
        'div',
        { class: 'group' },
        h('button', { class: 'row tappable danger', attrs: { type: 'button', 'data-testid': 'forget' }, onclick: () => ask(t('startOverAsk'), t('startOver'), () => void app.forgetEverything()) }, h('span', { text: t('startOver') })),
      ),
      h('p', { class: 'quiet-text', text: t('startOverLine') }),
    ]);

  // MARK: New quiz

  const waiting = (words: string): HTMLElement => sheet(t('newQuiz'), [h('div', { class: 'working', attrs: { role: 'status' } }, h('span', { class: 'spinner large' }), h('p', { text: words }))], { done: t('cancel'), testid: 'quiz-sheet' });

  const write = (error: string | null): HTMLElement => {
    const field = h('textarea', {
      class: 'quiz-field',
      attrs: { rows: 8, placeholder: t('quizText'), 'aria-label': t('quizText'), 'data-testid': 'quiz-text' },
      oninput: () => {
        quizText = field.value;
        make.disabled = quizText.trim().length === 0;
      },
    });
    field.value = quizText;
    const count = h(
      'select',
      {
        class: 'select',
        attrs: { 'aria-label': t('quizCount'), 'data-testid': 'quiz-count' },
        onchange: () => {
          quizCount = Number(count.value);
        },
      },
      ...questionChoices.map((n) => h('option', { text: String(n), attrs: { value: n, selected: n === quizCount } })),
    );
    const make = h(
      'button',
      { class: 'main-button', attrs: { type: 'button', disabled: quizText.trim().length === 0, 'data-testid': 'quiz-create' }, onclick: () => void app.makeQuestions(quizText, quizCount) },
      h('span', { text: t('quizCreate') }),
    );
    return sheet(
      t('newQuiz'),
      [
        h('p', { class: 'quiet-text', text: t('quizLine') }),
        field,
        h('label', { class: 'group' }, h('span', { class: 'row' }, h('span', { text: t('quizCount') }), count)),
        error !== null ? h('p', { class: 'warn-text', attrs: { role: 'alert', 'data-testid': 'quiz-error' }, text: error }) : null,
        error !== null && app.creditsLeft !== null ? h('p', { class: 'quiet-text', text: t('creditsBuy') }) : null,
      ],
      { done: t('cancel'), bottom: make, testid: 'quiz-sheet' },
    );
  };

  const check = (draft: Extract<App['draft'], { stage: 'check' }>): HTMLElement => {
    const correction = h('input', { class: 'input', attrs: { type: 'text', placeholder: t('quizCorrection'), 'aria-label': t('quizCorrection'), 'data-testid': 'quiz-correction' } });
    return sheet(
      t('quizCheckTitle'),
      [
        draft.note !== null ? h('p', { class: 'note', attrs: { 'data-testid': 'quiz-note' }, text: draft.note }) : null,
        h('div', { class: 'group' }, row(t('quizSubject'), [draft.reply.summary.subject, draft.reply.summary.grade].filter(Boolean).join(' · ')), h('div', { class: 'row tall' }, h('span', { text: t('quizCovers') }), h('span', { class: 'quiet-text', text: draft.reply.summary.covers }))),
        h('h3', { class: 'group-title', text: t('quizQuestions', { n: draft.reply.items.length }) }),
        h('ol', { class: 'group questions' }, ...draft.reply.items.map((item) => h('li', { text: item.question }))),
        draft.error !== null ? h('p', { class: 'warn-text', attrs: { role: 'alert' }, text: draft.error }) : null,
        correcting
          ? h('div', { class: 'correct' }, correction, h('button', { class: 'capsule', text: t('quizRedo'), attrs: { type: 'button', disabled: draft.busy }, onclick: () => void app.correct(correction.value) }))
          : h('button', {
              class: 'link',
              text: t('quizWrong'),
              attrs: { type: 'button', 'data-testid': 'quiz-wrong' },
              onclick: () => {
                correcting = true;
                changed();
              },
            }),
      ],
      {
        done: t('cancel'),
        testid: 'quiz-sheet',
        bottom: h('button', { class: 'main-button', attrs: { type: 'button', disabled: draft.busy, 'data-testid': 'quiz-right' }, onclick: () => void app.acceptExam() }, draft.busy ? h('span', { class: 'spinner' }) : null, h('span', { text: t('quizRight') })),
      },
    );
  };

  // MARK: Open link

  const linkSheet = (link: Exclude<App['link'], { stage: 'closed' }>): HTMLElement => {
    const field = h('input', { class: 'input', attrs: { type: 'url', inputmode: 'url', autocapitalize: 'none', autocomplete: 'off', placeholder: t('linkPrompt'), 'aria-label': t('linkPrompt'), 'data-testid': 'link-field' } });
    field.value = linkText;
    field.addEventListener('input', () => {
      linkText = field.value;
    });
    const go = (): void => void app.lookUp(linkText);
    field.addEventListener('keydown', (event) => (event.key === 'Enter' ? go() : undefined));
    const found = link.stage === 'found' ? link : null;
    return sheet(
      t('linkTitle'),
      [
        field,
        found === null
          ? null
          : h(
              'div',
              { class: 'group pad', attrs: { 'data-testid': 'link-found' } },
              h('h3', { text: found.info.title ?? t('newQuiz') }),
              h('p', { class: 'quiet-text', text: [found.info.subject, found.info.grade, found.info.items !== undefined ? t('quizQuestions', { n: found.info.items }) : null].filter(Boolean).join(' \u00b7 ') }),
            ),
        link.error !== null ? h('p', { class: 'warn-text', attrs: { role: 'alert', 'data-testid': 'link-error' }, text: link.error }) : null,
        h('p', { class: 'quiet-text', text: t('linkFree') }),
      ],
      {
        done: t('cancel'),
        testid: 'link-sheet',
        bottom:
          found === null
            ? h('button', { class: 'main-button', attrs: { type: 'button', disabled: link.busy, 'data-testid': 'link-open' }, onclick: go }, link.busy ? h('span', { class: 'spinner' }) : null, h('span', { text: t('linkOpen') }))
            : h('button', { class: 'main-button', attrs: { type: 'button', disabled: found.busy, 'data-testid': 'link-add' }, onclick: () => void app.addShared() }, found.busy ? h('span', { class: 'spinner' }) : null, h('span', { text: t('linkAdd') })),
      },
    );
  };

  const confirmBox = (a: { question: string; action: string; run: () => void }): HTMLElement =>
    h(
      'div',
      { class: 'sheet-back middle', onclick: (event) => (event.target === event.currentTarget ? close() : undefined) },
      h(
        'div',
        { class: 'confirm', attrs: { role: 'alertdialog', 'aria-modal': 'true', 'aria-label': a.question, tabindex: -1 } },
        h('p', { text: a.question }),
        h(
          'div',
          { class: 'confirm-buttons' },
          h('button', { class: 'capsule', text: t('cancel'), attrs: { type: 'button' }, onclick: close }),
          h('button', {
            class: 'capsule danger',
            text: a.action,
            attrs: { type: 'button', 'data-testid': 'confirm' },
            onclick: () => {
              asking = null;
              a.run();
              changed();
            },
          }),
        ),
      ),
    );

  const ask = (question: string, action: string, run: () => void): void => {
    asking = { question, action, run };
    changed();
  };

  const render = (): void => {
    const draft = app.draft;
    let key: string;
    let build: () => HTMLElement | null;
    if (asking !== null) {
      const a = asking;
      key = `ask:${a.question}`;
      build = () => confirmBox(a);
    } else if (name !== null) {
      const which = name;
      key = `${which}:${JSON.stringify(which === 'credits' ? [app.quota] : which === 'voices' ? [store.settings.voiceID, app.voices.length, previewing] : which === 'duration' ? [store.settings.minutes] : [])}`;
      build = () => ({ credits, guide, voices, duration, settings })[which]();
    } else if (app.link.stage !== 'closed') {
      const link = app.link;
      key = `link:${JSON.stringify(link)}`;
      build = () => linkSheet(link);
    } else if (draft.stage === 'write') {
      key = `write:${draft.error}`;
      build = () => write(draft.error);
    } else if (draft.stage === 'making') {
      key = 'making';
      build = () => waiting(t('quizReading'));
    } else if (draft.stage === 'answering') {
      key = 'answering';
      build = () => waiting(t('quizAnswering'));
    } else if (draft.stage === 'check') {
      key = `check:${JSON.stringify([draft.reply.items, draft.reply.summary, draft.note, draft.error, draft.busy, correcting])}`;
      build = () => check(draft);
    } else {
      key = '';
      build = () => null;
      if (shown !== '') {
        // A quiz that was just saved or added: the next one starts empty.
        if (shown.startsWith('link:')) linkText = '';
        else quizText = '';
        correcting = false;
      }
    }
    if (key === shown) return;
    const wasOpen = shown !== '';
    shown = key;
    const el = build();
    if (el === null) {
      host.replaceChildren();
      host.classList.remove('open', 'entering');
      if (opener instanceof HTMLElement) opener.focus();
      opener = null;
      return;
    }
    if (!wasOpen) opener = document.activeElement;
    host.replaceChildren(el);
    host.classList.add('open');
    host.classList.toggle('entering', !wasOpen); // it comes up once; what changes in it afterwards stays still
    // The sheet is where the keyboard and VoiceOver go: the field if there is one, else the sheet itself.
    const first = el.querySelector<HTMLElement>('textarea, input[type="url"], [role="dialog"], [role="alertdialog"]');
    if (!wasOpen || first instanceof HTMLTextAreaElement) first?.focus({ preventScroll: true });
  };

  return {
    open(which) {
      name = which;
      changed();
    },
    confirm: ask,
    render,
  };
}
