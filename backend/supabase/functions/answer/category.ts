/**
 * D49: anonymous usage insight. A request is put in ONE category from a fixed list; only the category
 * (never text) is stored on the usage row. Decided in code from mode / route / a few topic words.
 */
export const CATEGORIES = [
  "matte",
  "naturvetenskap",
  "historia",
  "språk",
  "samhälle",
  "praktiskt",
  "socialt/rizz",
  "intervju",
  "webbsökning",
  "övrigt",
] as const;
export type Category = (typeof CATEGORIES)[number];

const P = "(?<![\\p{L}\\p{N}])";
const S = "(?![\\p{L}\\p{N}])";
const pat = (alts: string) => new RegExp(`${P}(?:${alts})${S}`, "iu");

const TOPICS: [Category, RegExp][] = [
  [
    "matte",
    pat(
      "plus|minus|gånger|delat|procent|kvadrat\\p{L}*|rot(?:en)? ur|ekvation\\p{L}*|derivat\\p{L}*|integral\\p{L}*|geometri|bråk|triangel\\p{L}*|vinkel|vinklar|sannolikhet|matte|matematik\\p{L}*|\\d+\\s*[+\\-*/×÷]\\s*\\d+",
    ),
  ],
  [
    "naturvetenskap",
    pat(
      "fotosyntes\\p{L}*|cell(?:er|en|erna)?|atom\\p{L}*|molekyl\\p{L}*|fysik\\p{L}*|kemi\\p{L}*|biologi\\p{L}*|energi\\p{L}*|kraft(?:en)?|gen(?:er|en)?|evolution\\p{L}*|ljus\\p{L}*|vågor|planet\\p{L}*|syre|koldioxid|växthus\\p{L}*|mitokondri\\p{L}*|newton\\p{L}*|elektr\\p{L}*|atmosfär\\p{L}*|ekosystem\\p{L}*|klimat\\p{L}*",
    ),
  ],
  [
    "historia",
    pat(
      "krig(?:et)?|världskriget|revolution\\p{L}*|kung(?:en)?|kejsare|historia|historisk\\p{L}*|århundrade\\p{L}*|-?talet|medeltid\\p{L}*|vikingar\\p{L}*|napoleon|berlinmuren|imperium|rike(?:t)?",
    ),
  ],
  [
    "språk",
    pat(
      "betyder|översätt\\p{L}*|till (?:engelska|svenska|tyska|franska|spanska)|grammatik|stava\\p{L}*|synonym\\p{L}*|adverb|verb|substantiv|adjektiv|uttal\\p{L}*|slang|ordet",
    ),
  ],
  [
    "samhälle",
    pat(
      "riksdag\\p{L}*|regering\\p{L}*|lag(?:en|ar)?|val(?:et)?|ekonomi\\p{L}*|skatt\\p{L}*|politik\\p{L}*|demokrati\\p{L}*|rättighet\\p{L}*|kommun\\p{L}*|eu|fn|grundlag\\p{L}*|inflation\\p{L}*|sociologi\\p{L}*",
    ),
  ],
  [
    "praktiskt",
    pat(
      "recept|laga|packa|plan(?:era)?|hur gör (?:man|jag)|steg för steg|bank\\p{L}*|bankkort|plånbok\\p{L}*|reklamation\\p{L}*|garanti\\p{L}*|resa|boka|tvätta|städa|hungrig|mat",
    ),
  ],
];

export interface CategoryInput {
  mode: string;
  persona: string;
  fragment: string;
  planKind: string | null; // interview | prep | rizz | social | socialline | calibrate | null
  web: boolean;
  computed: boolean;
}

export function categorize(i: CategoryInput): Category {
  if (i.mode === "interview_prep" || i.planKind === "interview" || i.planKind === "prep") {
    return "intervju";
  }
  if (i.planKind === "rizz" || i.planKind === "social" || i.planKind === "socialline" ||
    i.planKind === "calibrate") {
    return "socialt/rizz";
  }
  if (i.web) return "webbsökning";
  if (i.computed) return "matte";
  for (const [c, re] of TOPICS) if (re.test(i.fragment)) return c;
  return "övrigt";
}
