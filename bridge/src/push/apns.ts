import https from "https";

export interface PushConfig {
  deviceToken: string;
  bundleId: string;
}

export class PushService {
  private config: PushConfig | null = null;

  configure(config: PushConfig): void {
    this.config = config;
  }

  get isConfigured(): boolean {
    return this.config !== null;
  }

  async sendNotification(title: string, body: string, data?: Record<string, string>): Promise<void> {
    if (!this.config) return;

    const payload = {
      aps: {
        alert: { title, body },
        sound: "default",
        "mutable-content": 1,
      },
      ...(data || {}),
    };

    console.log(`[push] Would send APNs notification: "${title}" — "${body}"`);
    console.log(`[push] To device: ${this.config.deviceToken.slice(0, 12)}...`);
    console.log(`[push] Payload:`, JSON.stringify(payload).slice(0, 200));
  }

  async notifyTaskComplete(sessionName: string): Promise<void> {
    await this.sendNotification(
      "Task Complete",
      `"${sessionName}" has finished running.`,
      { type: "task_complete" }
    );
  }

  async notifyApprovalNeeded(sessionName: string, toolName: string): Promise<void> {
    await this.sendNotification(
      "Approval Needed",
      `"${sessionName}" wants to run: ${toolName}`,
      { type: "approval_needed" }
    );
  }

  async notifyError(sessionName: string, error: string): Promise<void> {
    await this.sendNotification(
      "Error",
      `"${sessionName}": ${error.slice(0, 100)}`,
      { type: "error" }
    );
  }
}
