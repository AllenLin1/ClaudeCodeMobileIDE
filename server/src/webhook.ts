import type { Env } from "./licensing";

interface RevenueCatEvent {
  type: string;
  app_user_id: string;
  expiration_at_ms?: number;
  product_id?: string;
  event_timestamp_ms: number;
}

interface RevenueCatWebhookBody {
  api_version: string;
  event: RevenueCatEvent;
}

export async function handleWebhook(
  request: Request,
  env: Env
): Promise<Response> {
  const authHeader = request.headers.get("Authorization");
  if (
    env.REVENUECAT_WEBHOOK_SECRET &&
    authHeader !== `Bearer ${env.REVENUECAT_WEBHOOK_SECRET}`
  ) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }

  const body = (await request.json()) as RevenueCatWebhookBody;
  const event = body.event;

  if (!event || !event.app_user_id) {
    return Response.json({ error: "invalid payload" }, { status: 400 });
  }

  const userId = event.app_user_id;
  const raw = await env.LICENSING_KV.get(`user:${userId}`);
  if (!raw) {
    return Response.json({ error: "user not found" }, { status: 404 });
  }

  const user = JSON.parse(raw);

  switch (event.type) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
    case "UNCANCELLATION":
      user.tier = "pro";
      user.rc_subscriber_id = userId;
      if (event.expiration_at_ms) {
        user.rc_expiration = new Date(event.expiration_at_ms).toISOString();
      }
      break;

    case "CANCELLATION":
    case "EXPIRATION":
    case "BILLING_ISSUE":
      user.tier = "expired";
      break;

    case "SUBSCRIBER_ALIAS":
      break;

    default:
      break;
  }

  user.updated_at = new Date().toISOString();
  await env.LICENSING_KV.put(`user:${userId}`, JSON.stringify(user));

  return Response.json({ ok: true });
}
