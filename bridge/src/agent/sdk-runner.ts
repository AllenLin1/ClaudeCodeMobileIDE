import { EventEmitter } from "events";

export interface SDKMessage {
  type: "text" | "tool_use" | "tool_result" | "result" | "error";
  sessionId: string;
  content?: string;
  toolName?: string;
  toolInput?: any;
  toolResult?: any;
  isStreaming?: boolean;
}

export interface ToolApprovalRequest {
  sessionId: string;
  toolName: string;
  input: any;
}

export interface SDKRunnerOptions {
  model?: string;
  cwd: string;
  sessionId: string;
  allowedTools?: string[];
  onApprovalNeeded: (req: ToolApprovalRequest) => Promise<boolean>;
}

export class SDKRunner extends EventEmitter {
  private opts: SDKRunnerOptions;
  private abortController: AbortController | null = null;
  private _isRunning = false;

  constructor(opts: SDKRunnerOptions) {
    super();
    this.opts = opts;
  }

  get isRunning(): boolean {
    return this._isRunning;
  }

  get sessionId(): string {
    return this.opts.sessionId;
  }

  async run(prompt: string): Promise<void> {
    this._isRunning = true;
    this.abortController = new AbortController();

    try {
      const queryFn = await this.loadQueryFunction();
      if (queryFn) {
        await this.runWithSDK(queryFn, prompt);
      } else {
        this.runSimulated(prompt);
      }
    } catch (err: any) {
      if (err.name === "AbortError") return;
      this.emit("message", {
        type: "error",
        sessionId: this.opts.sessionId,
        content: err.message || "Unknown error",
      } satisfies SDKMessage);
    } finally {
      this._isRunning = false;
      this.abortController = null;
    }
  }

  interrupt(): void {
    this.abortController?.abort();
  }

  private async loadQueryFunction(): Promise<((...args: any[]) => any) | null> {
    // Try @anthropic-ai/claude-agent-sdk first (current name)
    try {
      const sdk = await import("@anthropic-ai/claude-agent-sdk");
      const fn = sdk.query || sdk.default?.query;
      if (typeof fn === "function") {
        console.log("[sdk] Loaded @anthropic-ai/claude-agent-sdk");
        return fn;
      }
    } catch {}

    // Try @anthropic-ai/claude-code (older name)
    try {
      const sdk = await import("@anthropic-ai/claude-code");
      const fn = sdk.query || sdk.default?.query;
      if (typeof fn === "function") {
        console.log("[sdk] Loaded @anthropic-ai/claude-code");
        return fn;
      }
    } catch {}

    console.log("[sdk] No Claude SDK found. Install with: npm install @anthropic-ai/claude-agent-sdk");
    return null;
  }

  private async runWithSDK(queryFn: (...args: any[]) => any, prompt: string): Promise<void> {
    console.log(`[sdk] Running query: "${prompt.slice(0, 80)}"`);

    const result = queryFn({
      prompt,
      abortController: this.abortController,
      options: {
        cwd: this.opts.cwd,
        ...(this.opts.model && this.opts.model !== "default" ? { model: this.opts.model } : {}),
        allowedTools: this.opts.allowedTools || [
          "Read", "Write", "Edit", "Bash", "Glob", "Grep",
        ],
      },
    });

    for await (const message of result) {
      if (this.abortController?.signal.aborted) break;

      const mapped = this.mapMessage(message);
      if (mapped) {
        this.emit("message", mapped);
      }
    }

    this.emit("message", {
      type: "result",
      sessionId: this.opts.sessionId,
      content: "Task completed",
    } satisfies SDKMessage);
  }

  private mapMessage(raw: any): SDKMessage | null {
    if (!raw) return null;

    // Handle different SDK message formats
    if (raw.type === "assistant" && raw.message) {
      const content = raw.message.content;
      if (Array.isArray(content)) {
        for (const block of content) {
          if (block.type === "text") {
            return {
              type: "text",
              sessionId: this.opts.sessionId,
              content: block.text,
            };
          }
          if (block.type === "tool_use") {
            return {
              type: "tool_use",
              sessionId: this.opts.sessionId,
              toolName: block.name,
              toolInput: block.input,
            };
          }
        }
      }
      if (typeof content === "string") {
        return { type: "text", sessionId: this.opts.sessionId, content };
      }
    }

    if (raw.type === "result") {
      return {
        type: "result",
        sessionId: this.opts.sessionId,
        content: typeof raw.result === "string" ? raw.result : JSON.stringify(raw.result),
      };
    }

    // Direct text messages
    if (typeof raw === "string") {
      return { type: "text", sessionId: this.opts.sessionId, content: raw };
    }

    return null;
  }

  private runSimulated(prompt: string): void {
    this.emit("message", {
      type: "text",
      sessionId: this.opts.sessionId,
      content: `[Bridge] Received prompt: "${prompt.slice(0, 100)}"\n\nClaude Agent SDK is not installed. Install it with:\n  npm install @anthropic-ai/claude-agent-sdk\n\nThe bridge will relay messages once the SDK is available.`,
    } satisfies SDKMessage);

    this.emit("message", {
      type: "result",
      sessionId: this.opts.sessionId,
      content: "SDK not available — running in simulation mode",
    } satisfies SDKMessage);
  }
}
