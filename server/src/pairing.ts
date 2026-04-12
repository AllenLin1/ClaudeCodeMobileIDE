import type { Env } from "./licensing";

const PAIRING_TTL_MS = 10 * 60 * 1000;

interface PairingRecord {
  code: string;
  roomId: string;
  bridgePublicKey: string;
  serverUrl: string;
  createdAt: number;
}

const memoryStore = new Map<string, PairingRecord>();

function cleanExpired() {
  const now = Date.now();
  for (const [key, record] of memoryStore) {
    if (now - record.createdAt > PAIRING_TTL_MS) {
      memoryStore.delete(key);
    }
  }
}

export async function handlePairRegister(
  request: Request,
  env: Env
): Promise<Response> {
  const body = (await request.json()) as Partial<PairingRecord>;

  if (!body.code || !body.roomId) {
    return Response.json({ error: "code and roomId required" }, { status: 400 });
  }

  const record: PairingRecord = {
    code: body.code.toUpperCase(),
    roomId: body.roomId,
    bridgePublicKey: body.bridgePublicKey || "",
    serverUrl: body.serverUrl || "",
    createdAt: Date.now(),
  };

  const key = `pair:${record.code}`;

  memoryStore.set(key, record);
  cleanExpired();

  try {
    await env.LICENSING_KV.put(key, JSON.stringify(record), {
      expirationTtl: 600,
    });
  } catch {
    // KV may fail in local dev; memory store is the fallback
  }

  return Response.json({ ok: true, expiresIn: 600 });
}

export async function handlePairLookup(
  code: string,
  env: Env
): Promise<Response> {
  const key = `pair:${code.toUpperCase()}`;

  cleanExpired();
  const memRecord = memoryStore.get(key);
  if (memRecord) {
    return Response.json({
      roomId: memRecord.roomId,
      bridgePublicKey: memRecord.bridgePublicKey,
      serverUrl: memRecord.serverUrl,
    });
  }

  try {
    const raw = await env.LICENSING_KV.get(key);
    if (raw) {
      const record = JSON.parse(raw) as PairingRecord;
      return Response.json({
        roomId: record.roomId,
        bridgePublicKey: record.bridgePublicKey,
        serverUrl: record.serverUrl,
      });
    }
  } catch {
    // KV read failed; already checked memory
  }

  return Response.json(
    { error: "Pairing code not found or expired. Make sure Bridge is running." },
    { status: 404 }
  );
}
