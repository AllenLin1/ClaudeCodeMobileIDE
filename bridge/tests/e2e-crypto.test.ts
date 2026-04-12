import { describe, it, expect } from "vitest";
import { E2ECrypto } from "../src/crypto/e2e";

describe("E2ECrypto (Curve25519 + ChaChaPoly)", () => {
  it("should generate distinct key pairs", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    expect(alice.getPublicKey()).not.toBe(bob.getPublicKey());
    expect(alice.getSecretKey()).not.toBe(bob.getSecretKey());
  });

  it("should encrypt and decrypt between two parties", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();

    alice.deriveSharedKey(bob.getPublicKey());
    bob.deriveSharedKey(alice.getPublicKey());

    const plaintext = "Hello from Alice to Bob!";
    const encrypted = alice.encrypt(plaintext);

    expect(encrypted.nonce).toBeTruthy();
    expect(encrypted.ciphertext).toBeTruthy();
    expect(encrypted.ciphertext).not.toBe(plaintext);

    const decrypted = bob.decrypt(encrypted);
    expect(decrypted).toBe(plaintext);
  });

  it("should handle JSON roundtrip", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    alice.deriveSharedKey(bob.getPublicKey());
    bob.deriveSharedKey(alice.getPublicKey());

    const message = {
      type: "prompt",
      sessionId: "sess_123",
      text: "Refactor the API router",
    };

    const encrypted = alice.encrypt(JSON.stringify(message));
    const decrypted = JSON.parse(bob.decrypt(encrypted));
    expect(decrypted).toEqual(message);
  });

  it("should handle large payloads", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    alice.deriveSharedKey(bob.getPublicKey());
    bob.deriveSharedKey(alice.getPublicKey());

    const large = "x".repeat(100_000);
    expect(bob.decrypt(alice.encrypt(large))).toBe(large);
  });

  it("should handle unicode / CJK", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    alice.deriveSharedKey(bob.getPublicKey());
    bob.deriveSharedKey(alice.getPublicKey());

    const text = "你好世界 🚀 こんにちは 한국어";
    expect(bob.decrypt(alice.encrypt(text))).toBe(text);
  });

  it("should fail with wrong key", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    const eve = new E2ECrypto();

    alice.deriveSharedKey(bob.getPublicKey());
    eve.deriveSharedKey(alice.getPublicKey());

    const encrypted = alice.encrypt("secret");
    expect(() => eve.decrypt(encrypted)).toThrow();
  });

  it("should fail with tampered ciphertext", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    alice.deriveSharedKey(bob.getPublicKey());
    bob.deriveSharedKey(alice.getPublicKey());

    const encrypted = alice.encrypt("secret");
    const buf = Buffer.from(encrypted.ciphertext, "base64");
    buf[20] ^= 0xff;
    encrypted.ciphertext = buf.toString("base64");

    expect(() => bob.decrypt(encrypted)).toThrow();
  });

  it("should throw if shared key not derived", () => {
    const alice = new E2ECrypto();
    expect(() => alice.encrypt("test")).toThrow("Shared key not derived");
    expect(() => alice.decrypt({ nonce: "x", ciphertext: "y" })).toThrow("Shared key not derived");
  });

  it("should reconstruct from base64 keys", () => {
    const original = new E2ECrypto();
    const pub = original.getPublicKey();
    const sec = original.getSecretKey();

    const restored = E2ECrypto.fromBase64(pub, sec);
    expect(restored.getPublicKey()).toBe(pub);

    const bob = new E2ECrypto();
    restored.deriveSharedKey(bob.getPublicKey());
    bob.deriveSharedKey(restored.getPublicKey());

    expect(bob.decrypt(restored.encrypt("works"))).toBe("works");
  });

  it("should produce different ciphertexts for same plaintext", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    alice.deriveSharedKey(bob.getPublicKey());

    const e1 = alice.encrypt("same");
    const e2 = alice.encrypt("same");
    expect(e1.ciphertext).not.toBe(e2.ciphertext);
  });
});
