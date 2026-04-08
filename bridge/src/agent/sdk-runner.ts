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

/**
 * Wraps Claude Agent SDK query() calls.
 * 
 * NOTE: The actual @anthropic-ai/claude-agent-sdk import is deferred to runtime
 * because the package may not be installed in all environments.
 * When the SDK is not available, this falls back to a simulated mode.
 */
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
      const sdk = await this.loadSDK();
      if (sdk) {
        await this.runWithSDK(sdk, prompt);
      } else {
        await this.runSimulated(prompt);
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

  private async loadSDK(): Promise<any> {
    try {
      return await import("@anthropic-ai/claude-code");
    } catch {
      try {
        return await import("@anthropic-ai/claude-agent-sdk");
      } catch {
        return null;
      }
    }
  }

  private async runWithSDK(sdk: any, prompt: string): Promise<void> {
    const queryFn = sdk.query || sdk.default?.query;
    if (!queryFn) {
      return this.runSimulated(prompt);
    }

    const options: any = {
      prompt,
      abortController: this.abortController,
      options: {
        cwd: this.opts.cwd,
        model: this.opts.model,
        allowedTools: this.opts.allowedTools || [
          "Read",
          "Write",
          "Edit",
          "Bash",
          "Glob",
          "Grep",
        ],
      },
    };

    if (this.opts.sessionId) {
      options.options.resume = this.opts.sessionId;
    }

    options.options.canUseTool = async (
      toolName: string,
      input: any
    ): Promise<{ behavior: string }> => {
      const allowed = await this.opts.onApprovalNeeded({
        sessionId: this.opts.sessionId,
        toolName,
        input,
      });
      return { behavior: allowed ? "allow" : "deny" };
    };

    for await (const message of queryFn(options)) {
      if (this.abortController?.signal.aborted) break;

      const sdkMsg = this.mapSDKMessage(message);
      if (sdkMsg) {
        this.emit("message", sdkMsg);
      }
    }

    this.emit("message", {
      type: "result",
      sessionId: this.opts.sessionId,
      content: "Task completed",
    } satisfies SDKMessage);
  }

  private mapSDKMessage(raw: any): SDKMessage | null {
    if (!raw) return null;

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
        return {
          type: "text",
          sessionId: this.opts.sessionId,
          content,
        };
      }
    }

    if (raw.type === "result") {
      return {
        type: "result",
        sessionId: this.opts.sessionId,
        content:
          typeof raw.result === "string"
            ? raw.result
            : JSON.stringify(raw.result),
      };
    }

    return null;
  }

  private async runSimulated(prompt: string): Promise<void> {
    this.emit("message", {
      type: "text",
      sessionId: this.opts.sessionId,
      content: `[Bridge] Received prompt: "${prompt.slice(0, 100)}..."\n\nClaude Agent SDK is not installed. Install it with:\n  npm install @anthropic-ai/claude-code\n\nThe bridge will relay messages once the SDK is available.`,
    } satisfies SDKMessage);

    this.emit("message", {
      type: "result",
      sessionId: this.opts.sessionId,
      content: "SDK not available — running in simulation mode",
    } satisfies SDKMessage);
  }
}
