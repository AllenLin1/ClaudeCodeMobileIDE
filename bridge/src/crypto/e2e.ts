import * as crypto from "crypto";

export interface EncryptedPayload {
  nonce: string;
  ciphertext: string;
}

const HKDF_SALT = "CodePilot-E2E";
const KEY_LENGTH = 32;
const NONCE_LENGTH = 12;

export class E2ECrypto {
  private privateKey: crypto.KeyObject;
  private publicKeyRaw: Buffer;
  private sharedKey: Buffer | null = null;

  constructor(existingKeys?: { publicKey: string; secretKey: string }) {
    if (existingKeys) {
      this.privateKey = crypto.createPrivateKey({
        key: Buffer.concat([
          Buffer.from("302e020100300506032b656e04220420", "hex"),
          Buffer.from(existingKeys.secretKey, "base64"),
        ]),
        format: "der",
        type: "pkcs8",
      });
      this.publicKeyRaw = Buffer.from(existingKeys.publicKey, "base64");
    } else {
      const kp = crypto.generateKeyPairSync("x25519");
      this.privateKey = kp.privateKey;
      const spkiDer = kp.publicKey.export({ type: "spki", format: "der" }) as Buffer;
      this.publicKeyRaw = spkiDer.subarray(spkiDer.length - 32);
    }
  }

  getPublicKey(): string {
    return this.publicKeyRaw.toString("base64");
  }

  getSecretKey(): string {
    const pkcs8Der = this.privateKey.export({ type: "pkcs8", format: "der" }) as Buffer;
    return pkcs8Der.subarray(pkcs8Der.length - 32).toString("base64");
  }

  deriveSharedKey(peerPublicKeyB64: string): void {
    const peerRaw = Buffer.from(peerPublicKeyB64, "base64");
    const peerKey = crypto.createPublicKey({
      key: Buffer.concat([
        Buffer.from("302a300506032b656e032100", "hex"),
        peerRaw,
      ]),
      format: "der",
      type: "spki",
    });

    const sharedSecret = crypto.diffieHellman({
      privateKey: this.privateKey,
      publicKey: peerKey,
    });

    this.sharedKey = Buffer.from(
      crypto.hkdfSync(
        "sha256",
        sharedSecret,
        Buffer.from(HKDF_SALT, "utf-8"),
        Buffer.alloc(0),
        KEY_LENGTH
      )
    );
  }

  encrypt(plaintext: string): EncryptedPayload {
    if (!this.sharedKey) throw new Error("Shared key not derived. Call deriveSharedKey() first.");

    const nonce = crypto.randomBytes(NONCE_LENGTH);
    const cipher = crypto.createCipheriv("chacha20-poly1305", this.sharedKey, nonce, {
      authTagLength: 16,
    });

    const encrypted = Buffer.concat([
      cipher.update(plaintext, "utf-8"),
      cipher.final(),
    ]);
    const authTag = cipher.getAuthTag();

    const combined = Buffer.concat([nonce, encrypted, authTag]);

    return {
      nonce: nonce.toString("base64"),
      ciphertext: combined.toString("base64"),
    };
  }

  decrypt(payload: EncryptedPayload): string {
    if (!this.sharedKey) throw new Error("Shared key not derived. Call deriveSharedKey() first.");

    const combined = Buffer.from(payload.ciphertext, "base64");

    const nonce = combined.subarray(0, NONCE_LENGTH);
    const authTag = combined.subarray(combined.length - 16);
    const encrypted = combined.subarray(NONCE_LENGTH, combined.length - 16);

    const decipher = crypto.createDecipheriv("chacha20-poly1305", this.sharedKey, nonce, {
      authTagLength: 16,
    });
    decipher.setAuthTag(authTag);

    const decrypted = Buffer.concat([
      decipher.update(encrypted),
      decipher.final(),
    ]);

    return decrypted.toString("utf-8");
  }

  static fromBase64(publicKeyB64: string, secretKeyB64: string): E2ECrypto {
    return new E2ECrypto({ publicKey: publicKeyB64, secretKey: secretKeyB64 });
  }
}
