import {
  handleAuth,
  handleRenew,
  handleUsage,
  handlePublicKey,
  type Env,
} from "./licensing";
import { handleWebhook } from "./webhook";
import { handlePairRegister, handlePairLookup } from "./pairing";
export { RelayRoom } from "./relay";

function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  };
}

function withCors(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [k, v] of Object.entries(corsHeaders())) {
    headers.set(k, v);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export default {
  async fetch(
    request: Request,
    env: Env,
    _ctx: ExecutionContext
  ): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      if (path === "/auth" && request.method === "POST") {
        return withCors(await handleAuth(request, env));
      }

      if (path === "/renew" && request.method === "POST") {
        return withCors(await handleRenew(request, env));
      }

      if (path === "/usage" && request.method === "POST") {
        return withCors(await handleUsage(request, env));
      }

      if (path === "/public-key" && request.method === "GET") {
        return withCors(await handlePublicKey(env));
      }

      if (path === "/webhook/revenuecat" && request.method === "POST") {
        return withCors(await handleWebhook(request, env));
      }

      if (path === "/pair/register" && request.method === "POST") {
        return withCors(await handlePairRegister(request, env));
      }

      if (path.startsWith("/pair/") && request.method === "GET") {
        const code = path.split("/pair/")[1];
        if (code && code !== "register") {
          return withCors(await handlePairLookup(code, env));
        }
      }

      if (path.startsWith("/relay/")) {
        const roomId = path.split("/relay/")[1];
        if (!roomId) {
          return withCors(
            Response.json({ error: "room id required" }, { status: 400 })
          );
        }

        const durableId = env.RELAY.idFromName(roomId);
        const stub = env.RELAY.get(durableId);
        return stub.fetch(request);
      }

      if (path === "/health") {
        return withCors(
          Response.json({ status: "ok", version: "1.0.0" })
        );
      }

      return withCors(
        Response.json({ error: "not found" }, { status: 404 })
      );
    } catch (err) {
      const message = err instanceof Error ? err.message : "internal error";
      return withCors(
        Response.json({ error: message }, { status: 500 })
      );
    }
  },
};
