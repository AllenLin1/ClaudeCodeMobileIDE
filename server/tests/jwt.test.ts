import { describe, it, expect } from "vitest";
import { signJWT, verifyJWT, type JWTPayload } from "../src/jwt";
import { generateKeyPair, exportPKCS8, exportSPKI } from "jose";

async function makeKeys() {
  const { publicKey, privateKey } = await generateKeyPair("RS256", {
    extractable: true,
  });
  return {
    privatePem: await exportPKCS8(privateKey),
    publicPem: await exportSPKI(publicKey),
  };
}

function samplePayload(overrides: Partial<JWTPayload> = {}): JWTPayload {
  const now = Math.floor(Date.now() / 1000);
  return {
    sub: "user_abc",
    tier: "pro",
    limits: {
      max_sessions: 5,
      max_projects: -1,
      remaining_free: 0,
      features: ["multi_session", "git", "file_browser", "push", "model_select"],
    },
    device_pair_id: "dp_123",
    iat: now,
    exp: now + 3600,
    ...overrides,
  };
}

describe("JWT sign + verify", () => {
  it("should sign and verify a valid token", async () => {
    const { privatePem, publicPem } = await makeKeys();
    const payload = samplePayload();
    const token = await signJWT(payload, privatePem);

    expect(token).toBeTruthy();
    expect(token.split(".")).toHaveLength(3);

    const verified = await verifyJWT(token, publicPem);
    expect(verified).not.toBeNull();
    expect(verified!.sub).toBe("user_abc");
    expect(verified!.tier).toBe("pro");
    expect(verified!.limits.max_sessions).toBe(5);
    expect(verified!.device_pair_id).toBe("dp_123");
  });

  it("should reject a token signed with a different key", async () => {
    const keys1 = await makeKeys();
    const keys2 = await makeKeys();
    const payload = samplePayload();
    const token = await signJWT(payload, keys1.privatePem);

    const verified = await verifyJWT(token, keys2.publicPem);
    expect(verified).toBeNull();
  });

  it("should reject an expired token", async () => {
    const { privatePem, publicPem } = await makeKeys();
    const payload = samplePayload({
      iat: Math.floor(Date.now() / 1000) - 7200,
      exp: Math.floor(Date.now() / 1000) - 3600,
    });
    const token = await signJWT(payload, privatePem);

    const verified = await verifyJWT(token, publicPem);
    expect(verified).toBeNull();
  });

  it("should reject a tampered token", async () => {
    const { privatePem, publicPem } = await makeKeys();
    const payload = samplePayload();
    const token = await signJWT(payload, privatePem);

    // Flip a character in the payload section
    const parts = token.split(".");
    parts[1] = parts[1].slice(0, -1) + (parts[1].endsWith("A") ? "B" : "A");
    const tampered = parts.join(".");

    const verified = await verifyJWT(tampered, publicPem);
    expect(verified).toBeNull();
  });

  it("should reject malformed tokens", async () => {
    const { publicPem } = await makeKeys();
    expect(await verifyJWT("", publicPem)).toBeNull();
    expect(await verifyJWT("a.b", publicPem)).toBeNull();
    expect(await verifyJWT("not-a-jwt", publicPem)).toBeNull();
  });

  it("should preserve free tier payload", async () => {
    const { privatePem, publicPem } = await makeKeys();
    const payload = samplePayload({
      tier: "free",
      limits: {
        max_sessions: 1,
        max_projects: 1,
        remaining_free: 7,
        features: [],
      },
    });
    const token = await signJWT(payload, privatePem);
    const verified = await verifyJWT(token, publicPem);

    expect(verified!.tier).toBe("free");
    expect(verified!.limits.max_sessions).toBe(1);
    expect(verified!.limits.remaining_free).toBe(7);
    expect(verified!.limits.features).toEqual([]);
  });
});
