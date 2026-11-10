/**
 * K21 (BLOCKER, safety; Deangelo's test 2026-11-10: "Jag mår skit och orkar inte leva." in Auto was silence, because
 * the model called it "not a question"): words about suicide, self-harm or not wanting to live ALWAYS get a short,
 * warm answer that takes it seriously and shows a way to help, in every mode and whatever `is_question` would say.
 * Decided in code before the model (like the phone and allergy filters), never by the model's judgement.
 *
 * Numbers checked against the sources 2026-11-10: 112 (emergency), Mind's Självmordslinjen 90101 (mind.se, 1177.se,
 * ki.se), Bris 116 111 for children and young people under 18 (bris.se: "Du som är under 18 år …", open every day
 * and night). Opening hours of Självmordslinjen differ between sources, so none are said.
 */

const W = (s: string) => `(?<![\\p{L}])(?:${s})(?![\\p{L}])`;
const RE = (alts: string[]) => new RegExp(alts.map(W).join("|"), "iu");

/** Clear signs: the speaker does not want to live, wants to die, plans to hurt or kill themself. */
const CRISIS = RE([
  // not wanting to live / to exist
  // straight and inverted word order: "jag orkar inte leva", "orkar jag inte leva", "att jag inte orkar leva"
  String.raw`(?:orkar|vill|klarar|pallar|kan) (?:jag |ja )?inte (?:att )?(?:leva|leva längre|leva mer|finnas|finnas längre|finnas kvar|vara kvar)(?! utan)`,
  String.raw`inte (?:orkar|vill|klarar|pallar) (?:att )?(?:leva|leva längre|leva mer|finnas|finnas längre|finnas kvar|vara kvar)(?! utan)`,
  String.raw`(?:orkar|pallar) inte (?:mer|längre) med (?:livet|att leva|allt|mig själv)`,
  String.raw`(?:vill|ville|skulle vilja) (?:jag |ja )?(?:bara )?(?:dö|vara död|inte vakna|sluta finnas|inte finnas|försvinna för alltid)(?! av)`,
  String.raw`(?:det vore|det hade varit|allt vore|alla vore|alla skulle ha det|alla skulle må) bättre (?:om jag (?:var|vore) död|utan mig)`,
  String.raw`bättre om jag (?:var|vore|dog|inte fanns)`,
  String.raw`ingen (?:mening|idé) (?:med att|att) (?:leva|finnas)`,
  String.raw`livet är inte värt att leva`,
  String.raw`(?:jag )?(?:hatar|är trött på) (?:livet|att leva) så (?:mycket )?att jag vill dö`,
  // suicide, plans
  String.raw`(?:jag|ja) (?:ska|vill|tänker|kommer att|funderar på att|har tänkt|planerar att|tänkt) (?:ta livet av mig|ta mitt (?:eget )?liv|döda mig själv|avsluta mitt liv|göra slut på mig själv|göra slut på mitt liv|hoppa (?:från|framför) \p{L}+)`,
  String.raw`ta livet av mig själv`,
  String.raw`(?:har|får|går runt med) självmordstankar`,
  String.raw`självmordstankar`,
  String.raw`(?:tänker|funderar|tänkt) på (?:att ta )?självmord`,
  String.raw`(?:jag )?(?:vill|ska|tänker) begå självmord`,
  // self-harm
  String.raw`(?:jag )?(?:har börjat |brukar |vill |måste )?(?:skada|skär|skära|bränna) mig själv`,
  String.raw`(?:jag )?(?:har börjat|brukar|vill|ska) skära mig`,
  String.raw`självskadar|självskada mig`,
  // English and slang
  String.raw`kill myself|want to die|wanna die|end my life|suicidal|kms|unalive myself|don't want to live|dont want to live`,
]);

/** The words say it, but as an everyday figure of speech: never an alarm on these alone. */
const FIGURE = RE([
  String.raw`dör av (?:skratt|skam|tristess|längtan|nyfikenhet)`,
  String.raw`(?:vill|kan) dö av (?:skratt|skam|tristess)`,
  String.raw`(?:kan|klarar|orkar) inte leva utan`,
  // a thing, not a person: "min telefon vill inte leva längre"
  String.raw`(?:min |mitt |den |det )?(?:telefon|mobil|dator|laptop|bil|batteri|cykel|växt|blomma|router|skrivare|tv|surfplatta|ipad|iphone)\p{L}* (?:vill|orkar|klarar) inte (?:leva|leva längre|leva mer)`,
]);

export function isCrisis(text: string): boolean {
  const t = (text ?? "").replace(/\s+/g, " ").trim();
  if (!t || !CRISIS.test(t)) return false;
  // a figure of speech counts only when no clear sign is left once it is removed
  return CRISIS.test(t.replace(new RegExp(FIGURE.source, "giu"), " "));
}

/** To the person who said it. Spoken: numbers as words. */
export const CRISIS_SELF =
  "Det du säger låter riktigt tungt, och det är bra att du säger det. Du behöver inte vara ensam med det här. Är du i fara just nu, ring ett ett två. Annars kan du ringa Självmordslinjen på nittio ett noll ett, eller prata med en vuxen du litar på, till exempel skolkuratorn. Är du under arton kan du ringa Bris på ett ett sex ett ett ett, dygnet runt.";
/** When someone else said it (Socialt, Rizz, Intervju): to the user, about the other person. */
export const CRISIS_OTHER =
  "Det personen säger är allvarligt, ta det på allvar. Fråga lugnt hur hen mår och lyssna, utan att döma. Är någon i fara just nu, ring ett ett två. Självmordslinjen nås på nittio ett noll ett, och den som är under arton kan ringa Bris på ett ett sex ett ett ett.";
