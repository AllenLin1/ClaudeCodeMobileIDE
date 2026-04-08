import nacl from "tweetnacl";
import naclUtil from "tweetnacl-util";

export interface KeyPair {
  publicKey: Uint8Array;
  secretKey: Uint8Array;
}

export interface EncryptedPayload {
  nonce: string;
  ciphertext: string;
}

export class E2ECrypto {
  private keyPair: KeyPair;
  private sharedKey: Uint8Array | null = null;

  constructor(existingKeyPair?: KeyPair) {
    this.keyPair = existingKeyPair || nacl.box.keyPair();
  }

  getPublicKey(): string {
    return naclUtil.encodeBase64(this.keyPair.publicKey);
  }

  getSecretKey(): string {
    return naclUtil.encodeBase64(this.keyPair.secretKey);
  }

  deriveSharedKey(peerPublicKeyB64: string): void {
    const peerPublicKey = naclUtil.decodeBase64(peerPublicKeyB64);
    this.sharedKey = nacl.box.before(peerPublicKey, this.keyPair.secretKey);
  }

  encrypt(plaintext: string): EncryptedPayload {
    if (!this.sharedKey) throw new Error("Shared key not derived. Call deriveSharedKey() first.");
    const nonce = nacl.randomBytes(nacl.box.nonceLength);
    const messageBytes = naclUtil.decodeUTF8(plaintext);
    const encrypted = nacl.box.after(messageBytes, nonce, this.sharedKey);
    if (!encrypted) throw new Error("Encryption failed");
    return {
      nonce: naclUtil.encodeBase64(nonce),
      ciphertext: naclUtil.encodeBase64(encrypted),
    };
  }

  decrypt(payload: EncryptedPayload): string {
    if (!this.sharedKey) throw new Error("Shared key not derived. Call deriveSharedKey() first.");
    const nonce = naclUtil.decodeBase64(payload.nonce);
    const ciphertext = naclUtil.decodeBase64(payload.ciphertext);
    const decrypted = nacl.box.open.after(ciphertext, nonce, this.sharedKey);
    if (!decrypted) throw new Error("Decryption failed — wrong key or tampered data");
    return naclUtil.encodeUTF8(decrypted);
  }

  static fromBase64(publicKeyB64: string, secretKeyB64: string): E2ECrypto {
    return new E2ECrypto({
      publicKey: naclUtil.decodeBase64(publicKeyB64),
      secretKey: naclUtil.decodeBase64(secretKeyB64),
    });
  }
}
