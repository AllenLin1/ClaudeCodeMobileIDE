import { describe, it, expect, vi, beforeEach } from "vitest";
import { ApprovalBridge } from "../src/agent/approval-bridge";

describe("ApprovalBridge", () => {
  let bridge: ApprovalBridge;
  let sentMessages: any[];

  beforeEach(() => {
    bridge = new ApprovalBridge();
    sentMessages = [];
  });

  const mockSend = (msg: any) => sentMessages.push(msg);

  it("should send tool_request to app and await resolution", async () => {
    const promise = bridge.createRequest(
      { sessionId: "s1", toolName: "Bash", input: { command: "npm test" } },
      mockSend
    );

    expect(sentMessages).toHaveLength(1);
    expect(sentMessages[0].type).toBe("sdk:tool_request");
    expect(sentMessages[0].toolName).toBe("Bash");
    expect(sentMessages[0].input.command).toBe("npm test");
    expect(bridge.pendingCount).toBe(1);

    const requestId = sentMessages[0].requestId;
    bridge.resolveApproval(requestId, true);

    const result = await promise;
    expect(result).toBe(true);
    expect(bridge.pendingCount).toBe(0);
  });

  it("should deny when resolved with false", async () => {
    const promise = bridge.createRequest(
      { sessionId: "s1", toolName: "Write", input: { path: "/etc/passwd" } },
      mockSend
    );

    const requestId = sentMessages[0].requestId;
    bridge.resolveApproval(requestId, false);

    expect(await promise).toBe(false);
  });

  it("should handle app messages correctly", async () => {
    const promise = bridge.createRequest(
      { sessionId: "s1", toolName: "Bash", input: {} },
      mockSend
    );

    const requestId = sentMessages[0].requestId;

    // Unrelated message should not resolve
    const handled1 = bridge.handleAppMessage({ type: "prompt", text: "hello" });
    expect(handled1).toBe(false);

    // Correct approval
    const handled2 = bridge.handleAppMessage({
      type: "approve",
      requestId,
      allow: true,
    });
    expect(handled2).toBe(true);

    expect(await promise).toBe(true);
  });

  it("should return false for unknown request IDs", () => {
    expect(bridge.resolveApproval("nonexistent", true)).toBe(false);
  });

  it("should cancel all pending requests", async () => {
    const p1 = bridge.createRequest(
      { sessionId: "s1", toolName: "Bash", input: {} },
      mockSend
    );
    const p2 = bridge.createRequest(
      { sessionId: "s2", toolName: "Write", input: {} },
      mockSend
    );

    expect(bridge.pendingCount).toBe(2);
    bridge.cancelAll();
    expect(bridge.pendingCount).toBe(0);

    expect(await p1).toBe(false);
    expect(await p2).toBe(false);
  });

  it("should handle multiple concurrent requests", async () => {
    const p1 = bridge.createRequest(
      { sessionId: "s1", toolName: "Bash", input: { command: "ls" } },
      mockSend
    );
    const p2 = bridge.createRequest(
      { sessionId: "s1", toolName: "Write", input: { path: "foo.txt" } },
      mockSend
    );

    expect(bridge.pendingCount).toBe(2);

    bridge.resolveApproval(sentMessages[0].requestId, true);
    bridge.resolveApproval(sentMessages[1].requestId, false);

    expect(await p1).toBe(true);
    expect(await p2).toBe(false);
  });
});
