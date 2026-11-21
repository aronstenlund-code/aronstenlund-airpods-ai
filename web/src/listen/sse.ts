/// The server's answer comes as server-sent events (`event: X` / `data: <one line of JSON>`, a blank line between).
/// Fed with text as it arrives; gives back the events that are complete.
export interface ServerEvent {
  event: string;
  data: unknown;
}

export class EventReader {
  private rest = '';

  feed(text: string): ServerEvent[] {
    this.rest += text.replace(/\r\n/g, '\n');
    const events: ServerEvent[] = [];
    for (;;) {
      const end = this.rest.indexOf('\n\n');
      if (end < 0) break;
      const frame = this.rest.slice(0, end);
      this.rest = this.rest.slice(end + 2);
      let event = 'message';
      const data: string[] = [];
      for (const line of frame.split('\n')) {
        if (line.startsWith('event:')) event = line.slice(6).trim();
        else if (line.startsWith('data:')) data.push(line.slice(5).replace(/^ /, ''));
      }
      if (data.length === 0) continue;
      try {
        events.push({ event, data: JSON.parse(data.join('\n')) });
      } catch {
        /* a frame that is not JSON says nothing we use */
      }
    }
    return events;
  }
}
