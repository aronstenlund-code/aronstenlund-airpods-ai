const enc = new TextEncoder();

/** One Server-Sent Event frame. Data is JSON on a single line, so no escaping of newlines needed. */
export function sseFrame(event: string, data: unknown): Uint8Array {
  return enc.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

export const SSE_HEADERS: Record<string, string> = {
  "content-type": "text/event-stream; charset=utf-8",
  "cache-control": "no-cache, no-transform",
  "x-accel-buffering": "no",
  connection: "keep-alive",
};
