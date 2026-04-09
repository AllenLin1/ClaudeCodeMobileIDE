import { describe, it, expect } from "vitest";
import { TierEnforcer } from "../src/auth/tier-enforcer";
import type { JWTClaims } from "../src/auth/jwt-validator";

function makeClaims(overrides: Partial<JWTClaims> = {}): JWTClaims {
  return {
    sub: "user_1",
    tier: "pro",
    limits: {
      max_sessions: 5,
      max_projects: -1,
      remaining_free: 0,
      features: ["multi_session", "git", "file_browser", "push", "model_select"],
    },
    device_pair_id: "dp_1",
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 3600,
    ...overrides,
  };
}

describe("TierEnforcer — Pro tier", () => {
  const enforcer = new TierEnforcer(makeClaims());

  it("should identify as pro", () => {
    expect(enforcer.isPro).toBe(true);
    expect(enforcer.isFree).toBe(false);
    expect(enforcer.isExpired).toBe(false);
  });

  it("should allow unlimited sessions", () => {
    expect(enforcer.canStartNewSession(0)).toBe(true);
    expect(enforcer.canStartNewSession(4)).toBe(true);
    expect(enforcer.canStartNewSession(5)).toBe(false);
  });

  it("should allow unlimited projects", () => {
    expect(enforcer.canStartNewProject(0)).toBe(true);
    expect(enforcer.canStartNewProject(100)).toBe(true);
  });

  it("should allow sending prompts", () => {
    expect(enforcer.canSendPrompt()).toBe(true);
  });

  it("should have all features", () => {
    expect(enforcer.canSelectModel()).toBe(true);
    expect(enforcer.canBrowseFiles()).toBe(true);
    expect(enforcer.canUseGit()).toBe(true);
    expect(enforcer.hasFeature("push")).toBe(true);
  });
});

describe("TierEnforcer — Free tier", () => {
  const enforcer = new TierEnforcer(
    makeClaims({
      tier: "free",
      limits: {
        max_sessions: 1,
        max_projects: 1,
        remaining_free: 7,
        features: [],
      },
    })
  );

  it("should identify as free", () => {
    expect(enforcer.isPro).toBe(false);
    expect(enforcer.isFree).toBe(true);
    expect(enforcer.isExpired).toBe(false);
  });

  it("should limit sessions to 1", () => {
    expect(enforcer.canStartNewSession(0)).toBe(true);
    expect(enforcer.canStartNewSession(1)).toBe(false);
  });

  it("should limit projects to 1", () => {
    expect(enforcer.canStartNewProject(0)).toBe(true);
    expect(enforcer.canStartNewProject(1)).toBe(false);
  });

  it("should allow prompts while remaining > 0", () => {
    expect(enforcer.canSendPrompt()).toBe(true);
  });

  it("should block all pro features", () => {
    expect(enforcer.canSelectModel()).toBe(false);
    expect(enforcer.canBrowseFiles()).toBe(false);
    expect(enforcer.canUseGit()).toBe(false);
    expect(enforcer.hasFeature("push")).toBe(false);
  });
});

describe("TierEnforcer — Free tier exhausted", () => {
  const enforcer = new TierEnforcer(
    makeClaims({
      tier: "free",
      limits: {
        max_sessions: 1,
        max_projects: 1,
        remaining_free: 0,
        features: [],
      },
    })
  );

  it("should block prompts when remaining = 0", () => {
    expect(enforcer.canSendPrompt()).toBe(false);
  });
});

describe("TierEnforcer — Expired tier", () => {
  const enforcer = new TierEnforcer(
    makeClaims({
      tier: "expired",
      limits: {
        max_sessions: 0,
        max_projects: 0,
        remaining_free: 0,
        features: [],
      },
    })
  );

  it("should identify as expired", () => {
    expect(enforcer.isExpired).toBe(true);
  });

  it("should block everything", () => {
    expect(enforcer.canSendPrompt()).toBe(false);
    expect(enforcer.canStartNewSession(0)).toBe(false);
    expect(enforcer.canStartNewProject(0)).toBe(false);
    expect(enforcer.canSelectModel()).toBe(false);
    expect(enforcer.canBrowseFiles()).toBe(false);
    expect(enforcer.canUseGit()).toBe(false);
  });
});
