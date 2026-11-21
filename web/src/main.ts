import { Client, type KeyValue } from './api/client';
import { DrillApi } from './api/drill';
import { ListenApi } from './api/listen';
import { ExamApi } from './api/exam';
import { App } from './app';
import { backend, testTraffic } from './config';
import { ListenSession } from './listen/session';
import { BrowserSound, ScreenAwake, browserClock, listenForPresses, showNothingPlaying, showNowPlaying } from './platform/browser';
import { BrowserMic, openLine } from './platform/mic';
import { Store } from './store';
import './styles.css';
import { chosenLanguage, translator, type Lang } from './texts';
import { View } from './ui/view';

/// The browser's storage, or the visit's memory when it is switched off (private windows): the beta still works.
function storage(pick: () => Storage): KeyValue {
  const memory = new Map<string, string>();
  let real: Storage | null = null;
  try {
    real = pick();
    real.setItem('earmind.probe', '1');
    real.removeItem('earmind.probe');
  } catch {
    real = null;
  }
  return {
    getItem: (key) => (real !== null ? real.getItem(key) : (memory.get(key) ?? null)),
    setItem: (key, value) => {
      memory.set(key, value);
      try {
        real?.setItem(key, value);
      } catch {
        /* full: this visit keeps it */
      }
    },
    removeItem: (key) => {
      memory.delete(key);
      real?.removeItem(key);
    },
  };
}

const kept = storage(() => window.localStorage);
const tab = storage(() => window.sessionStorage);
const langKey = 'earmind.beta.lang';

// D253: always English first; Swedish when the user has chosen it with the EN/SV switch (kept in this browser).
const lang: Lang = chosenLanguage(kept.getItem(langKey));
const draftKey = 'earmind.beta.draft';
const consentKey = 'earmind.beta.consent.v1';
document.documentElement.lang = lang;
const t = translator(lang);

const audio = document.querySelector<HTMLAudioElement>('#sound') ?? document.body.appendChild(document.createElement('audio'));
const sound = new BrowserSound(audio);
const awake = new ScreenAwake();
const client = new Client(backend, (url, init) => fetch(url, init), kept, () => Date.now(), testTraffic(window.location.search, tab), lang);
const store = new Store(kept);
const files = {
  link: (bytes: Uint8Array, name: string): string => URL.createObjectURL(new File([bytes], name, { type: 'audio/mpeg' })),
  forget: (url: string): void => URL.revokeObjectURL(url),
};

// Listening (A156 part 2): the microphone is transcribed, a question is answered and read aloud. One thing at a
// time: it stops whatever plays, and Play stops it.
const listen: ListenSession = new ListenSession({
  api: new ListenApi(client),
  mic: new BrowserMic(),
  open: openLine,
  sound,
  files,
  clock: browserClock,
  awake,
  lang,
  voiceID: () => store.settings.voiceID,
  t,
  stopOthers: () => app.stopAll(),
});

const app: App = new App({
  online: () => navigator.onLine,
  stopListening: () => listen.stop(),
  drill: new DrillApi(client),
  exam: new ExamApi(client),
  sound,
  clock: browserClock,
  store,
  awake,
  t,
  // D253 "Download the sound": the files the server already made, fetched as they are and handed to the browser.
  files: {
    bytes: async (url) => {
      const reply = await fetch(url);
      if (!reply.ok) throw new Error(`sound file: ${reply.status}`);
      return new Uint8Array(await reply.arrayBuffer());
    },
    ...files,
  },
});

// A voice's sample has its own element: it is only heard while nothing else plays.
const sample = new Audio();
sample.preload = 'none';

const root = document.querySelector<HTMLElement>('#app');
if (root === null) throw new Error('EarMind: #app is missing');

const view = new View(root, {
  app,
  store,
  t,
  lang,
  flags: kept,
  listen,
  // D21: the consent is kept in this browser with the day it was given; taking it back removes it.
  consent: {
    given: () => kept.getItem(consentKey),
    give: () => kept.setItem(consentKey, new Date().toISOString().slice(0, 10)),
    withdraw: () => kept.removeItem(consentKey),
  },
  platform: {
    awakeSupported: awake.supported,
    awakeHeld: () => awake.held,
    pageHidden: () => document.visibilityState === 'hidden',
    nowPlaying: showNowPlaying,
    nothingPlaying: showNothingPlaying,
    setLanguage: (code) => {
      if (code === lang) return;
      kept.setItem(langKey, code);
      // Everything is shown again in the new language; what was being typed comes along.
      tab.setItem(draftKey, JSON.stringify(view.typed()));
      window.location.reload();
    },
    preview: (url) => {
      sample.pause();
      if (url === null) return;
      sample.src = url;
      void sample.play().catch(() => undefined);
    },
  },
});

app.onChange = () => view.render();
listen.onChange = () => view.render();
awake.onChange = () => view.render();
sample.addEventListener('ended', () => view.render());

// The sound stopped by itself. With the page hidden it was the screen (D250): the user is told when they come back.
sound.onInterrupted = () => {
  if (listen.isOn) {
    listen.press(); // the answer stopped by itself: the page listens again
    return;
  }
  if (!app.isPlaying) return;
  view.stoppedByScreen = true;
  app.interrupted();
};
sound.onBlocked = () => {
  if (listen.isOn) {
    listen.press();
    return;
  }
  if (!app.isPlaying) return;
  view.blocked = true;
  app.interrupted();
};

// The AirPods: one press, two presses, three presses (and the lock screen's buttons).
listenForPresses(
  (press) => {
    view.stoppedByScreen = false;
    view.blocked = false;
    if (listen.isOn) listen.press();
    else app.press(press);
    view.render();
  },
  () => {
    listen.stop();
    app.stopAll();
  },
);

document.addEventListener('visibilitychange', () => {
  // The page never listens where it cannot be seen: hidden, or the screen dark, ends the listening (D250).
  if (document.visibilityState === 'hidden') listen.halt(t('listenHidden'));
  if (document.visibilityState === 'visible') {
    void app.refreshQuota();
    view.render();
  }
});

try {
  const draft = JSON.parse(tab.getItem(draftKey) ?? 'null') as { text?: string; style?: string } | null;
  tab.removeItem(draftKey);
  if (draft !== null) view.fill(String(draft.text ?? ''), String(draft.style ?? ''));
} catch {
  /* nothing to bring back */
}

view.render();
void app.init();
