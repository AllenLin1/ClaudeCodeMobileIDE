import { describe, it, expect } from "vitest";
import { JWTValidator, type JWTClaims } from "../src/auth/jwt-validator";
import { SignJWT, generateKeyPair, exportSPKI } from "jose";

async function makeKeys() {
  const { publicKey, privateKey } = await generateKeyPair("RS256");
  return { publicKey, privateKey, publicPem: await exportSPKI(publicKey) };
}

async function signToken(
  privateKey: CryptoKey,
  claims: Partial<JWTClaims>
): Promise<string> {
  return new SignJWT(claims as any)
    .setProtectedHeader({ alg: "RS256" })
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(privateKey);
}

describe("JWTValidator", () => {
  it("should validate a correctly signed token", async () => {
    const { privateKey, publicPem } = await makeKeys();
    const validator = new JWTValidator(publicPem);

    const token = await signToken(privateKey, {
      sub: "user_1",
      tier: "pro",
      limits: {
        max_sessions: 5,
        max_projects: -1,
        remaining_free: 0,
        features: ["multi_session"],
      },
      device_pair_id: "dp_1",
    });

    const claims = await validator.validate(token);
    expect(claims).not.toBeNull();
    expect(claims!.sub).toBe("user_1");
    expect(claims!.tier).toBe("pro");
  });

  it("should reject token from different issuer", async () => {
    const keys1 = await makeKeys();
    const keys2 = await makeKeys();

    const token = await signToken(keys1.privateKey, { sub: "user_1", tier: "free" });
    const validator = new JWTValidator(keys2.publicPem);

    expect(await validator.validate(token)).toBeNull();
  });

  it("should reject expired token", async () => {
    const { privateKey, publicPem } = await makeKeys();
    const validator = new JWTValidator(publicPem);

    const token = await new SignJWT({ sub: "user_1", tier: "free" } as any)
      .setProtectedHeader({ alg: "RS256" })
      .setIssuedAt(Math.floor(Date.now() / 1000) - 7200)
      .setExpirationTime(Math.floor(Date.now() / 1000) - 3600)
      .sign(privateKey);

    expect(await validator.validate(token)).toBeNull();
  });

  it("should reject garbage input", async () => {
    const { publicPem } = await makeKeys();
    const validator = new JWTValidator(publicPem);

    expect(await validator.validate("")).toBeNull();
    expect(await validator.validate("garbage")).toBeNull();
    expect(await validator.validate("a.b.c")).toBeNull();
  });

  it("should cache the public key across multiple validations", async () => {
    const { privateKey, publicPem } = await makeKeys();
    const validator = new JWTValidator(publicPem);

    const t1 = await signToken(privateKey, { sub: "u1", tier: "pro" });
    const t2 = await signToken(privateKey, { sub: "u2", tier: "free" });

    const c1 = await validator.validate(t1);
    const c2 = await validator.validate(t2);

    expect(c1!.sub).toBe("u1");
    expect(c2!.sub).toBe("u2");
  });
});
