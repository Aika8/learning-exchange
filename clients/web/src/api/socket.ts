import { WS_URL } from '../config';
import type { Schemas } from './client';

type Handler = (data: unknown) => void;

/**
 * One WebSocket for all channels of api/asyncapi.yaml. Re-subscribes after a reconnect.
 * Observer pattern on the client side: components subscribe to channels and get callbacks.
 */
export class MarketSocket {
  private ws: WebSocket | null = null;
  private handlers = new Map<string, Set<Handler>>();
  private closed = false;

  constructor(private readonly token: string | null) {
    this.open();
  }

  subscribe(channel: string, handler: Handler): () => void {
    let set = this.handlers.get(channel);
    if (!set) {
      set = new Set();
      this.handlers.set(channel, set);
      this.send({ op: 'subscribe', channel });
    }
    set.add(handler);
    return () => {
      set.delete(handler);
      if (set.size === 0) {
        this.handlers.delete(channel);
        this.send({ op: 'unsubscribe', channel });
      }
    };
  }

  close() {
    this.closed = true;
    this.ws?.close();
  }

  private open() {
    const url = this.token ? `${WS_URL}?token=${encodeURIComponent(this.token)}` : WS_URL;
    const ws = new WebSocket(url);
    this.ws = ws;
    ws.onopen = () => this.handlers.forEach((_, channel) => this.send({ op: 'subscribe', channel }));
    ws.onmessage = (e) => {
      const msg = JSON.parse(String(e.data)) as { channel: string; data?: unknown; error?: unknown };
      if (msg.data !== undefined) this.handlers.get(msg.channel)?.forEach((h) => h(msg.data));
    };
    ws.onclose = () => {
      if (!this.closed) setTimeout(() => this.open(), 1000);
    };
  }

  private send(msg: Schemas['WsClientMessage']) {
    if (this.ws?.readyState === WebSocket.OPEN) this.ws.send(JSON.stringify(msg));
  }
}
