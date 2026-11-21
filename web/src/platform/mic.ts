import { level, to16k } from '../listen/pcm';
import type { Line, Mic } from '../listen/session';

/// The browser's microphone (getUserMedia) as blocks of 16 kHz sound. The browser asks the user itself and shows its
/// own microphone sign; nothing is recorded or kept here, each block is handed on and forgotten.
export class BrowserMic implements Mic {
  private stream: MediaStream | null = null;
  private context: AudioContext | null = null;
  private node: ScriptProcessorNode | null = null;

  async start(onBlock: (samples: Int16Array, level: number) => void): Promise<void> {
    this.stop();
    if (navigator.mediaDevices === undefined) throw new Error('no microphone here');
    const stream = await navigator.mediaDevices.getUserMedia({ audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true } });
    const Context = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    const context = new Context();
    const source = context.createMediaStreamSource(stream);
    // ScriptProcessor is old but is in every browser, and needs no second file as an AudioWorklet would.
    const node = context.createScriptProcessor(4096, 1, 1);
    const quiet = context.createGain();
    quiet.gain.value = 0; // the microphone is never played back
    node.onaudioprocess = (event) => {
      const input = event.inputBuffer.getChannelData(0);
      onBlock(to16k(input, context.sampleRate), level(input));
    };
    source.connect(node);
    node.connect(quiet);
    quiet.connect(context.destination);
    this.stream = stream;
    this.context = context;
    this.node = node;
    if (context.state === 'suspended') await context.resume().catch(() => undefined);
  }

  stop(): void {
    if (this.node !== null) this.node.onaudioprocess = null;
    this.node?.disconnect();
    this.stream?.getTracks().forEach((track) => track.stop());
    void this.context?.close().catch(() => undefined);
    this.node = null;
    this.stream = null;
    this.context = null;
  }
}

/// The Scribe socket. Sound that comes before it is open waits a moment; a long wait is dropped, not piled up.
export function openLine(url: string): Line {
  const socket = new WebSocket(url);
  const waiting: string[] = [];
  const line: Line = {
    onMessage: null,
    onClose: null,
    send: (text) => {
      if (socket.readyState === WebSocket.OPEN) socket.send(text);
      else if (socket.readyState === WebSocket.CONNECTING && waiting.length < 40) waiting.push(text);
    },
    close: () => socket.close(),
  };
  socket.addEventListener('open', () => {
    for (const text of waiting.splice(0)) socket.send(text);
  });
  socket.addEventListener('message', (event) => {
    if (typeof event.data === 'string') line.onMessage?.(event.data);
  });
  socket.addEventListener('close', () => line.onClose?.());
  return line;
}
