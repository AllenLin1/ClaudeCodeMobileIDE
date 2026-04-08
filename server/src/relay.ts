interface Env {
  LICENSING_KV: KVNamespace;
  JWT_PRIVATE_KEY_PEM: string;
  JWT_PUBLIC_KEY_PEM: string;
}

interface BufferedMessage {
  data: string;
  timestamp: number;
}

type PeerRole = "app" | "bridge";

interface ConnectedPeer {
  ws: WebSocket;
  role: PeerRole;
  lastPing: number;
}

const MAX_OFFLINE_BUFFER = 200;
const PING_INTERVAL_MS = 30_000;
const PEER_TIMEOUT_MS = 90_000;

export class RelayRoom implements DurableObject {
  private state: DurableObjectState;
  private peers: Map<string, ConnectedPeer> = new Map();
  private offlineBuffer: Map<PeerRole, BufferedMessage[]> = new Map([
    ["app", []],
    ["bridge", []],
  ]);
  private pingInterval: ReturnType<typeof setInterval> | null = null;

  constructor(state: DurableObjectState, _env: Env) {
    this.state = state;
    this.state.blockConcurrencyWhile(async () => {
      const appBuf = await this.state.storage.get<BufferedMessage[]>(
        "buffer:app"
      );
      const bridgeBuf = await this.state.storage.get<BufferedMessage[]>(
        "buffer:bridge"
      );
      if (appBuf) this.offlineBuffer.set("app", appBuf);
      if (bridgeBuf) this.offlineBuffer.set("bridge", bridgeBuf);
    });
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const role = url.searchParams.get("role") as PeerRole | null;

    if (!role || !["app", "bridge"].includes(role)) {
      return new Response("Missing or invalid ?role=app|bridge", {
        status: 400,
      });
    }

    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected WebSocket", { status: 426 });
    }

    const pair = new WebSocketPair();
    const [client, server] = [pair[0], pair[1]];

    this.state.acceptWebSocket(server, [role]);
    const peerId = crypto.randomUUID();

    this.peers.set(peerId, {
      ws: server,
      role,
      lastPing: Date.now(),
    });

    this.startPingIfNeeded();
    this.flushOfflineBuffer(role, server);

    server.addEventListener("message", (event) => {
      this.handleMessage(peerId, role, event.data);
    });

    server.addEventListener("close", () => {
      this.peers.delete(peerId);
      this.stopPingIfEmpty();
    });

    server.addEventListener("error", () => {
      this.peers.delete(peerId);
      this.stopPingIfEmpty();
    });

    return new Response(null, { status: 101, webSocket: client });
  }

  private handleMessage(
    senderId: string,
    senderRole: PeerRole,
    data: string | ArrayBuffer
  ) {
    const targetRole: PeerRole = senderRole === "app" ? "bridge" : "app";
    const raw = typeof data === "string" ? data : new TextDecoder().decode(data);

    if (raw === "pong") {
      const peer = this.peers.get(senderId);
      if (peer) peer.lastPing = Date.now();
      return;
    }

    let delivered = false;
    for (const [id, peer] of this.peers) {
      if (id !== senderId && peer.role === targetRole) {
        try {
          peer.ws.send(raw);
          delivered = true;
        } catch {
          this.peers.delete(id);
        }
      }
    }

    if (!delivered) {
      this.bufferForOffline(targetRole, raw);
    }
  }

  private bufferForOffline(role: PeerRole, data: string) {
    const buf = this.offlineBuffer.get(role) || [];
    buf.push({ data, timestamp: Date.now() });
    if (buf.length > MAX_OFFLINE_BUFFER) {
      buf.splice(0, buf.length - MAX_OFFLINE_BUFFER);
    }
    this.offlineBuffer.set(role, buf);
    this.state.storage.put(`buffer:${role}`, buf);
  }

  private flushOfflineBuffer(role: PeerRole, ws: WebSocket) {
    const buf = this.offlineBuffer.get(role) || [];
    if (buf.length === 0) return;

    for (const msg of buf) {
      try {
        ws.send(msg.data);
      } catch {
        break;
      }
    }

    this.offlineBuffer.set(role, []);
    this.state.storage.put(`buffer:${role}`, []);
  }

  private startPingIfNeeded() {
    if (this.pingInterval) return;
    this.pingInterval = setInterval(() => {
      const now = Date.now();
      for (const [id, peer] of this.peers) {
        if (now - peer.lastPing > PEER_TIMEOUT_MS) {
          try {
            peer.ws.close(1000, "timeout");
          } catch { /* already closed */ }
          this.peers.delete(id);
          continue;
        }
        try {
          peer.ws.send("ping");
        } catch {
          this.peers.delete(id);
        }
      }
      this.stopPingIfEmpty();
    }, PING_INTERVAL_MS);
  }

  private stopPingIfEmpty() {
    if (this.peers.size === 0 && this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }
  }
}
