import * as path from "path";
import * as os from "os";
import * as fs from "fs";
import dotenv from "dotenv";
import { E2ECrypto } from "./crypto/e2e";
import { RelayClient } from "./relay-client";
import { JWTValidator, type JWTClaims } from "./auth/jwt-validator";
import { TierEnforcer } from "./auth/tier-enforcer";
import { SessionManager } from "./session/manager";
import { FileBrowser } from "./file/browser";
import { GitService } from "./file/git";
import { PushService } from "./push/apns";
import {
  generatePairingCode,
  generateRoomId,
  displayQR,
  type PairingInfo,
} from "./pairing/qr";

dotenv.config();

export interface BridgeConfig {
  serverUrl: string;
  roomId?: string;
  publicKeyPem?: string;
  daemon?: boolean;
}

const CONFIG_DIR = path.join(os.homedir(), ".codepilot");
const CONFIG_FILE = path.join(CONFIG_DIR, "config.json");
const DB_FILE = path.join(CONFIG_DIR, "sessions.db");

function ensureConfigDir(): void {
  fs.mkdirSync(CONFIG_DIR, { recursive: true });
}

function loadConfig(): any {
  try {
    return JSON.parse(fs.readFileSync(CONFIG_FILE, "utf-8"));
  } catch {
    return {};
  }
}

function saveConfig(data: any): void {
  ensureConfigDir();
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(data, null, 2));
}

export class Bridge {
  private relay: RelayClient | null = null;
  private crypto: E2ECrypto;
  private jwtValidator: JWTValidator | null = null;
  private enforcer: TierEnforcer | null = null;
  private sessionManager: SessionManager | null = null;
  private fileBrowser: FileBrowser;
  private gitService: GitService;
  private pushService: PushService;
  private config: BridgeConfig;
  private currentJWT: string | null = null;

  constructor(config: BridgeConfig) {
    this.config = config;
    this.fileBrowser = new FileBrowser();
    this.gitService = new GitService();
    this.pushService = new PushService();

    ensureConfigDir();
    const saved = loadConfig();

    if (saved.secretKey && saved.publicKey) {
      this.crypto = E2ECrypto.fromBase64(saved.publicKey, saved.secretKey);
    } else {
      this.crypto = new E2ECrypto();
      saved.publicKey = this.crypto.getPublicKey();
      saved.secretKey = this.crypto.getSecretKey();
      saveConfig(saved);
    }

    if (saved.roomId && !config.roomId) {
      config.roomId = saved.roomId;
    }
  }

  async start(): Promise<void> {
    const roomId = this.config.roomId || generateRoomId();
    const saved = loadConfig();
    saved.roomId = roomId;
    saved.serverUrl = this.config.serverUrl;
    saveConfig(saved);

    if (this.config.publicKeyPem) {
      this.jwtValidator = new JWTValidator(this.config.publicKeyPem);
    } else {
      try {
        const resp = await fetch(`${this.config.serverUrl}/public-key`);
        const data = (await resp.json()) as { public_key: string };
        if (data.public_key) {
          this.jwtValidator = new JWTValidator(data.public_key);
        }
      } catch (err) {
        console.warn("[bridge] Could not fetch public key:", err);
      }
    }

    this.sessionManager = new SessionManager({
      dbPath: DB_FILE,
      sendToApp: (msg) => this.sendToApp(msg),
      maxSessions: 5,
    });

    this.relay = new RelayClient({
      serverUrl: this.config.serverUrl.replace("https://", "wss://").replace("http://", "ws://"),
      roomId,
      role: "bridge",
      crypto: this.crypto,
      onMessage: (msg) => this.handleAppMessage(msg),
      onConnected: () => console.log("[bridge] Connected to relay"),
      onDisconnected: () => console.log("[bridge] Disconnected from relay"),
    });

    const pairingCode = generatePairingCode();
    const pairingInfo: PairingInfo = {
      pairingCode,
      roomId,
      bridgePublicKey: this.crypto.getPublicKey(),
      serverUrl: this.config.serverUrl,
    };

    console.log(`[bridge] Registering pairing code ${pairingCode} with server...`);
    const regUrl = `${this.config.serverUrl}/pair/register`;
    const regPayload = JSON.stringify({
      code: pairingCode,
      roomId,
      bridgePublicKey: this.crypto.getPublicKey(),
      serverUrl: this.config.serverUrl,
    });
    let registered = false;
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        const resp = await fetch(regUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: regPayload,
        });
        if (resp.ok) {
          console.log(`[bridge] Pairing code registered OK`);
          registered = true;
          break;
        }
        const text = await resp.text();
        console.warn(`[bridge] Register attempt ${attempt} failed: ${resp.status} ${text}`);
      } catch (err: any) {
        console.warn(`[bridge] Register attempt ${attempt} error: ${err.message}`);
      }
      if (attempt < 3) await new Promise(r => setTimeout(r, 2000));
    }
    if (!registered) {
      console.error("[bridge] WARNING: Could not register pairing code. App may not be able to connect by code.");
      console.error("[bridge] Room ID for manual connection:", roomId);
    }

    displayQR(pairingInfo);
    this.relay.connect();

    console.log("[bridge] Waiting for app connection...\n");
  }

  private sendToApp(msg: any): void {
    this.relay?.send(msg);
  }

  private async handleAppMessage(msg: any): Promise<void> {
    console.log(`[bridge] Received from app: ${msg.type || JSON.stringify(msg).slice(0, 80)}`);
    try {
      if (msg.type === "auth") {
        await this.handleAuth(msg);
        return;
      }

      if (msg.type === "pair") {
        this.handlePairing(msg);
        return;
      }

      if (!this.enforcer) {
        console.log("[bridge] No auth yet, auto-granting dev mode access");
        this.enforcer = new TierEnforcer({
          sub: "dev",
          tier: "pro",
          limits: {
            max_sessions: 5,
            max_projects: -1,
            remaining_free: -1,
            features: ["multi_session", "git", "file_browser", "push", "model_select"],
          },
          device_pair_id: "",
          iat: Math.floor(Date.now() / 1000),
          exp: Math.floor(Date.now() / 1000) + 86400,
        });
      }

      if (this.enforcer.isExpired) {
        this.sendToApp({
          type: "tier:limit",
          feature: "subscription",
          message: "Subscription expired. Please renew to continue.",
        });
        return;
      }

      switch (msg.type) {
        case "prompt":
          await this.handlePrompt(msg);
          break;
        case "approve":
        case "answer":
        case "interrupt":
          this.sessionManager?.handleAppMessage(msg);
          break;
        case "session:create":
          this.handleCreateSession(msg);
          break;
        case "session:resume":
          await this.handleResumeSession(msg);
          break;
        case "session:list":
          this.handleListSessions();
          break;
        case "session:kill":
          this.sessionManager?.killSession(msg.sessionId);
          break;
        case "file:list":
          await this.handleFileList(msg);
          break;
        case "file:read":
          await this.handleFileRead(msg);
          break;
        case "git:status":
          await this.handleGitStatus(msg);
          break;
        case "git:diff":
          await this.handleGitDiff(msg);
          break;
        case "git:log":
          await this.handleGitLog(msg);
          break;
        case "push:register":
          this.handlePushRegister(msg);
          break;
        default:
          console.warn("[bridge] Unknown message type:", msg.type);
          this.sendToApp({
            type: "error",
            code: "UNKNOWN_TYPE",
            message: `Unknown message type: ${msg.type}`,
          });
      }
    } catch (err: any) {
      console.error("[bridge] Error handling message:", err);
      this.sendToApp({
        type: "error",
        code: "BRIDGE_ERROR",
        message: err.message || "Unknown bridge error",
      });
    }
  }

  private async handleAuth(msg: any): Promise<void> {
    if (!msg.token) {
      this.sendToApp({ type: "auth:required" });
      return;
    }

    if (!this.jwtValidator) {
      console.warn("[bridge] No JWT validator — accepting all tokens in dev mode");
      this.currentJWT = msg.token;
      this.enforcer = new TierEnforcer({
        sub: "dev",
        tier: "pro",
        limits: {
          max_sessions: 5,
          max_projects: -1,
          remaining_free: -1,
          features: ["multi_session", "git", "file_browser", "push", "model_select"],
        },
        device_pair_id: "",
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 3600,
      });
      this.sendToApp({ type: "auth:success", tier: "pro" });
      return;
    }

    const claims = await this.jwtValidator.validate(msg.token);
    if (!claims) {
      this.sendToApp({ type: "auth:failed", reason: "Invalid or expired token" });
      return;
    }

    this.currentJWT = msg.token;
    this.enforcer = new TierEnforcer(claims);

    if (this.sessionManager) {
      this.sessionManager = new SessionManager({
        dbPath: DB_FILE,
        sendToApp: (m) => this.sendToApp(m),
        maxSessions: claims.limits.max_sessions,
      });
    }

    this.sendToApp({ type: "auth:success", tier: claims.tier });
  }

  private handlePairing(msg: any): void {
    if (msg.appPublicKey) {
      this.crypto.deriveSharedKey(msg.appPublicKey);
      console.log("[bridge] E2E keys exchanged with app");
      this.sendToApp({
        type: "pair:success",
        bridgePublicKey: this.crypto.getPublicKey(),
      });
    }
  }

  private handleCreateSession(msg: any): void {
    if (!this.enforcer?.canStartNewSession(
      this.sessionManager?.listSessions().filter((s) => s.status === "active").length || 0
    )) {
      this.sendToApp({
        type: "tier:limit",
        feature: "multi_session",
        message: "Session limit reached. Upgrade to Pro.",
      });
      return;
    }

    this.sessionManager?.createSession(
      msg.name || "Untitled",
      msg.cwd || process.cwd(),
      msg.model || "default"
    );
  }

  private async handleResumeSession(msg: any): Promise<void> {
    const messages = this.sessionManager?.getSessionMessages(msg.sessionId) || [];
    this.sendToApp({
      type: "session:history",
      sessionId: msg.sessionId,
      messages,
    });
  }

  private async handlePrompt(msg: any): Promise<void> {
    console.log(`[bridge] handlePrompt: sessionId=${msg.sessionId}, text="${(msg.text || "").slice(0, 50)}"`);

    if (!this.enforcer?.canSendPrompt()) {
      this.sendToApp({
        type: "tier:limit",
        feature: "prompt",
        message: "Free tier limit reached. Upgrade to Pro for unlimited usage.",
      });
      return;
    }

    if (!this.sessionManager) {
      console.error("[bridge] SessionManager not initialized");
      this.sendToApp({
        type: "error",
        code: "NO_SESSION_MANAGER",
        message: "Bridge not ready. Please restart the bridge.",
      });
      return;
    }

    const sessions = this.sessionManager.listSessions();
    const exists = sessions.find(s => s.id === msg.sessionId);
    if (!exists) {
      console.log(`[bridge] Session ${msg.sessionId} not found, auto-creating`);
      this.sessionManager.createSession(
        msg.name || "Chat",
        msg.cwd || process.cwd(),
        msg.model || "default"
      );
      const newSessions = this.sessionManager.listSessions();
      const created = newSessions[0];
      if (created) {
        console.log(`[bridge] Auto-created session: ${created.id}`);
        msg.sessionId = created.id;
        this.sendToApp({
          type: "session:created",
          sessionId: created.id,
          originalSessionId: msg.sessionId,
          name: created.name,
        });
      }
    }

    try {
      await this.sessionManager.sendPrompt(msg.sessionId, msg.text);
    } catch (err: any) {
      console.error(`[bridge] sendPrompt error:`, err.message);
      this.sendToApp({
        type: "sdk:result",
        sessionId: msg.sessionId,
        message: {
          type: "result",
          sessionId: msg.sessionId,
          content: `Bridge received your message: "${msg.text}"\n\nClaude Agent SDK is not installed. To enable AI responses:\n  cd bridge && npm install @anthropic-ai/claude-code\n  export ANTHROPIC_API_KEY=sk-ant-...\n  node bin/cli.js start --server http://localhost:8787`,
        },
      });
    }
  }

  private handleListSessions(): void {
    const sessions = this.sessionManager?.listSessions() || [];
    this.sendToApp({ type: "session:list", sessions });
  }

  private async handleFileList(msg: any): Promise<void> {
    if (!this.enforcer?.canBrowseFiles()) {
      this.sendToApp({
        type: "tier:limit",
        feature: "file_browser",
        message: "File browser is a Pro feature.",
      });
      return;
    }
    const files = await this.fileBrowser.list(msg.path);
    this.sendToApp({ type: "file:list", path: msg.path, files });
  }

  private async handleFileRead(msg: any): Promise<void> {
    if (!this.enforcer?.canBrowseFiles()) {
      this.sendToApp({
        type: "tier:limit",
        feature: "file_browser",
        message: "File browser is a Pro feature.",
      });
      return;
    }
    const result = await this.fileBrowser.read(msg.path);
    this.sendToApp({ type: "file:content", path: msg.path, ...result });
  }

  private async handleGitStatus(msg: any): Promise<void> {
    if (!this.enforcer?.canUseGit()) {
      this.sendToApp({
        type: "tier:limit",
        feature: "git",
        message: "Git integration is a Pro feature.",
      });
      return;
    }
    const status = await this.gitService.status(msg.cwd);
    this.sendToApp({ type: "git:status", cwd: msg.cwd, status });
  }

  private async handleGitDiff(msg: any): Promise<void> {
    if (!this.enforcer?.canUseGit()) {
      this.sendToApp({
        type: "tier:limit",
        feature: "git",
        message: "Git integration is a Pro feature.",
      });
      return;
    }
    const diff = await this.gitService.diff(msg.cwd);
    this.sendToApp({ type: "git:diff", cwd: msg.cwd, diff });
  }

  private async handleGitLog(msg: any): Promise<void> {
    if (!this.enforcer?.canUseGit()) {
      this.sendToApp({
        type: "tier:limit",
        feature: "git",
        message: "Git integration is a Pro feature.",
      });
      return;
    }
    const commits = await this.gitService.log(msg.cwd, msg.limit || 20);
    this.sendToApp({ type: "git:log", cwd: msg.cwd, commits });
  }

  private handlePushRegister(msg: any): void {
    if (msg.deviceToken && msg.bundleId) {
      this.pushService.configure({
        deviceToken: msg.deviceToken,
        bundleId: msg.bundleId,
      });
      console.log("[bridge] Push notification registered");
    }
  }

  shutdown(): void {
    this.sessionManager?.shutdown();
    this.relay?.close();
  }
}
