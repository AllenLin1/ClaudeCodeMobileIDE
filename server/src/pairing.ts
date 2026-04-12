import type { Env } from "./licensing";

const PAIRING_TTL_SECONDS = 600;

interface PairingRecord {
  code: string;
  roomId: string;
  bridgePublicKey: string;
  serverUrl: string;
  createdAt: number;
}

export async function handlePairRegister(
  request: Request,
  env: Env
): Promise<Response> {
  const body = (await request.json()) as PairingRecord;

  if (!body.code || !body.roomId) {
    return Response.json({ error: "code and roomId required" }, { status: 400 });
  }

  await env.LICENSING_KV.put(
    `pair:${body.code.toUpperCase()}`,
    JSON.stringify(body),
    { expirationTtl: PAIRING_TTL_SECONDS }
  );

  return Response.json({ ok: true, expiresIn: PAIRING_TTL_SECONDS });
}

export async function handlePairLookup(
  code: string,
  env: Env
): Promise<Response> {
  const raw = await env.LICENSING_KV.get(`pair:${code.toUpperCase()}`);

  if (!raw) {
    return Response.json(
      { error: "Pairing code not found or expired. Please check the code and try again." },
      { status: 404 }
    );
  }

  const record = JSON.parse(raw) as PairingRecord;
  return Response.json({
    roomId: record.roomId,
    bridgePublicKey: record.bridgePublicKey,
    serverUrl: record.serverUrl,
  });
}
