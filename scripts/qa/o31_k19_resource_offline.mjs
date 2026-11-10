// Oscar QA, O31: independent offline test of Kevin's K19 (answer/resource.ts): is a request for a film/page
// recognised (isResourceRequest), which topic is searched (resourceTopic), and can a look-alike address pass the
// domain list (domainOf). The live part (search + 200 check) costs API and is not run here. Free, deployed file.
//   node scripts/qa/o31_k19_resource_offline.mjs > reports/qa/data/<stamp>-o31-k19.json
import { domainOf, isResourceRequest, resourceTopic } from "../../backend/supabase/functions/answer/resource.ts";

const ASK = [
  "har du en film om fotosyntes", "finns det någon bra video om andra världskriget", "tipsa om en sida om bråk",
  "kan du hitta en film om cellen", "jag vill se en film om vulkaner", "visa en video om Pythagoras sats",
  "har du något klipp om franska revolutionen", "finns det nån bra sida om det här", "kan du länka något om DNA",
  "skicka en länk om ekvationer", "ge mig en film om Shakespeare", "var kan jag läsa mer om klimatförändringar",
  "har du nåt bra på UR om demokrati", "någon youtube om derivata", "kan du rekommendera en film om fotosyntesen",
];
const NOT_ASK = [
  "vilken film vann Oscar 2020", "vad handlar filmen Titanic om", "hur gör man en film i skolan", "vad är en webbsida",
  "jag såg en film om hajar igår", "finns det liv på Mars", "har du sett Harry Potter", "skicka hälsningar till mamma",
];
const TOPIC = [ // [fragment, lastQ, the topic must contain]
  ["har du en film om fotosyntes", "", "fotosyntes"], ["finns det någon bra sida om det här", "vad är fotosyntes", "fotosyntes"],
  ["har du en film om det", "förklara hur vulkaner bildas", "vulkaner"], ["finns det en video på engelska om DNA", "", "DNA"],
  ["har du en film om andra världskriget för åk 9", "", "andra världskriget"], ["skicka en länk om bråk tack", "", "bråk"],
  ["har du en bra sida om hur man räknar procent", "", "procent"], ["finns det en film om det här på UR Play", "vad är cellandning", "cellandning"],
];
const DOMAINS = [ // [url, expected domain or null]
  ["https://urplay.se/program/123-fotosyntes", "urplay.se"], ["https://www.ne.se/uppslagsverk/x", "ne.se"],
  ["https://urplay.se.evil.example/x", null], ["https://evilurplay.se/x", null], ["https://urplay.se@evil.example/x", null],
  ["https://khanacademy.org.evil.example/x", null], ["http://sv.khanacademy.org/math", "sv.khanacademy.org"],
  ["javascript:alert(1)//urplay.se", null], ["https://xn--urply-lra.se/x", null],
];
const ask = ASK.map((t) => ({ t, got: isResourceRequest(t), ok: isResourceRequest(t) }));
const notAsk = NOT_ASK.map((t) => ({ t, got: isResourceRequest(t), ok: !isResourceRequest(t) }));
const topic = TOPIC.map(([f, q, must]) => { const t = resourceTopic(f, q); return { f, lastQ: q, topic: t, ok: t.toLowerCase().includes(must.toLowerCase()) && t.length < must.length + 25 }; });
const dom = DOMAINS.map(([u, want]) => ({ u, want, got: domainOf(u), ok: domainOf(u) === want }));
const n = (a) => `${a.filter((x) => x.ok).length}/${a.length}`;
console.log(JSON.stringify({ sum_requests: n(ask), sum_not_requests: n(notAsk), sum_topic: n(topic), sum_domains: n(dom),
  fails: [...ask, ...notAsk, ...topic, ...dom].filter((x) => !x.ok), ask, notAsk, topic, dom }, null, 1));
