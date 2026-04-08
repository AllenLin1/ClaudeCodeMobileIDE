import { describe, it, expect } from "vitest";
import { E2ECrypto } from "../src/crypto/e2e";

describe("E2ECrypto", () => {
  it("should generate distinct key pairs", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    expect(alice.getPublicKey()).not.toBe(bob.getPublicKey());
    expect(alice.getSecretKey()).not.toBe(bob.getSecretKey());
  });

  it("should encrypt and decrypt a message between two parties", () => {
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

  it("should handle JSON payload roundtrip", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();

    alice.deriveSharedKey(bob.getPublicKey());
    bob.deriveSharedKey(alice.getPublicKey());

    const message = {
      type: "prompt",
      sessionId: "sess_123",
      text: "Refactor the API router",
      model: "claude-opus-4-6-20260401",
    };

    const encrypted = alice.encrypt(JSON.stringify(message));
    const decrypted = JSON.parse(bob.decrypt(encrypted));

    expect(decrypted).toEqual(message);
  });

  it("should handle large payloads (code blocks)", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    alice.deriveSharedKey(bob.getPublicKey());
    bob.deriveSharedKey(alice.getPublicKey());

    const largePayload = "x".repeat(100_000);
    const encrypted = alice.encrypt(largePayload);
    const decrypted = bob.decrypt(encrypted);
    expect(decrypted).toBe(largePayload);
    expect(decrypted.length).toBe(100_000);
  });

  it("should handle unicode / CJK characters", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    alice.deriveSharedKey(bob.getPublicKey());
    bob.deriveSharedKey(alice.getPublicKey());

    const text = "你好世界 🚀 こんにちは 한국어";
    const decrypted = bob.decrypt(alice.encrypt(text));
    expect(decrypted).toBe(text);
  });

  it("should fail to decrypt with wrong key", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    const eve = new E2ECrypto();

    alice.deriveSharedKey(bob.getPublicKey());
    eve.deriveSharedKey(alice.getPublicKey());

    const encrypted = alice.encrypt("secret");

    expect(() => eve.decrypt(encrypted)).toThrow();
  });

  it("should fail to decrypt tampered ciphertext", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    alice.deriveSharedKey(bob.getPublicKey());
    bob.deriveSharedKey(alice.getPublicKey());

    const encrypted = alice.encrypt("secret");
    encrypted.ciphertext =
      encrypted.ciphertext.slice(0, -2) +
      (encrypted.ciphertext.endsWith("AA") ? "BB" : "AA");

    expect(() => bob.decrypt(encrypted)).toThrow();
  });

  it("should throw if shared key not derived", () => {
    const alice = new E2ECrypto();
    expect(() => alice.encrypt("test")).toThrow("Shared key not derived");
    expect(() =>
      alice.decrypt({ nonce: "x", ciphertext: "y" })
    ).toThrow("Shared key not derived");
  });

  it("should reconstruct from base64 keys", () => {
    const original = new E2ECrypto();
    const pub = original.getPublicKey();
    const sec = original.getSecretKey();

    const restored = E2ECrypto.fromBase64(pub, sec);
    expect(restored.getPublicKey()).toBe(pub);
    expect(restored.getSecretKey()).toBe(sec);

    const bob = new E2ECrypto();
    restored.deriveSharedKey(bob.getPublicKey());
    bob.deriveSharedKey(restored.getPublicKey());

    const msg = "restored key works";
    expect(bob.decrypt(restored.encrypt(msg))).toBe(msg);
  });

  it("should produce different ciphertexts for same plaintext (random nonce)", () => {
    const alice = new E2ECrypto();
    const bob = new E2ECrypto();
    alice.deriveSharedKey(bob.getPublicKey());

    const e1 = alice.encrypt("same text");
    const e2 = alice.encrypt("same text");

    expect(e1.nonce).not.toBe(e2.nonce);
    expect(e1.ciphertext).not.toBe(e2.ciphertext);
  });
});
