"""A157 (D251): sorts every string literal in the app: what language it is in and how it reaches the user."""
from __future__ import annotations
import re, json, sys, os, collections
sys.path.insert(0, os.path.dirname(__file__))
import swiftlit

SV = set("""och att det som en är på för med av till den inte har de om ett kan jag du vi ni han hon men så eller när
var från ska här där nu bara också mer mycket alla allt ingen inget inga vad hur varför vilken vilka din ditt dina
min mitt mina sin sitt sina igen sedan efter innan under över utan mellan bli blir blev gör göra gjort får få finns
fanns kommer kom gick går gå säg säger sagt läs läser skriv skriver spela spelar stoppa pausa starta börja fortsätt
klar avbryt tillbaka nästa förra stäng öppna välj visa dölj lägg ta bort spara ändra byt försök prova fråga frågor
svar svaret svaren prov provet text texten röst rösten ljud ljudet krediter kredit vecka veckan dag dagar timme
timmar minut minuter sekund sekunder kvar räcker kostar kostnad fyll köp köpet konto lyssna lyssnar hör hörs
telefonen mikrofonen inställningar språk svenska engelska rätt fel bra nytt ny nya gamla kort lång långa lite
tyst högt lugnt snabbt långsamt alltid aldrig ibland kanske ja nej tack hej okej något någon några varje annan
andra samma själv redan ännu snart senare idag imorgon igår nyss just vill behöver måste borde kunde skulle
ordet ord mening rad rader sida sidor bild bilder fil filer länk namn kod steg läge lägen av på till din
avbrutet avsluta dokument enklare foto foton klart kortare meningar skola skrivet skymd sparade stycke stycken syns
upprepa viska pausad tryck gånger gång varv kvar vald tillagt publicerat senare tidigare kommande ämne
cirka ungefär högst minst först sist hela halva per utan med mot hos vid
bjud klistra redo standard""".split())
EN = set("""the and that this with for from you your are was were will would can could should have has had not but
what when where why how which who all any some more most other into over under after before between out off on in
of to is it as at by be or if no yes do does did done make made get got set use used show hide open close start
stop pause play next back done cancel save delete remove add edit change try again ask question questions answer
answers text voice sound credits credit week day days hour hours minute minutes second seconds left costs cost
buy purchase account listen listening phone microphone settings language right wrong good new old short long
always never sometimes maybe thanks hello okay something someone each same already soon later today need must
word words line lines page pages file files link name code step mode failed error missing found unknown""".split())

WORD = re.compile(r"[A-Za-zÅÄÖåäöÉéÜü]+")
IDENT = re.compile(r"^[A-Za-z0-9_.\-:/%@#+*]*$")


def language(text: str, interpolated: bool = False) -> str:
    """'sv', 'en', 'none' (no words: symbols, identifiers, formats) or 'unknown' (words in neither list).
    A literal with a value in it ("\\(n) foton") is a text, never an identifier."""
    t = text.strip()
    words = [w.lower() for w in WORD.findall(t)]
    if not words:
        return "none"
    if re.search(r"[åäöÅÄÖ]", t):
        return "sv"
    # An identifier, a key, a file name or a format ("repetition.progress", "too_long", "yyyy-MM-dd", "cloud"), but
    # not a word with a colon or a full stop after it ("Saknas:", "Klart.").
    if not interpolated and " " not in t and IDENT.match(t) and (
            re.search(r"\w[._:/\-]\w|[a-z][A-Z]|\d|[%@#*+_]", t)
            or t.islower() and len(words) == 1 and t not in SV and t not in EN and t.isalpha()):
        return "none"
    sv = sum(w in SV for w in words)
    en = sum(w in EN for w in words)
    if sv > en:
        return "sv"
    if en > sv:
        return "en"
    return "unknown"


# The SwiftUI and system calls whose first string literal is looked up in the catalog by itself.
LSK = re.compile(r"""(?x)
    (?:\b(?:Text|Button|Label|Toggle|Picker|TextField|SecureField|Section|Menu|Link|NavigationLink|LabeledContent|
          ProgressView|DisclosureGroup|ContentUnavailableView|Tab|Stepper|Slider|DatePicker|ShareLink|Gauge|GroupBox|
          ControlWidgetButton|ControlWidgetToggle|EditButton|TextEditor|ColorPicker|PasteButton|RenameButton|
          LocalizedStringKey|LocalizedStringResource|IntentDescription|TypeDisplayRepresentation|DisplayRepresentation|
          AppShortcut|IntentDialog)\s*\(\s*(?:title\s*:\s*|name\s*:\s*|stringLiteral\s*:\s*)?$)
  | (?:\.(?:navigationTitle|navigationSubtitle|accessibilityLabel|accessibilityHint|accessibilityValue|alert|
          confirmationDialog|help|badge|tabItem|searchable|accessibilityAction|accessibilityCustomContent|
          accessibilityInputLabels|configurationDisplayName|description|displayName|presentationDetents|
          navigationBarTitle|toolbarTitleMenu|fileExporter|accessibilityRotor|contextMenu|swipeActions|
          accessibilityRepresentation|dialogSuggestedAction)\s*\(\s*(?:named\s*:\s*)?$)
  | (?:\b(?:prompt|description|message|title|subtitle|label|text|placeholder)\s*:\s*Text\s*\(\s*$)
  | (?::\s*(?:LocalizedStringKey|LocalizedStringResource|Text)\s*=\s*$)
  | (?:\bString\s*\(\s*localized\s*:\s*$)
  | (?:\bshortTitle\s*:\s*$)
  | (?:@Parameter\s*\([^)]*\b(?:title|description)\s*:\s*$)
  | (?:\bphrases\s*:\s*\[[^\]]*$)
""")
LOG = re.compile(r"\b(?:Log\.\w+|logger|Logger|log|os_log|print|debugPrint|assert|assertionFailure|precondition|preconditionFailure|fatalError|NSLog)\b[^\"]*$")
VERBATIM = re.compile(r"\bText\s*\(\s*verbatim\s*:\s*$")
NONTEXT = re.compile(r"""(?x)
    (?:\b(?:systemImage|systemName|named|forKey|key|identifier|id|kind|withIdentifier|forResource|ofType|withExtension|
          suiteName|domain|category|subsystem|forHTTPHeaderField|httpMethod|format|dateFormat|locale|localeIdentifier|
          regex|pattern|path|appendingPathComponent|appending|scheme|host|name\s*:\s*Notification|rawValue|
          accessibilityIdentifier|image|sound|font|forInfoDictionaryKey|contentType|mimeType|language|voice|
          string\s*:\s*"https)\s*:\s*$)
  | (?:\.accessibilityIdentifier\s*\(\s*$)
  | (?:\bImage\s*\(\s*(?:systemName\s*:\s*)?$)
  | (?:\bcase\s+\w+\s*=\s*$)
  | (?:\b(?:URL|NSPredicate|NSRegularExpression|Regex|Notification\.Name|UIImage|Color|DateFormatter|Locale)\s*\(\s*(?:string\s*:\s*|\w+\s*:\s*)?$)
  | (?:@AppStorage\s*\(\s*$)
  | (?:\bimport\b)
""")


def context(lit: swiftlit.Literal) -> str:
    b = lit.before
    if VERBATIM.search(b):
        return "verbatim"
    if LSK.search(b):
        return "key"
    if LOG.search(b):
        return "log"
    if NONTEXT.search(b):
        return "nontext"
    return "plain"


def rows(roots=("Lumen", "LumenControls", "Shared")):
    for f in swiftlit.swift_files(*roots):
        for l in swiftlit.literals(f):
            yield l, language(l.plain, l.interpolated), context(l)


if __name__ == "__main__":
    out, c = [], collections.Counter()
    area = collections.defaultdict(collections.Counter)
    for l, lang, ctx in rows():
        c[(lang, ctx)] += 1
        a = "/".join(l.file.split("/")[:3])
        area[a][(lang, ctx)] += 1
        out.append({"file": l.file, "line": l.line, "text": l.text, "lang": lang, "ctx": ctx,
                    "before": l.before.strip()[-60:], "interp": l.interpolated, "multi": l.multiline})
    for k, v in sorted(c.items()):
        print(k, v)
    print()
    for a in sorted(area):
        v = area[a]
        print(f"{a:34} sv key {v[('sv','key')]:4} sv plain {v[('sv','plain')]:4} en key {v[('en','key')]:4} en plain {v[('en','plain')]:4} unk key {v[('unknown','key')]:3} unk plain {v[('unknown','plain')]:4}")
    if len(sys.argv) > 1:
        json.dump(out, open(sys.argv[1], "w"), ensure_ascii=False, indent=0)
