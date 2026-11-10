/**
 * K21 (BLOCKER, safety; Deangelo's test 2026-11-10: "Jag mår skit och orkar inte leva." in Auto was silence, because
 * the model called it "not a question"): words about suicide, self-harm or not wanting to live ALWAYS get a short,
 * warm answer that takes it seriously and shows a way to help, in every mode and whatever `is_question` would say.
 *
 * Two layers (Oscar O17: the first version caught 16/30 of his cases and gave 12/30 false alarms):
 *  1. a STRONG hit in code (clear words, with filler words, spoken forms and common mishearings) = the answer at once;
 *  2. a WEAK hit (first person plus a word about living, dying, waking up or hurting oneself, or a strong pattern
 *     that an everyday reading excludes, "jag vill inte leva i Stockholm") = a one-word yes/no check by a small model
 *     before anything else; when that check fails, the answer is given (never silence by default).
 *
 * Numbers checked against the sources 2026-11-10: 112 (emergency), Mind's Självmordslinjen 90101 (mind.se, 1177.se,
 * ki.se), Bris 116 111 for children and young people under 18 (bris.se: "Du som är under 18 år …", open every day
 * and night). Opening hours of Självmordslinjen differ between sources, so none are said.
 */

const W = (s: string) => `(?<![\\p{L}])(?:${s})(?![\\p{L}])`;
const RE = (alts: string[]) => new RegExp(alts.map(W).join("|"), "iu");
const RE_G = (alts: string[]) => new RegExp(alts.map(W).join("|"), "giu");

/** Filler words teenagers put in the middle ("jag vill typ inte leva", "orkar inte ens leva"). */
const F = String.raw`(?:(?:typ|ens|liksom|asså|alltså|bara|fan|jävla|helt|seriöst|ärligt talat|nog|nästan|egentligen|längre) )*`;
/** I, also spoken and misheard ("ja", "jaa"). */
const I = String.raw`(?:jag|ja|jaa|jg)`;
/** to live, also misheard ("läva", "lefva"). */
const LIVE = String.raw`(?:leva|läva|lefva|leeva)`;
const CAN = String.raw`(?:orkar|orka|orkade|vill|ville|klarar|klara|pallar|palla|kan|kunde)`;

/** Clear signs: the speaker does not want to live, wants to die, plans to hurt or kill themself. */
const STRONG = [
  // not wanting to live / to exist, straight and inverted word order, with fillers
  String.raw`${CAN} (?:${I} )?${F}inte ${F}(?:att )?${LIVE}`,
  String.raw`inte ${F}${CAN} ${F}(?:att )?${LIVE}`,
  String.raw`${CAN} (?:${I} )?inte ${F}(?:finnas|finnas kvar|vara kvar)`,
  String.raw`(?:orkar|orka|pallar|palla) inte (?:mer|längre) med (?:livet|att leva|allt|mig själv)`,
  String.raw`(?:vill|ville|skulle vilja|vell) (?:${I} )?${F}(?:dö|vara död|inte vakna|sluta finnas|inte finnas|försvinna för alltid)`,
  String.raw`(?:aldrig|slippa) (?:mer )?vakna(?: igen| mer)?`,
  String.raw`(?:sova|somna) och (?:aldrig|inte) vakna`,
  String.raw`ingen (?:skulle|kommer att|hade) (?:sakna|märka|bry sig om|bry sig) (?:mig|att jag) (?:om jag|när jag) (?:dog|dör|försvann|försvinner|inte fanns|var borta|var död)`,
  String.raw`(?:det vore|det hade varit|allt vore|alla vore|alla skulle ha det|alla skulle må|alla hade haft det) bättre (?:om jag (?:var|vore) (?:död|borta)|om jag inte fanns|utan mig)`,
  String.raw`bättre om jag (?:var död|vore död|var borta|vore borta|dog|inte fanns)`,
  String.raw`ingen (?:mening|idé) (?:med att|att) (?:${LIVE}|finnas)`,
  String.raw`livet är inte värt att ${LIVE}`,
  String.raw`(?:så |helt |jätte)?trött på att ${LIVE}`,
  // suicide, plans
  String.raw`${I} (?:ska|vill|tänker|kommer att|funderar på att|har tänkt|har tänkt på att|planerar att|tänkt|har funderat på att|ville) ${F}(?:ta livet av mig|ta mitt (?:eget )?liv|döda mig själv|avsluta mitt liv|göra slut på mig själv|göra slut på mitt liv|göra slut på allt|hoppa (?:från|framför) \p{L}+)`,
  String.raw`(?:vill|ska|tänker) (?:${I} )?(?:ta livet av mig|göra slut på allt|göra slut på mig själv|avsluta allt)`,
  String.raw`ta livet av mig själv`,
  String.raw`(?:har|får|går runt med|får ofta) självmordstankar`,
  String.raw`(?:tänker|funderar|tänkt|har tänkt) (?:ofta |mycket )?på (?:att ta )?självmord`,
  String.raw`självmord (?:känns|verkar|är) (?:som )?(?:den )?(?:enda|bästa|en) (?:utvägen|utväg|lösningen|lösning)`,
  String.raw`(?:${I} )?(?:vill|ska|tänker) begå självmord`,
  // self-harm, every tense
  String.raw`(?:${I} )?(?:skadar|skadade|skadat|har skadat|brukar skada|vill skada|ska skada|börjat skada|skada) mig själv`,
  String.raw`(?:skär|skar|skurit|har skurit|skära) mig (?:igen|ofta|varje (?:dag|kväll|natt)|när jag mår|i armen|i armarna|på armen|på armarna|i benen)`,
  String.raw`(?:har börjat|brukar|har|vill|ska|måste) (?:skära|skurit|skär) mig(?! (?:en|ett|på papper|i fingret|i tummen|när jag rakar|med kniven när))`,
  String.raw`självskadar|självskada mig|självskadat`,
  // English and slang
  String.raw`kill myself|want to die|wanna die|end my life|suicidal|kms|unalive myself|don'?t want to live|wanna kms`,
];

/** The everyday reading of a strong pattern: then it is only a weak hit (the yes/no check decides). */
const EXCEPT = [
  String.raw`inte ${F}(?:att )?${LIVE} (?:i|på|som|med att|utan|så här i|i en|där|här|hos|ihop med|nära)`,
  String.raw`(?:kan|klarar|orkar) inte ${LIVE} (?:utan|med att)`,
  String.raw`(?:vill|skulle vilja) (?:${I} )?dö (?:i|på|när jag (?:är|blir) gammal|som gammal|av ålder|i sömnen när)`,
  String.raw`dö av (?:skratt|skam|tristess|längtan|nyfikenhet|värme|tråkighet)`,
  String.raw`(?:heter|låten|boken|filmen|serien|dikten) (?:heter )?\p{L}* ?jag vill dö`,
  String.raw`kms (?:lol|haha|xd|asså det var)`,
  String.raw`(?:min |mitt |den |det )?(?:telefon|mobil|dator|laptop|bil|batteri|cykel|växt|blomma|router|skrivare|tv|surfplatta|ipad|iphone)\p{L}* (?:vill|orkar|klarar) inte (?:leva|leva längre|leva mer)`,
  String.raw`(?:om|hos|bland|kring|angående) (?:\p{L}+ )?självmordstankar`,
  // everyday idioms that carry no risk at all (removed before the risk words are counted)
  String.raw`(?:dör|dog|döden|kommer dö|kommer att dö) (?:om jag inte får|av \p{L}+|i spelet|i minecraft|i fortnite)`,
  String.raw`döda (?:den här |den |en )?(?:bossen|boss|zombien|draken|fienden|monstret)`,
  String.raw`(?:vill|ska) (?:bara )?försvinna under täcket`,
  String.raw`(?:vill|ville) dö av \p{L}+`,
  String.raw`leva med att (?:ha fel|förlora|vara)`,
  String.raw`(?:låten|boken|filmen|serien|dikten|spelet) (?:heter|hette) [\p{L} ]+`,
  String.raw`vill du dö`,
];

/** Words that may be about the speaker's life or harm: first person plus one of these = ask the small model. */
const RISK = /(?<![\p{L}])(?:leva|läva|lever|livet|liv|dö|död|döda|dog|dör|vakna|försvinna|försvann|sakna mig|självmord\p{L}*|självskad\p{L}*|skada mig|skadar mig|skär mig|skar mig|skurit mig|ta slut|göra slut|hoppa framför|kms|kill myself|die|dying)(?![\p{L}])/iu;
const FIRST = /(?<![\p{L}])(?:jag|ja|mig|mitt|min|jg|i|me|my)(?![\p{L}])/iu;

const STRONG_RE = RE(STRONG);
const EXCEPT_G = RE_G(EXCEPT);

export type CrisisLevel = "strong" | "weak" | null;

export function crisisLevel(text: string): CrisisLevel {
  const t = (text ?? "").toLowerCase().replace(/[,.!?;:]+/g, " ").replace(/\s+/g, " ").trim();
  if (!t) return null;
  // an everyday reading is removed first: strong only if a clear sign is left; weak if risk words are left
  const rest = t.replace(EXCEPT_G, " ");
  if (STRONG_RE.test(rest)) return "strong";
  if (FIRST.test(rest) && RISK.test(rest)) return "weak";
  // a strong pattern that only an everyday reading explains: the check decides (never silence by itself)
  return STRONG_RE.test(t) ? "weak" : null;
}

/** "min kompis säger att han inte vill leva": about someone else, so the user gets the line on how to help. */
const ABOUT_OTHER = /(?<![\p{L}])(?:min (?:kompis|vän|bästis|bror|syster|polare|tjej|kille|flickvän|pojkvän|klasskompis)|mitt ex|han|hon|hen|dom|de)(?: \p{L}+){0,2} (?:säger|sa|sade|skrev|skriver|har sagt|berättade|tycker|messade|sms:ade) att/iu;
export function aboutOther(text: string): boolean {
  return ABOUT_OTHER.test(text ?? "");
}

/** Strong hits only (the code layer; kept for the offline tests). */
export function isCrisis(text: string): boolean {
  return crisisLevel(text) === "strong";
}

/** The yes/no check for a weak hit (small model, a few tokens). */
export const CRISIS_CHECK_PROMPT =
  `You check ONE utterance that a young person (13-19) said, picked up by a microphone. Does the SPEAKER express thoughts of suicide, of not wanting to live, of wanting to die or disappear for good, or of hurting themself, now or recently? Answer "ja" for any such sign, also when it is said casually, with slang, in passing or half as a joke. Answer "nej" for everyday figures of speech and exaggerations ("dör av skratt", "jag dör om jag inte får mat", "provet tar livet av mig", "jag vill dö av skam", "jag kan inte leva med att ha fel", "jag vill bara försvinna under täcket idag"), wishes about where or how to live, dying old one day, games, cutting food or shaving, titles of books and songs, school work and other people's stories in the news or history. Answer "ja" when the words could mean that the speaker does not want to live or wants to hurt themself and nothing in the sentence makes it an everyday expression. Reply with one word: ja or nej.`;

export function crisisVerdict(reply: string): boolean {
  return !/^\s*nej\b/iu.test(reply);
}

/** To the person who said it. Spoken: numbers as words. */
export const CRISIS_SELF =
  "Det du säger låter riktigt tungt, och det är bra att du säger det. Du behöver inte vara ensam med det här. Är du i fara just nu, ring ett ett två. Annars kan du ringa Självmordslinjen på nittio ett noll ett, eller prata med en vuxen du litar på, till exempel skolkuratorn. Är du under arton kan du ringa Bris på ett ett sex ett ett ett, dygnet runt.";
/** When someone else said it (Socialt, Rizz, Intervju): to the user, about the other person. */
export const CRISIS_OTHER =
  "Det personen säger är allvarligt, ta det på allvar. Fråga lugnt hur hen mår och lyssna, utan att döma. Är någon i fara just nu, ring ett ett två. Självmordslinjen nås på nittio ett noll ett, och den som är under arton kan ringa Bris på ett ett sex ett ett ett.";
