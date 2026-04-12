interface Env {
  LICENSING_KV: KVNamespace;
  JWT_PRIVATE_KEY_PEM: string;
  JWT_PUBLIC_KEY_PEM: string;
}

type PeerRole = "app" | "bridge";

interface ConnectedPeer {
  ws: WebSocket;
  role: PeerRole;
}

export class RelayRoom implements DurableObject {
  private state: DurableObjectState;
  private peers: Map<string, ConnectedPeer> = new Map();
  private offlineBuffer: Map<PeerRole, string[]> = new Map([
    ["app", []],
    ["bridge", []],
  ]);

  constructor(state: DurableObjectState, _env: Env) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const role = url.searchParams.get("role") as PeerRole | null;

    if (!role || !["app", "bridge"].includes(role)) {
      return new Response("Missing or invalid ?role=app|bridge", { status: 400 });
    }

    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected WebSocket", { status: 426 });
    }

    const pair = new WebSocketPair();
    const [client, server] = [pair[0], pair[1]];

    server.accept();
    const peerId = crypto.randomUUID();

    this.peers.set(peerId, { ws: server, role });
    console.log(`[relay] Peer connected: ${role} (${peerId}), total peers: ${this.peers.size}`);

    this.flushOfflineBuffer(role, server);

    server.addEventListener("message", (event) => {
      const raw = typeof event.data === "string" ? event.data : new TextDecoder().decode(event.data as ArrayBuffer);

      if (raw === "pong") return;

      const targetRole: PeerRole = role === "app" ? "bridge" : "app";
      let delivered = false;

      for (const [id, peer] of this.peers) {
        if (id !== peerId && peer.role === targetRole) {
          try {
            peer.ws.send(raw);
            delivered = true;
          } catch {
            console.log(`[relay] Failed to send to ${id}, removing`);
            this.peers.delete(id);
          }
        }
      }

      if (!delivered) {
        const buf = this.offlineBuffer.get(targetRole) || [];
        buf.push(raw);
        if (buf.length > 100) buf.shift();
        this.offlineBuffer.set(targetRole, buf);
        console.log(`[relay] ${targetRole} offline, buffered (${buf.length} msgs)`);
      } else {
        console.log(`[relay] Forwarded ${role} -> ${targetRole}`);
      }
    });

    server.addEventListener("close", () => {
      console.log(`[relay] Peer disconnected: ${role} (${peerId})`);
      this.peers.delete(peerId);
    });

    server.addEventListener("error", () => {
      console.log(`[relay] Peer error: ${role} (${peerId})`);
      this.peers.delete(peerId);
    });

    return new Response(null, { status: 101, webSocket: client });
  }

  private flushOfflineBuffer(role: PeerRole, ws: WebSocket) {
    const buf = this.offlineBuffer.get(role) || [];
    if (buf.length === 0) return;

    console.log(`[relay] Flushing ${buf.length} buffered messages to ${role}`);
    for (const msg of buf) {
      try {
        ws.send(msg);
      } catch {
        break;
      }
    }
    this.offlineBuffer.set(role, []);
  }
}
