/// The beta's screens are plain DOM: no framework to send to the phone (no runtime dependencies, CLAUDE.md).

type Child = Node | string | null | false | undefined;

interface Props {
  class?: string;
  text?: string;
  /// Attributes as they are written in HTML (`aria-label`, `type`, `disabled` …). `false`/`null` leaves one out.
  attrs?: Record<string, string | number | boolean | null | undefined>;
  onclick?: (event: MouseEvent) => void;
  oninput?: (event: Event) => void;
  onchange?: (event: Event) => void;
}

export function h<K extends keyof HTMLElementTagNameMap>(tag: K, props: Props = {}, ...children: Child[]): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  if (props.class) el.className = props.class;
  if (props.text !== undefined) el.textContent = props.text;
  for (const [name, value] of Object.entries(props.attrs ?? {})) {
    if (value === false || value === null || value === undefined) continue;
    el.setAttribute(name, value === true ? '' : String(value));
  }
  if (props.onclick) el.addEventListener('click', props.onclick as EventListener);
  if (props.oninput) el.addEventListener('input', props.oninput);
  if (props.onchange) el.addEventListener('change', props.onchange);
  for (const child of children) {
    if (child === null || child === false || child === undefined) continue;
    el.append(child);
  }
  return el;
}

/// A part of the screen that is built again only when what it shows has changed (`key`), so a field that is being
/// typed in, or a button under a finger, is not replaced for nothing.
export class Region {
  private key: string | null = null;
  constructor(readonly el: HTMLElement) {}

  show(key: string, build: () => Child[]): void {
    if (key === this.key) return;
    this.key = key;
    this.el.replaceChildren(...build().filter((c): c is Node | string => c !== null && c !== false && c !== undefined));
  }
}

const paths: Record<string, string> = {
  play: '<path d="M7 4.5v15a1 1 0 0 0 1.5.86l12.5-7.5a1 1 0 0 0 0-1.72L8.5 3.64A1 1 0 0 0 7 4.5z" fill="currentColor"/>',
  pause: '<rect x="5.5" y="4" width="4.5" height="16" rx="1.2" fill="currentColor"/><rect x="14" y="4" width="4.5" height="16" rx="1.2" fill="currentColor"/>',
  gear: '<path d="M12 8.6a3.4 3.4 0 1 0 0 6.8 3.4 3.4 0 0 0 0-6.8zm8.2 3.4c0-.5 0-1-.1-1.4l2-1.5-2-3.4-2.3.9a8 8 0 0 0-2.4-1.4L15 2.7h-4l-.4 2.5a8 8 0 0 0-2.4 1.4l-2.3-.9-2 3.4 2 1.5a8 8 0 0 0 0 2.8l-2 1.5 2 3.4 2.3-.9a8 8 0 0 0 2.4 1.4l.4 2.5h4l.4-2.5a8 8 0 0 0 2.4-1.4l2.3.9 2-3.4-2-1.5c.1-.4.1-.9.1-1.4z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>',
  plus: '<circle cx="12" cy="12" r="9.2" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M12 7.6v8.8M7.6 12h8.8" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
  clock: '<circle cx="12" cy="12" r="9.2" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M12 6.8V12l3.4 2.2" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>',
  chevron: '<path d="M9 5.5l6.5 6.5L9 18.5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  next: '<path d="M4.5 5.2v13.6a.8.8 0 0 0 1.2.7l9.3-6.1V19a1 1 0 0 0 2 0V5a1 1 0 0 0-2 0v5.6L5.7 4.5a.8.8 0 0 0-1.2.7z" fill="currentColor"/>',
  previous: '<path d="M19.5 5.2v13.6a.8.8 0 0 1-1.2.7L9 13.4V19a1 1 0 0 1-2 0V5a1 1 0 0 1 2 0v5.6l9.3-6.1a.8.8 0 0 1 1.2.7z" fill="currentColor"/>',
  trash: '<path d="M4.5 7h15M9.5 7V4.8h5V7M6.5 7l.9 12.2h9.2L17.500 7M10 10.500v5.500M14 10.500v5.500" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>',
  close: '<path d="M6.500 6.500l11 11M17.500 6.500l-11 11" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
  check: '<path d="M5 12.500l4.500 4.500L19 7.500" fill="none" stroke="currentColor" stroke-width="2.200" stroke-linecap="round" stroke-linejoin="round"/>',
};

/// A small drawing for a button. Decoration: the button's own label says what it does.
export function icon(name: keyof typeof paths, size = 20): SVGSVGElement {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('width', String(size));
  svg.setAttribute('height', String(size));
  svg.setAttribute('aria-hidden', 'true');
  svg.innerHTML = paths[name];
  return svg;
}
