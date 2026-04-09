import { signJWT, verifyJWT, type JWTPayload } from "./jwt";

export interface Env {
  LICENSING_KV: KVNamespace;
  JWT_PRIVATE_KEY_PEM: string;
  JWT_PUBLIC_KEY_PEM: string;
  RELAY: DurableObjectNamespace;
  REVENUECAT_WEBHOOK_SECRET: string;
}

const FREE_TIER_LIMIT = 10;
const JWT_TTL_SECONDS = 3600;

const PRO_FEATURES = [
  "multi_session",
  "git",
  "file_browser",
  "push",
  "model_select",
];
const FREE_FEATURES: string[] = [];

interface UserRecord {
  tier: "pro" | "free" | "expired";
  free_used: number;
  rc_subscriber_id?: string;
  rc_expiration?: string;
  device_pair_id?: string;
  created_at: string;
  updated_at: string;
}

async function getOrCreateUser(
  kv: KVNamespace,
  userId: string
): Promise<UserRecord> {
  const raw = await kv.get(`user:${userId}`);
  if (raw) return JSON.parse(raw);

  const user: UserRecord = {
    tier: "free",
    free_used: 0,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  };
  await kv.put(`user:${userId}`, JSON.stringify(user));
  return user;
}

async function saveUser(
  kv: KVNamespace,
  userId: string,
  user: UserRecord
): Promise<void> {
  user.updated_at = new Date().toISOString();
  await kv.put(`user:${userId}`, JSON.stringify(user));
}

function buildPayload(
  userId: string,
  user: UserRecord
): JWTPayload {
  const now = Math.floor(Date.now() / 1000);
  const remaining =
    user.tier === "pro" ? -1 : Math.max(0, FREE_TIER_LIMIT - user.free_used);

  return {
    sub: userId,
    tier: user.tier,
    limits: {
      max_sessions: user.tier === "pro" ? 5 : 1,
      max_projects: user.tier === "pro" ? -1 : 1,
      remaining_free: remaining,
      features: user.tier === "pro" ? PRO_FEATURES : FREE_FEATURES,
    },
    device_pair_id: user.device_pair_id || "",
    iat: now,
    exp: now + JWT_TTL_SECONDS,
  };
}

export async function handleAuth(
  request: Request,
  env: Env
): Promise<Response> {
  const body = (await request.json()) as {
    user_id: string;
    device_pair_id?: string;
  };
  if (!body.user_id) {
    return Response.json({ error: "user_id required" }, { status: 400 });
  }

  const user = await getOrCreateUser(env.LICENSING_KV, body.user_id);

  if (body.device_pair_id) {
    user.device_pair_id = body.device_pair_id;
    await saveUser(env.LICENSING_KV, body.user_id, user);
  }

  const payload = buildPayload(body.user_id, user);
  const token = await signJWT(payload, env.JWT_PRIVATE_KEY_PEM);

  return Response.json({ token, payload });
}

export async function handleRenew(
  request: Request,
  env: Env
): Promise<Response> {
  const auth = request.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }

  const oldToken = auth.slice(7);
  const oldPayload = await verifyJWT(oldToken, env.JWT_PUBLIC_KEY_PEM);

  let userId: string;
  if (oldPayload) {
    userId = oldPayload.sub;
  } else {
    const decoded = JSON.parse(
      new TextDecoder().decode(
        Uint8Array.from(
          atob(
            oldToken
              .split(".")[1]
              .replace(/-/g, "+")
              .replace(/_/g, "/")
          ),
          (c) => c.charCodeAt(0)
        )
      )
    );
    userId = decoded.sub;
    if (!userId) {
      return Response.json({ error: "invalid token" }, { status: 401 });
    }
  }

  const user = await getOrCreateUser(env.LICENSING_KV, userId);
  const payload = buildPayload(userId, user);
  const token = await signJWT(payload, env.JWT_PRIVATE_KEY_PEM);

  return Response.json({ token, payload });
}

export async function handleUsage(
  request: Request,
  env: Env
): Promise<Response> {
  const auth = request.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }

  const payload = await verifyJWT(auth.slice(7), env.JWT_PUBLIC_KEY_PEM);
  if (!payload) {
    return Response.json({ error: "invalid token" }, { status: 401 });
  }

  if (payload.tier === "pro") {
    return Response.json({ allowed: true, remaining: -1 });
  }

  const user = await getOrCreateUser(env.LICENSING_KV, payload.sub);
  user.free_used += 1;
  await saveUser(env.LICENSING_KV, payload.sub, user);

  const remaining = Math.max(0, FREE_TIER_LIMIT - user.free_used);
  const allowed = user.free_used <= FREE_TIER_LIMIT;

  return Response.json({ allowed, remaining, used: user.free_used });
}

export async function handlePublicKey(env: Env): Promise<Response> {
  return Response.json({ public_key: env.JWT_PUBLIC_KEY_PEM });
}
