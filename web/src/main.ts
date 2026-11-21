import { Client, type KeyValue } from './api/client';
import { DrillApi } from './api/drill';
import { ExamApi } from './api/exam';
import { App } from './app';
import { backend, testTraffic } from './config';
import { BrowserSound, ScreenAwake, browserClock, listenForPresses, showNothingPlaying, showNowPlaying } from './platform/browser';
import { Store } from './store';
import './styles.css';
import { pickLanguage, translator, type Lang } from './texts';
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

// D251: English, or Swedish for a Swedish browser; the choice in Settings wins.
const chosen = kept.getItem(langKey);
const lang: Lang = chosen === 'sv' || chosen === 'en' ? chosen : pickLanguage(navigator.languages, navigator.language);
document.documentElement.lang = lang;
const t = translator(lang);

const audio = document.querySelector<HTMLAudioElement>('#sound') ?? document.body.appendChild(document.createElement('audio'));
const sound = new BrowserSound(audio);
const awake = new ScreenAwake();
const client = new Client(backend, (url, init) => fetch(url, init), kept, () => Date.now(), testTraffic(window.location.search, tab), lang);
const store = new Store(kept);
const app = new App({ drill: new DrillApi(client), exam: new ExamApi(client), sound, clock: browserClock, store, awake, t });

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
  platform: {
    awakeSupported: awake.supported,
    awakeHeld: () => awake.held,
    pageHidden: () => document.visibilityState === 'hidden',
    nowPlaying: showNowPlaying,
    nothingPlaying: showNothingPlaying,
    setLanguage: (code) => {
      kept.setItem(langKey, code);
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
awake.onChange = () => view.render();
sample.addEventListener('ended', () => view.render());

// The sound stopped by itself. With the page hidden it was the screen (D250): the user is told when they come back.
sound.onInterrupted = () => {
  if (!app.isPlaying) return;
  view.stoppedByScreen = true;
  app.interrupted();
};
sound.onBlocked = () => {
  if (!app.isPlaying) return;
  view.blocked = true;
  app.interrupted();
};

// The AirPods: one press, two presses, three presses (and the lock screen's buttons).
listenForPresses(
  (press) => {
    view.stoppedByScreen = false;
    view.blocked = false;
    app.press(press);
    view.render();
  },
  () => app.stopAll(),
);

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') {
    void app.refreshQuota();
    view.render();
  }
});

view.render();
void app.init();
