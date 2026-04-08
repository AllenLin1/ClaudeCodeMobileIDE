import type { ToolApprovalRequest } from "./sdk-runner";

type ApprovalResolver = (allowed: boolean) => void;

export class ApprovalBridge {
  private pending: Map<string, ApprovalResolver> = new Map();

  createRequest(
    req: ToolApprovalRequest,
    sendToApp: (msg: any) => void
  ): Promise<boolean> {
    const requestId = `${req.sessionId}:${req.toolName}:${Date.now()}`;

    sendToApp({
      type: "sdk:tool_request",
      requestId,
      sessionId: req.sessionId,
      toolName: req.toolName,
      input: req.input,
    });

    return new Promise<boolean>((resolve) => {
      this.pending.set(requestId, resolve);

      setTimeout(() => {
        if (this.pending.has(requestId)) {
          this.pending.delete(requestId);
          resolve(false);
        }
      }, 300_000);
    });
  }

  resolveApproval(requestId: string, allowed: boolean): boolean {
    const resolver = this.pending.get(requestId);
    if (!resolver) return false;
    this.pending.delete(requestId);
    resolver(allowed);
    return true;
  }

  handleAppMessage(msg: any): boolean {
    if (msg.type === "approve" && msg.requestId) {
      return this.resolveApproval(msg.requestId, msg.allow === true);
    }
    return false;
  }

  get pendingCount(): number {
    return this.pending.size;
  }

  cancelAll(): void {
    for (const [id, resolver] of this.pending) {
      resolver(false);
    }
    this.pending.clear();
  }
}
