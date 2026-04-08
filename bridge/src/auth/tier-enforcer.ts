import type { JWTClaims } from "./jwt-validator";

export type Feature =
  | "multi_session"
  | "git"
  | "file_browser"
  | "push"
  | "model_select";

export class TierEnforcer {
  private claims: JWTClaims;

  constructor(claims: JWTClaims) {
    this.claims = claims;
  }

  get tier(): string {
    return this.claims.tier;
  }

  get isPro(): boolean {
    return this.claims.tier === "pro";
  }

  get isFree(): boolean {
    return this.claims.tier === "free";
  }

  get isExpired(): boolean {
    return this.claims.tier === "expired";
  }

  get maxSessions(): number {
    return this.claims.limits.max_sessions;
  }

  get maxProjects(): number {
    return this.claims.limits.max_projects;
  }

  get remainingFree(): number {
    return this.claims.limits.remaining_free;
  }

  hasFeature(feature: Feature): boolean {
    return this.claims.limits.features.includes(feature);
  }

  canStartNewSession(currentCount: number): boolean {
    if (this.isExpired) return false;
    if (this.maxSessions === -1) return true;
    return currentCount < this.maxSessions;
  }

  canStartNewProject(currentCount: number): boolean {
    if (this.isExpired) return false;
    if (this.maxProjects === -1) return true;
    return currentCount < this.maxProjects;
  }

  canSendPrompt(): boolean {
    if (this.isExpired) return false;
    if (this.isPro) return true;
    return this.remainingFree > 0;
  }

  canSelectModel(): boolean {
    return this.hasFeature("model_select");
  }

  canBrowseFiles(): boolean {
    return this.hasFeature("file_browser");
  }

  canUseGit(): boolean {
    return this.hasFeature("git");
  }
}
