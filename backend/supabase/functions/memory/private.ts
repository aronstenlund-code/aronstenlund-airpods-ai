/**
 * D274 (Deangelo, within D113; Oscar O107 M-2/M-3). Checked in code after the model, not only in the prompt:
 * 1. Contact details are never kept: phone numbers, e-mail addresses and street addresses (sv and en). A city alone
 *    ("Bor i Uppsala") is not a contact detail.
 * 2. About other people only name and relation are kept ("Brodern heter Elias"). A memory whose subject is a family
 *    member or friend must have exactly that shape; anywhere else, a relation word followed by a private
 *    circumstance (work, money, relationships, the law, faith, politics, where they live) stops the memory. Their
 *    health is already stopped by the health list (D113 B5).
 * No other memory stops are added here (D274).
 */

const CONTACT_WORDS =
  /mobilnummer\p{L}*|mobilnr|telefonnummer\p{L}*|telefonnr|phone number|mobile number|cell number|e-?postadress\p{L}*|mejladress\p{L}*|mailadress\p{L}*|e-?mail address|hemadress\p{L}*|gatuadress\p{L}*|postadress\p{L}*|(?<![\p{L}])adress(?:en)?\s*:|home address|street address|postnummer|zip code|postcode|postal code/iu;

const EMAIL = /[\p{L}\d._%+-]+@[\p{L}\d-]+(?:\.[\p{L}\d-]+)+/u;

const PHONE = [
  /\+\d{1,3}[\s-]?\(?\d{1,4}\)?(?:[\s-]?\d){5,10}(?!\d)/, // +46 70 123 45 67, +1 555 123 4567
  /(?<![\d\p{L}.,:])0\d{1,3}[\s-]?\d(?:[\s-]?\d){4,8}(?![\d.,:])/u, // 070-123 45 67, 08-123 456 78, 0701234567
  /\(\d{2,4}\)[\s-]?\d{3}[\s-]?\d{4}(?!\d)/, // (555) 123-4567
  /(?<![\d.,:])\d{3}[\s.-]\d{3}[\s.-]\d{4}(?![\d.,:])/, // 555-123-4567
];

const STREET_SV =
  /\p{L}*(?:gatan|vägen|gränd|gränden|torget|stigen|allén|backen|leden|platsen|esplanaden|promenaden|liden|slingan|stråket|kroken|gata)\s+\d{1,4}\s?[a-zA-Z]?(?![\d\p{L}])/iu;
const LIVES_AT = /(?<![\p{L}])(?:bor|bostad|lives?|living)\s+(?:på|vid|at|on)\s+(?:\p{L}+\s+){1,3}\d{1,4}\s?[a-zA-Z]?(?![\d\p{L}])/iu;
const STREET_EN =
  /(?<![\d\p{L}])\d{1,5}[a-zA-Z]?\s+(?:\p{L}+\s+){1,3}(?:street|road|rd\.|avenue|ave\.|lane|drive|way|court|boulevard|place|close|crescent)(?![\p{L}])/iu;
const POSTCODE_CITY = /(?<![\d.,:])\d{3}\s?\d{2}\s+\p{Lu}\p{Ll}+/u;

export function isContactDetail(t: string): boolean {
  return CONTACT_WORDS.test(t) || EMAIL.test(t) || PHONE.some((r) => r.test(t)) || STREET_SV.test(t) || LIVES_AT.test(t) ||
    STREET_EN.test(t) || POSTCODE_CITY.test(t);
}

/** Family, friends, partners: a memory about them keeps only name and relation. */
const CLOSE =
  "mamma|mamman|morsan|modern|pappa|pappan|farsan|fadern|förälder|föräldern|föräldrar|föräldrarna|bror|brodern|brorsan|lillebror|lillebrorsan|storebror|storebrorsan|syster|systern|syrran|lillasyster|lillasystern|storasyster|storasystern|syskon|syskonen|mormor|morfar|farmor|farfar|kusin|kusinen|kusiner|kusinerna|moster|mostern|faster|fastern|morbror|farbror|styvpappa|styvpappan|styvmamma|styvmamman|bonuspappa|bonuspappan|bonusmamma|bonusmamman|kompis|kompisen|kompisar|kompisarna|bästis|bästisen|vän|vännen|vänner|vännerna|väninna|väninnan|kamrat|kamraten|klasskompis|klasskompisen|flickvän|flickvännen|pojkvän|pojkvännen|partner|partnern|sambo|sambon|granne|grannen|mother|mom|mum|father|dad|brother|sister|parent|parents|friend|friends|cousin|aunt|uncle|grandma|grandpa|grandmother|grandfather|boyfriend|girlfriend|neighbor|neighbour";
/** Other people the wearer names; only the private-circumstance check applies to them. */
const OTHER = "lärare|läraren|lärarna|mentor|mentorn|tränare|tränaren|chef|chefen|kollega|kollegan|teacher|coach|boss";

const CLOSE_SET = new Set(CLOSE.split("|"));
const REL_SET = new Set([...CLOSE_SET, ...OTHER.split("|")]);
const LEAD = new Set(
  "min mitt mina hans hennes deras sin sitt sina en ett bästa äldre yngre lilla stora gamla nya his her their my the a an best older younger little big".split(" "),
);
const NAME = "\\p{Lu}[\\p{L}'-]*";
/** "Brodern heter Elias", "Bästa kompisen heter Sara Lind", "His sister is called Maja". */
const NAME_ONLY = new RegExp(
  `^(?:(?:${[...LEAD].join("|")})\\s+)*(?:${CLOSE})\\s+(?:heter|is called|is named|'s name is)\\s+${NAME}(?:\\s+${NAME}){0,2}\\s*\\.?$`,
  "iu",
);

const PRIVATE_CUE =
  /(?<![\p{L}])(?:arbetslös\p{L}*|jobb\p{L}*|arbetar|arbete\p{L}*|anställd|lön\p{L}*|tjänar|skuld\p{L}*|lån(?:et|ar|ade)?|pengar|ekonomi\p{L}*|konkurs|fattig\p{L}*|rik|bidrag|a-kassa|socialtjänst\p{L}*|socialen|sparken|uppsagd|avskedad|pension\p{L}*|skild\p{L}*|skilsmäss\p{L}*|separer\p{L}*|gift|förlovad|ihop med|tillsammans med|flickvän\p{L}*|pojkvän\p{L}*|dejtar|kär i|otrogen|gjort slut|gjorde slut|bråk\p{L}*|fängelse\p{L}*|polis\p{L}*|dömd|åtal\p{L}*|brott\p{L}*|missbruk\p{L}*|dricker|alkohol\p{L}*|drog\p{L}*|knark\p{L}*|religio\p{L}*|muslim|kristen|jude|judisk|troende|röstar|parti\p{L}*|politi\p{L}*|flykting|asyl|uppehållstillstånd|bor (?:i|på|hos|med|vid)|flyttat|adress\p{L}*|sexuell\p{L}*|homosexuell|gay|lesbisk|unemployed|job|jobs|works|worked|salary|money|debt\p{L}*|divorc\p{L}*|married|dating|in love|prison|jail|police|arrested|votes|voted|lives in|lives at|lost (?:his|her|their) job|fired)(?![\p{L}])/iu;

function sentences(t: string): string[] {
  return t.split(/[.!?;](?:\s|$)/u).map((s) => s.trim()).filter(Boolean);
}

export function isPrivateAboutOthers(t: string): boolean {
  for (const s of sentences(t)) {
    const tokens = s.toLowerCase().split(/[^\p{L}\d'-]+/u).filter(Boolean);
    let i = 0;
    while (i < tokens.length && LEAD.has(tokens[i])) i++;
    if (i < tokens.length && CLOSE_SET.has(tokens[i]) && !NAME_ONLY.test(s)) return true;
    for (let k = 0; k < tokens.length; k++) {
      if (REL_SET.has(tokens[k]) && PRIVATE_CUE.test(tokens.slice(k + 1, k + 9).join(" "))) return true;
    }
  }
  return false;
}
