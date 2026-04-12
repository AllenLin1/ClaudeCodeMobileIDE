import WebSocket from "ws";
import { EventEmitter } from "events";
import type { E2ECrypto, EncryptedPayload } from "./crypto/e2e";

export interface RelayClientOptions {
  serverUrl: string;
  roomId: string;
  role: "bridge";
  crypto: E2ECrypto;
  onMessage: (decrypted: any) => void;
  onConnected?: () => void;
  onDisconnected?: () => void;
}

const RECONNECT_BASE_MS = 1000;
const RECONNECT_MAX_MS = 30000;

export class RelayClient extends EventEmitter {
  private ws: WebSocket | null = null;
  private opts: RelayClientOptions;
  private reconnectAttempt = 0;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private seq = 0;
  private peerAck = 0;
  private closed = false;

  constructor(opts: RelayClientOptions) {
    super();
    this.opts = opts;
  }

  connect(): void {
    if (this.closed) return;
    const url = `${this.opts.serverUrl}/relay/${this.opts.roomId}?role=${this.opts.role}`;
    this.ws = new WebSocket(url);

    this.ws.on("open", () => {
      this.reconnectAttempt = 0;
      this.opts.onConnected?.();
      this.emit("connected");
    });

    this.ws.on("message", (data: WebSocket.Data) => {
      const raw = data.toString();
      if (raw === "ping") {
        this.ws?.send("pong");
        return;
      }
      try {
        const envelope = JSON.parse(raw);
        if (envelope.ack !== undefined) {
          this.peerAck = envelope.ack;
        }
        if (envelope.plain) {
          const msg = JSON.parse(envelope.plain);
          this.opts.onMessage(msg);
        } else if (envelope.encrypted) {
          const decrypted = this.opts.crypto.decrypt(
            envelope.encrypted as EncryptedPayload
          );
          const msg = JSON.parse(decrypted);
          this.opts.onMessage(msg);
        }
      } catch (err) {
        console.error("[relay] Failed to process message:", err);
      }
    });

    this.ws.on("close", () => {
      this.opts.onDisconnected?.();
      this.emit("disconnected");
      this.scheduleReconnect();
    });

    this.ws.on("error", (err) => {
      console.error("[relay] WebSocket error:", err.message);
    });
  }

  send(message: any): void {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      console.warn("[relay] Not connected, message dropped");
      return;
    }
    this.seq++;
    const plaintext = JSON.stringify(message);
    const envelope = {
      seq: this.seq,
      ack: this.peerAck,
      ts: Date.now(),
      plain: plaintext,
    };
    this.ws.send(JSON.stringify(envelope));
  }

  get isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }

  close(): void {
    this.closed = true;
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    this.ws?.close();
  }

  private scheduleReconnect(): void {
    if (this.closed) return;
    const delay = Math.min(
      RECONNECT_BASE_MS * Math.pow(2, this.reconnectAttempt),
      RECONNECT_MAX_MS
    );
    this.reconnectAttempt++;
    console.log(`[relay] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempt})`);
    this.reconnectTimer = setTimeout(() => this.connect(), delay);
  }
}
