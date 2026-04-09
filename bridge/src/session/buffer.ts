import Database from "better-sqlite3";
import type { SDKMessage } from "../agent/sdk-runner";
import type { SessionInfo } from "./manager";

export class SessionBuffer {
  private db: Database.Database;

  constructor(dbPath: string) {
    this.db = new Database(dbPath);
    this.db.pragma("journal_mode = WAL");
    this.init();
  }

  private init(): void {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        cwd TEXT NOT NULL,
        model TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        created_at INTEGER NOT NULL,
        last_activity INTEGER NOT NULL,
        last_message TEXT
      );

      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        type TEXT NOT NULL,
        content TEXT,
        tool_name TEXT,
        tool_input TEXT,
        tool_result TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id)
      );

      CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id, created_at);
    `);
  }

  saveSession(info: SessionInfo): void {
    this.db
      .prepare(
        `INSERT OR REPLACE INTO sessions (id, name, cwd, model, status, created_at, last_activity, last_message)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .run(
        info.id,
        info.name,
        info.cwd,
        info.model,
        info.status,
        info.createdAt,
        info.lastActivity,
        info.lastMessage || null
      );
  }

  saveMessage(sessionId: string, msg: SDKMessage): void {
    this.db
      .prepare(
        `INSERT INTO messages (session_id, type, content, tool_name, tool_input, tool_result, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`
      )
      .run(
        sessionId,
        msg.type,
        msg.content || null,
        msg.toolName || null,
        msg.toolInput ? JSON.stringify(msg.toolInput) : null,
        msg.toolResult ? JSON.stringify(msg.toolResult) : null,
        Date.now()
      );
  }

  getAllSessions(): SessionInfo[] {
    const rows = this.db
      .prepare("SELECT * FROM sessions ORDER BY last_activity DESC")
      .all() as any[];

    return rows.map((r) => ({
      id: r.id,
      name: r.name,
      cwd: r.cwd,
      model: r.model,
      status: r.status,
      createdAt: r.created_at,
      lastActivity: r.last_activity,
      lastMessage: r.last_message,
    }));
  }

  getMessages(sessionId: string, limit = 200): SDKMessage[] {
    const rows = this.db
      .prepare(
        "SELECT * FROM messages WHERE session_id = ? ORDER BY created_at DESC LIMIT ?"
      )
      .all(sessionId, limit) as any[];

    return rows.reverse().map((r) => ({
      type: r.type,
      sessionId: r.session_id,
      content: r.content,
      toolName: r.tool_name,
      toolInput: r.tool_input ? JSON.parse(r.tool_input) : undefined,
      toolResult: r.tool_result ? JSON.parse(r.tool_result) : undefined,
    }));
  }

  close(): void {
    this.db.close();
  }
}
