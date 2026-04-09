export interface JWTPayload {
  sub: string;
  tier: "pro" | "free" | "expired";
  limits: {
    max_sessions: number;
    max_projects: number;
    remaining_free: number;
    features: string[];
  };
  device_pair_id: string;
  iat: number;
  exp: number;
}

function arrayBufferToBase64Url(buffer: ArrayBuffer | Uint8Array): string {
  const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlToArrayBuffer(b64url: string): ArrayBuffer {
  const b64 = b64url.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function encodeUtf8(str: string): Uint8Array {
  return new TextEncoder().encode(str);
}

function pemToArrayBuffer(pem: string, label: string): ArrayBuffer {
  const lines = pem
    .replace(`-----BEGIN ${label}-----`, "")
    .replace(`-----END ${label}-----`, "")
    .replace(/\s/g, "");
  const binary = atob(lines);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer as ArrayBuffer;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const der = pemToArrayBuffer(pem, "PRIVATE KEY");
  return crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}

async function importPublicKey(pem: string): Promise<CryptoKey> {
  const der = pemToArrayBuffer(pem, "PUBLIC KEY");
  return crypto.subtle.importKey(
    "spki",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );
}

export async function signJWT(
  payload: JWTPayload,
  privateKeyPem: string
): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const headerB64 = arrayBufferToBase64Url(encodeUtf8(JSON.stringify(header)));
  const payloadB64 = arrayBufferToBase64Url(
    encodeUtf8(JSON.stringify(payload))
  );

  const signingInput = `${headerB64}.${payloadB64}`;
  const key = await importPrivateKey(privateKeyPem);
  const sigBytes = encodeUtf8(signingInput);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    sigBytes.buffer as ArrayBuffer
  );

  return `${signingInput}.${arrayBufferToBase64Url(signature)}`;
}

export async function verifyJWT(
  token: string,
  publicKeyPem: string
): Promise<JWTPayload | null> {
  const parts = token.split(".");
  if (parts.length !== 3) return null;

  const [headerB64, payloadB64, signatureB64] = parts;
  const signingInput = `${headerB64}.${payloadB64}`;

  try {
    const key = await importPublicKey(publicKeyPem);
    const signatureBuffer = base64UrlToArrayBuffer(signatureB64);
    const verifyBytes = encodeUtf8(signingInput);
    const valid = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      key,
      signatureBuffer,
      verifyBytes.buffer as ArrayBuffer
    );

    if (!valid) return null;

    const payloadJson = JSON.parse(
      new TextDecoder().decode(base64UrlToArrayBuffer(payloadB64))
    );
    if (payloadJson.exp && payloadJson.exp < Math.floor(Date.now() / 1000)) {
      return null;
    }

    return payloadJson as JWTPayload;
  } catch {
    return null;
  }
}
