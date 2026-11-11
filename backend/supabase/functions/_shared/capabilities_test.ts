// K44: the server's copy of Shared/capabilities.json is the same file, and the list answers as the app shows it.
import { assert, assertEquals } from "jsr:@std/assert@1.0.8";
import { capabilityAnswer, capabilityAsked, helpAnswer, notYetAsked, overview } from "./capabilities.ts";

Deno.test("K44 the copy in _shared is identical to Shared/capabilities.json (the app's file)", () => {
  const app = Deno.readTextFileSync(new URL("../../../../Shared/capabilities.json", import.meta.url));
  const srv = Deno.readTextFileSync(new URL("./capabilities.json", import.meta.url));
  assertEquals(JSON.parse(srv), JSON.parse(app), "copy Shared/capabilities.json to backend/supabase/functions/_shared/");
});

Deno.test("K44 'kan du …?' is answered from the list; things not on it are an honest no", () => {
  const cases: [string, string][] = [
    ["Kan du sätta en timer på tio minuter?", "timer"], ["Kan du spela musik?", "music"], ["Kan du lägga in ett möte i min kalender?", "calendar"],
    ["kan du påminna mig om saker", "reminders"], ["kan du väcka mig i morgon", "alarm"], ["Lumen, kan du ringa mamma", "call"],
    ["kan du förhöra mig", "quiz"], ["går det att spara en anteckning", "notes"], ["kan du översätta saker", "translate"], ["kan du hjälpa mig med läxan", "questions"],
  ];
  for (const [q, id] of cases) assertEquals(capabilityAsked(q)?.id, id, q);
  assertEquals(capabilityAsked("vad är en timer"), null);
  for (const q of ["kan du förklara fotosyntes", "kan du översätta fjäril till engelska", "kan du förhöra mig på cellen", "kan du hjälpa mig med läxan i matte om bråk"]) assertEquals(capabilityAsked(q), null, q);
  assert(notYetAsked("kan du skicka sms till Elin"));
  assert(!notYetAsked("kan du sätta en timer"));
  assert(capabilityAnswer(capabilityAsked("kan du sätta en timer")!).startsWith("Ja. Säg till exempel: Lumen, sätt en timer"));
  assert(capabilityAnswer(capabilityAsked("kan du sätta en timer")!, ["calendar"]).includes("tillåta larm och timer"));
  assert(capabilityAnswer(capabilityAsked("kan du byta låt")!).startsWith("Det kommer snart"));
  assert(!/studieassistent/i.test(overview()));
  assert(helpAnswer("Hur stänger jag av dig?")!.includes("Stoppa"));
  assertEquals(helpAnswer("hur stänger man av en dator"), null);
});

Deno.test("K44 live: 'kan du skicka ett mejl', 'kan du ta en bild' are an honest no", () => {
  for (const q of ["kan du skicka ett mejl", "kan du ta en bild", "kan du swisha pengar", "kan du tända lampan", "kan du boka en resa"]) assert(notYetAsked(q), q);
  assert(!notYetAsked("kan du sätta en timer"));
});

Deno.test("Oscar O52 after K44: sleep report, Spotify control (coming) and no '?.'", () => {
  assertEquals(capabilityAsked("kan du ge mig en morgonrapport om min sömn")?.id, "sleep");
  const sp = capabilityAsked("kan du styra Spotify och byta låt")!;
  assertEquals(sp.id, "spotify");
  assert(capabilityAnswer(sp).startsWith("Det kommer snart") && capabilityAnswer(sp).includes("öppna musik"));
  assertEquals(capabilityAsked("kan du öppna spotify")?.id, "music");
  assertEquals(capabilityAnswer(capabilityAsked("kan du kolla vädret")!), "Ja. Säg till exempel: Lumen, vad blir vädret i morgon?");
  assertEquals(capabilityAsked("kan du ge mig ett träningspass"), null);
});
