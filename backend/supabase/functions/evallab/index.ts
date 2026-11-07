// Retired lab function (2026-11-07, Kevin): replaced by a 410 stub so it can never run model calls on
// the owner's keys again. Measurements now run through scripts/live-eval.py against /answer.
Deno.serve(() =>
  new Response(JSON.stringify({ error: { code: "gone", message: "This lab endpoint is retired." } }), {
    status: 410,
    headers: { "content-type": "application/json" },
  })
);
