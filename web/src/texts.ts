/// Every word the beta shows, in English (the base, D251) and Swedish. The words are Kelly's (Ke86:
/// docs/design/engelska.md and docs/design/webbeta.md); the Swedish follows the iOS app where the same thing is said
/// there. One place, so her changes go in without touching anything else. `{name}` is filled in by `t()`.
export type Lang = 'en' | 'sv';

/// D251: Swedish when the browser is Swedish, otherwise English.
export function pickLanguage(languages: readonly string[] | undefined, fallback: string | undefined): Lang {
  const first = (languages && languages.length > 0 ? languages[0] : fallback) ?? 'en';
  return first.toLowerCase().startsWith('sv') ? 'sv' : 'en';
}

const en = {
  beta: 'Beta',
  creditsLeft: '{n} credits left',
  settings: 'Settings',
  done: 'Done',
  cancel: 'Cancel',
  tryAgain: 'Try again',

  // The screen has to be on (D250). "10 m" with a space that does not break.
  screenTitle: 'Keep the screen on',
  screenLine: 'In the beta, the screen has to stay on while it plays or listens. Your phone can be up to about 10 m (33 ft) from your AirPods, so you can put it down.',
  screenHow: 'How to keep it on',
  screenKept: 'The screen stays on while it plays.',
  screenNotKept: 'This browser can’t keep the screen on by itself. Set Auto-Lock to Never while you listen.',
  screenStopped: 'It stopped because the screen turned off. Play again?',
  guideIntro: 'The beta keeps the screen awake while it plays. If your screen still turns off:',
  guideIphone: 'iPhone',
  guideIphoneSteps: 'Settings › Display & Brightness › Auto-Lock › Never.',
  guideLowPower: 'Low Power Mode locks the screen after 30 seconds anyway, so turn it off while you listen.',
  guideAndroid: 'Android',
  guideAndroidSteps: 'Settings › Display › Screen timeout.',
  guideAfter: 'Change it back when you’re done.',

  // Say in AirPods
  sayLabel: 'Say in AirPods',
  sayPrompt: 'Type or paste what you want to hear',
  stylePrompt: 'How should it sound?',
  styleSuggestions: 'Clear|Calm|Cheerful|Whisper',
  voice: 'Voice',
  voiceLabel: 'Voice, {name}',
  voiceAuto: 'EarMind chooses',
  voicesNone: 'No voices to choose from right now. EarMind picks one.',
  voicePreview: 'Preview {name}',
  voicesNote: 'Previews are free. A new voice means new sound.',
  playFor: 'Play for {n} min',
  playForHour: 'Play for 1 hour',
  durationTitle: 'Play for',
  durationMin: '{n} min',
  durationHour: '1 hour',
  durationLabel: 'Duration, {n} minutes',
  cost: '{n} credits',
  costFree: 'Free. The sound already exists.',
  costShort: '{n} credits · you have {m}',
  costLabel: 'Costs {n} credits',
  tooLong: 'The text is too long: {n} of {m} characters.',
  making: 'Making the sound …',
  makingCount: 'Making the sound … {n} of {m}',
  playing: 'Playing in AirPods',
  left: '{t} left',
  leftPaused: '{t} left · paused',
  round: 'Round {n}',
  finished: 'Finished',
  play: 'Play',
  pause: 'Pause',
  resume: 'Resume',
  stop: 'Stop',
  nextSentence: 'Next sentence',
  previousSentence: 'Previous sentence',
  recent: 'Recent',
  recentPuts: '{text} · puts the text back',
  remove: 'Delete',
  pressesText: 'On your AirPods: 1 press pauses · 2 next sentence · 3 previous sentence',
  blocked: 'The browser stopped the sound. Tap Play once more.',

  // Quizzes
  nextQuiz: 'Next quiz',
  otherQuizzes: 'Other quizzes',
  newQuiz: 'New quiz',
  quizLine: 'Paste what you’re studying. EarMind makes the questions with top-grade answers and asks them in your AirPods.',
  quizText: 'Paste the text you’re studying',
  quizCount: 'Questions',
  quizCreate: 'Create questions',
  quizCreateN: 'Create {n} questions',
  quizReading: 'Reading your material …',
  quizCheckTitle: 'Is this right?',
  quizSubject: 'Subject',
  quizCovers: 'It covers',
  quizWrong: 'Something isn’t right',
  quizCorrection: 'What should be different?',
  quizRedo: 'Make them again',
  quizRight: 'Looks right',
  quizAnswering: 'Writing the answers …',
  quizFits: 'Your credits cover {n} questions.',
  quizNoneFit: 'Not enough credits for a quiz.',
  quizQuestions: '{n} questions',
  quizPerRound: 'about {n} min per round',
  quizStart: 'Start quiz',
  quizContinue: 'Continue',
  quizContinueAt: 'Continue · question {n}',
  quizNoMic: 'Plays in your AirPods. The microphone isn’t used.',
  quizCostAtStart: '{n} credits when you start. The sound is made then.',
  quizDelete: 'Delete quiz',
  quizDeleteAsk: 'Delete this quiz?',
  question: 'Question {n} of {m}',
  think: 'Think',
  longAnswer: 'Long answer',
  shortAnswer: 'Short answer',
  paused: 'Paused',
  end: 'End',
  pressesQuiz: 'On your AirPods: 1 press long answer · 2 short answer · 3 pause',

  // Credits (D249: no purchases on the web)
  credits: 'Credits',
  creditsBig: 'credits left',
  creditsMonthly: '{n} credits every month.',
  creditsHow: 'How it’s counted',
  creditsRow1: '1 character of new sound',
  creditsRow1v: '1 credit',
  creditsRow2: 'Sound that already exists',
  creditsRow3: 'Repeating the same text',
  creditsNew: 'New credits on {day}. Unused credits don’t carry over.',
  creditsBuy: 'Purchases come with the iOS app.',
  creditsUnknown: 'Credits couldn’t be loaded right now.',

  // Settings
  language: 'Language',
  english: 'English',
  swedish: 'Svenska',
  privacyTitle: 'What is sent',
  privacyLine: 'Texts you add are sent to EarMind’s server to make the questions and the sound. Start quiz never uses the microphone. Nothing is recorded.',
  startOver: 'Forget this browser',
  startOverLine: 'Removes the texts and quizzes kept in this browser.',
  startOverAsk: 'Remove everything kept in this browser?',
  about: 'EarMind beta · the iPhone app is on its way.',

  errorOffline: 'The sound couldn’t be loaded. Check your connection.',
  errorGeneric: 'Can’t play right now. Try again in a moment.',
};

export type Key = keyof typeof en;

const sv: Record<Key, string> = {
  beta: 'Beta',
  creditsLeft: '{n} krediter kvar',
  settings: 'Inställningar',
  done: 'Klar',
  cancel: 'Avbryt',
  tryAgain: 'Försök igen',

  screenTitle: 'Ha skärmen på',
  screenLine: 'I betan måste skärmen vara på medan det spelar eller lyssnar. Telefonen kan ligga upp till cirka 10 meter från dina AirPods, så du kan lägga ifrån dig den.',
  screenHow: 'Så håller du den på',
  screenKept: 'Skärmen hålls på medan det spelar.',
  screenNotKept: 'Den här webbläsaren kan inte hålla skärmen på själv. Sätt Automatisk låsning till Aldrig medan du lyssnar.',
  screenStopped: 'Det stannade för att skärmen släcktes. Spela igen?',
  guideIntro: 'Betan håller skärmen vaken medan det spelar. Släcks den ändå:',
  guideIphone: 'iPhone',
  guideIphoneSteps: 'Inställningar › Skärm och ljusstyrka › Automatisk låsning › Aldrig.',
  guideLowPower: 'Strömsparläget låser skärmen efter 30 sekunder ändå, så stäng av det medan du lyssnar.',
  guideAndroid: 'Android',
  guideAndroidSteps: 'Inställningar › Skärm › Tidsgräns för skärm.',
  guideAfter: 'Ändra tillbaka när du är klar.',

  sayLabel: 'Säg i AirPods',
  sayPrompt: 'Skriv eller klistra in det du vill höra',
  stylePrompt: 'Hur ska det låta?',
  styleSuggestions: 'Tydligt|Lugnt|Glatt|Viskande',
  voice: 'Röst',
  voiceLabel: 'Röst, {name}',
  voiceAuto: 'EarMind väljer',
  voicesNone: 'Det finns inga röster att välja just nu. EarMind väljer en.',
  voicePreview: 'Provlyssna {name}',
  voicesNote: 'Provlyssning kostar inget. En ny röst blir nytt ljud.',
  playFor: 'Spela i {n} min',
  playForHour: 'Spela i 1 timme',
  durationTitle: 'Spela i',
  durationMin: '{n} min',
  durationHour: '1 timme',
  durationLabel: 'Hur länge, {n} minuter',
  cost: '{n} krediter',
  costFree: 'Kostar inget. Ljudet finns redan.',
  costShort: '{n} krediter · du har {m}',
  costLabel: 'Kostar {n} krediter',
  tooLong: 'Texten är för lång: {n} av {m} tecken.',
  making: 'Gör ljudet …',
  makingCount: 'Gör ljudet … {n} av {m}',
  playing: 'Spelar i AirPods',
  left: '{t} kvar',
  leftPaused: '{t} kvar · pausad',
  round: 'Varv {n}',
  finished: 'Klart',
  play: 'Spela',
  pause: 'Pausa',
  resume: 'Fortsätt',
  stop: 'Stoppa',
  nextSentence: 'Nästa mening',
  previousSentence: 'Föregående mening',
  recent: 'Senaste',
  recentPuts: '{text} · lägger tillbaka texten',
  remove: 'Ta bort',
  pressesText: 'På dina AirPods: 1 tryck pausar · 2 nästa mening · 3 föregående mening',
  blocked: 'Webbläsaren stoppade ljudet. Tryck på Spela en gång till.',

  nextQuiz: 'Nästa prov',
  otherQuizzes: 'Andra prov',
  newQuiz: 'Nytt prov',
  quizLine: 'Klistra in det du pluggar på. EarMind gör frågorna med svar på högsta betyg och ställer dem i dina AirPods.',
  quizText: 'Klistra in texten du pluggar på',
  quizCount: 'Frågor',
  quizCreate: 'Skapa frågor',
  quizCreateN: 'Skapa {n} frågor',
  quizReading: 'Läser ditt material …',
  quizCheckTitle: 'Stämmer det här?',
  quizSubject: 'Ämne',
  quizCovers: 'Det handlar om',
  quizWrong: 'Något stämmer inte',
  quizCorrection: 'Vad ska vara annorlunda?',
  quizRedo: 'Gör om',
  quizRight: 'Ser rätt ut',
  quizAnswering: 'Skriver svar …',
  quizFits: 'Krediterna räcker till {n} frågor.',
  quizNoneFit: 'Krediterna räcker inte till ett prov.',
  quizQuestions: '{n} frågor',
  quizPerRound: 'cirka {n} min per varv',
  quizStart: 'Starta prov',
  quizContinue: 'Fortsätt',
  quizContinueAt: 'Fortsätt · fråga {n}',
  quizNoMic: 'Spelas i dina AirPods. Mikrofonen används inte.',
  quizCostAtStart: '{n} krediter när du startar. Ljudet görs då.',
  quizDelete: 'Ta bort provet',
  quizDeleteAsk: 'Ta bort det här provet?',
  question: 'Fråga {n} av {m}',
  think: 'Tänk',
  longAnswer: 'Långt svar',
  shortAnswer: 'Kort svar',
  paused: 'Pausad',
  end: 'Avsluta',
  pressesQuiz: 'På dina AirPods: 1 tryck långt svar · 2 kort svar · 3 paus',

  credits: 'Krediter',
  creditsBig: 'krediter kvar',
  creditsMonthly: '{n} krediter varje månad.',
  creditsHow: 'Så räknas det',
  creditsRow1: '1 tecken nytt ljud',
  creditsRow1v: '1 kredit',
  creditsRow2: 'Ljud som redan finns',
  creditsRow3: 'Upprepa samma text',
  creditsNew: 'Nya krediter den {day}. Oanvända krediter sparas inte.',
  creditsBuy: 'Köp kommer i iOS-appen.',
  creditsUnknown: 'Krediterna kunde inte hämtas just nu.',

  language: 'Språk',
  english: 'English',
  swedish: 'Svenska',
  privacyTitle: 'Vad som skickas',
  privacyLine: 'Texter du lägger in skickas till EarMinds server för att göra frågorna och ljudet. Starta prov använder aldrig mikrofonen. Inget spelas in.',
  startOver: 'Glöm den här webbläsaren',
  startOverLine: 'Tar bort texterna och proven som finns sparade i den här webbläsaren.',
  startOverAsk: 'Ta bort allt som är sparat i den här webbläsaren?',
  about: 'EarMind beta · appen för iPhone är på väg.',

  errorOffline: 'Ljudet kunde inte hämtas. Kolla nätet.',
  errorGeneric: 'Det gick inte att spela just nu. Försök igen om en stund.',
};

export const allTexts: Record<Lang, Record<Key, string>> = { en, sv };

export type Translate = (key: Key, vars?: Record<string, string | number>) => string;

export function translator(lang: Lang): Translate {
  const table = allTexts[lang];
  return (key, vars = {}) => table[key].replace(/\{([a-z]+)\}/g, (whole, name: string) => (name in vars ? String(vars[name]) : whole));
}

/// "1,236" in English, "1 236" in Swedish (a space that does not break the line).
export function grouped(n: number, lang: Lang): string {
  return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, lang === 'sv' ? ' ' : ',');
}

/// "December 1" / "1 december", from the server's day (YYYY-MM-DD…).
export function dayText(iso: string, lang: Lang): string | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso);
  if (m === null) return null;
  const months = {
    en: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
    sv: ['januari', 'februari', 'mars', 'april', 'maj', 'juni', 'juli', 'augusti', 'september', 'oktober', 'november', 'december'],
  }[lang];
  const month = months[Number(m[2]) - 1];
  if (month === undefined) return null;
  return lang === 'sv' ? `${Number(m[3])} ${month}` : `${month} ${Number(m[3])}`;
}

/// "7:32".
export function clockText(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}
