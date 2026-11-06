/**
 * D57: the spoken report command ("rapportera", "det där var fel", "skicka till utvecklarna") is recognised
 * in code, never sent to the model. /answer then returns `done.report = true` without any spoken answer so
 * the app can send the previous turn to POST /feedback and play its own short confirmation.
 */
const norm = (s: string) =>
  s.toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, " ").replace(/\s+/g, " ").trim();

const THIS = "(?:det|det där|det här|detta|svaret|svar|den här|den där)";
const PATTERNS: RegExp[] = [
  new RegExp(`^rapportera(?: ${THIS})?$`),
  new RegExp(`^(?:felanmäl|anmäl)(?: ${THIS})?$`),
  new RegExp(
    `^${THIS} (?:var|blev|är) (?:helt |ganska |så |ju )?(?:fel|dåligt|konstigt|felaktigt|inte bra|inte rätt)$`,
  ),
  new RegExp(`^skicka(?: ${THIS})? till utvecklarna$`),
  new RegExp(`^skicka (?:feedback|en rapport|rapport)$`),
  /^report(?: this| that| it)?$/,
  /^that was (?:wrong|bad|not right)$/,
  /^send (?:this |that |it )?to (?:the )?developers$/,
];

export function detectReport(fragment: string): boolean {
  const f = norm(fragment);
  if (!f || f.length > 60) return false;
  return PATTERNS.some((p) => p.test(f));
}
