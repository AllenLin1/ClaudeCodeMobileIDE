import { SDKRunner, type SDKMessage, type ToolApprovalRequest } from "../agent/sdk-runner";
import { ApprovalBridge } from "../agent/approval-bridge";
import { SessionBuffer } from "./buffer";

export interface SessionInfo {
  id: string;
  name: string;
  cwd: string;
  model: string;
  status: "active" | "paused" | "completed" | "error";
  createdAt: number;
  lastActivity: number;
  lastMessage?: string;
}

export interface SessionManagerOptions {
  dbPath: string;
  sendToApp: (msg: any) => void;
  maxSessions: number;
}

export class SessionManager {
  private sessions: Map<string, SDKRunner> = new Map();
  private sessionInfos: Map<string, SessionInfo> = new Map();
  private approvalBridge: ApprovalBridge;
  private buffer: SessionBuffer;
  private sendToApp: (msg: any) => void;
  private maxSessions: number;

  constructor(opts: SessionManagerOptions) {
    this.approvalBridge = new ApprovalBridge();
    this.buffer = new SessionBuffer(opts.dbPath);
    this.sendToApp = opts.sendToApp;
    this.maxSessions = opts.maxSessions;

    const persisted = this.buffer.getAllSessions();
    for (const info of persisted) {
      info.status = "paused";
      this.sessionInfos.set(info.id, info);
    }
  }

  createSession(name: string, cwd: string, model: string): SessionInfo {
    if (this.sessions.size >= this.maxSessions) {
      throw new Error(
        `Session limit reached (${this.maxSessions}). Upgrade to Pro for more sessions.`
      );
    }

    const id = `session_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
    const info: SessionInfo = {
      id,
      name,
      cwd,
      model,
      status: "active",
      createdAt: Date.now(),
      lastActivity: Date.now(),
    };

    this.sessionInfos.set(id, info);
    this.buffer.saveSession(info);

    const runner = new SDKRunner({
      model,
      cwd,
      sessionId: id,
      onApprovalNeeded: (req: ToolApprovalRequest) =>
        this.approvalBridge.createRequest(req, this.sendToApp),
    });

    runner.on("message", (msg: SDKMessage) => {
      info.lastActivity = Date.now();
      info.lastMessage =
        msg.content?.slice(0, 100) || msg.toolName || "...";

      this.buffer.saveMessage(id, msg);
      this.buffer.saveSession(info);

      this.sendToApp({
        type: `sdk:${msg.type === "tool_use" ? "message" : msg.type}`,
        sessionId: id,
        message: msg,
      });
    });

    this.sessions.set(id, runner);

    this.sendToApp({
      type: "session:created",
      sessionId: id,
      name,
      cwd,
      model,
    });

    return info;
  }

  async sendPrompt(sessionId: string, text: string): Promise<void> {
    let runner = this.sessions.get(sessionId);
    const info = this.sessionInfos.get(sessionId);
    if (!info) throw new Error(`Session ${sessionId} not found`);

    if (!runner) {
      runner = new SDKRunner({
        model: info.model,
        cwd: info.cwd,
        sessionId,
        onApprovalNeeded: (req) =>
          this.approvalBridge.createRequest(req, this.sendToApp),
      });
      runner.on("message", (msg: SDKMessage) => {
        info.lastActivity = Date.now();
        info.lastMessage = msg.content?.slice(0, 100) || msg.toolName || "...";
        this.buffer.saveMessage(sessionId, msg);
        this.buffer.saveSession(info);
        this.sendToApp({
          type: `sdk:${msg.type === "tool_use" ? "message" : msg.type}`,
          sessionId,
          message: msg,
        });
      });
      this.sessions.set(sessionId, runner);
    }

    info.status = "active";
    this.buffer.saveSession(info);
    await runner.run(text);
    info.status = "paused";
    this.buffer.saveSession(info);
  }

  handleAppMessage(msg: any): void {
    if (this.approvalBridge.handleAppMessage(msg)) return;

    if (msg.type === "interrupt" && msg.sessionId) {
      const runner = this.sessions.get(msg.sessionId);
      runner?.interrupt();
    }
  }

  listSessions(): SessionInfo[] {
    return Array.from(this.sessionInfos.values()).sort(
      (a, b) => b.lastActivity - a.lastActivity
    );
  }

  killSession(sessionId: string): void {
    const runner = this.sessions.get(sessionId);
    runner?.interrupt();
    this.sessions.delete(sessionId);

    const info = this.sessionInfos.get(sessionId);
    if (info) {
      info.status = "completed";
      this.buffer.saveSession(info);
    }
  }

  getSessionMessages(sessionId: string): SDKMessage[] {
    return this.buffer.getMessages(sessionId);
  }

  shutdown(): void {
    this.approvalBridge.cancelAll();
    for (const [id, runner] of this.sessions) {
      runner.interrupt();
    }
    this.sessions.clear();
    this.buffer.close();
  }
}
