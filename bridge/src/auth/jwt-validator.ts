import { importSPKI, jwtVerify } from "jose";

export interface JWTClaims {
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

export class JWTValidator {
  private publicKey: unknown = null;
  private publicKeyPem: string;

  constructor(publicKeyPem: string) {
    this.publicKeyPem = publicKeyPem;
  }

  private async getKey(): Promise<unknown> {
    if (!this.publicKey) {
      this.publicKey = await importSPKI(this.publicKeyPem, "RS256");
    }
    return this.publicKey;
  }

  async validate(token: string): Promise<JWTClaims | null> {
    try {
      const key = await this.getKey();
      const { payload } = await jwtVerify(token, key as any, {
        algorithms: ["RS256"],
      });
      return payload as unknown as JWTClaims;
    } catch {
      return null;
    }
  }
}
