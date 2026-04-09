import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { SessionBuffer } from "../src/session/buffer";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

describe("SessionBuffer (SQLite)", () => {
  let buffer: SessionBuffer;
  let dbPath: string;

  beforeEach(() => {
    dbPath = path.join(os.tmpdir(), `codepilot-test-${Date.now()}.db`);
    buffer = new SessionBuffer(dbPath);
  });

  afterEach(() => {
    buffer.close();
    try { fs.unlinkSync(dbPath); } catch {}
    try { fs.unlinkSync(dbPath + "-wal"); } catch {}
    try { fs.unlinkSync(dbPath + "-shm"); } catch {}
  });

  it("should save and retrieve a session", () => {
    buffer.saveSession({
      id: "sess_1",
      name: "API Refactor",
      cwd: "/home/user/project",
      model: "claude-opus-4-6-20260401",
      status: "active",
      createdAt: Date.now(),
      lastActivity: Date.now(),
      lastMessage: "Working on routes...",
    });

    const sessions = buffer.getAllSessions();
    expect(sessions).toHaveLength(1);
    expect(sessions[0].id).toBe("sess_1");
    expect(sessions[0].name).toBe("API Refactor");
    expect(sessions[0].model).toBe("claude-opus-4-6-20260401");
    expect(sessions[0].status).toBe("active");
  });

  it("should update an existing session", () => {
    const now = Date.now();
    buffer.saveSession({
      id: "sess_1",
      name: "Test",
      cwd: "/tmp",
      model: "default",
      status: "active",
      createdAt: now,
      lastActivity: now,
    });

    buffer.saveSession({
      id: "sess_1",
      name: "Test",
      cwd: "/tmp",
      model: "default",
      status: "paused",
      createdAt: now,
      lastActivity: now + 1000,
      lastMessage: "Done",
    });

    const sessions = buffer.getAllSessions();
    expect(sessions).toHaveLength(1);
    expect(sessions[0].status).toBe("paused");
    expect(sessions[0].lastMessage).toBe("Done");
  });

  it("should save and retrieve messages", () => {
    buffer.saveSession({
      id: "sess_1",
      name: "Test",
      cwd: "/tmp",
      model: "default",
      status: "active",
      createdAt: Date.now(),
      lastActivity: Date.now(),
    });

    buffer.saveMessage("sess_1", {
      type: "text",
      sessionId: "sess_1",
      content: "Hello Claude",
    });

    buffer.saveMessage("sess_1", {
      type: "tool_use",
      sessionId: "sess_1",
      toolName: "Read",
      toolInput: { file_path: "/src/main.ts" },
    });

    buffer.saveMessage("sess_1", {
      type: "result",
      sessionId: "sess_1",
      content: "Task complete",
    });

    const messages = buffer.getMessages("sess_1");
    expect(messages).toHaveLength(3);
    expect(messages[0].type).toBe("text");
    expect(messages[0].content).toBe("Hello Claude");
    expect(messages[1].type).toBe("tool_use");
    expect(messages[1].toolName).toBe("Read");
    expect(messages[1].toolInput).toEqual({ file_path: "/src/main.ts" });
    expect(messages[2].type).toBe("result");
  });

  it("should return messages in chronological order", () => {
    buffer.saveSession({
      id: "s1",
      name: "T",
      cwd: "/",
      model: "d",
      status: "active",
      createdAt: Date.now(),
      lastActivity: Date.now(),
    });

    for (let i = 0; i < 5; i++) {
      buffer.saveMessage("s1", {
        type: "text",
        sessionId: "s1",
        content: `Message ${i}`,
      });
    }

    const messages = buffer.getMessages("s1");
    expect(messages).toHaveLength(5);
    expect(messages[0].content).toBe("Message 0");
    expect(messages[4].content).toBe("Message 4");
  });

  it("should respect limit parameter", () => {
    buffer.saveSession({
      id: "s1",
      name: "T",
      cwd: "/",
      model: "d",
      status: "active",
      createdAt: Date.now(),
      lastActivity: Date.now(),
    });

    for (let i = 0; i < 10; i++) {
      buffer.saveMessage("s1", {
        type: "text",
        sessionId: "s1",
        content: `Msg ${i}`,
      });
    }

    const messages = buffer.getMessages("s1", 3);
    expect(messages).toHaveLength(3);
    // Most recent 3 messages
    expect(messages[0].content).toBe("Msg 7");
    expect(messages[2].content).toBe("Msg 9");
  });

  it("should return empty for unknown session", () => {
    expect(buffer.getMessages("nonexistent")).toEqual([]);
    expect(buffer.getAllSessions()).toEqual([]);
  });

  it("should order sessions by last_activity DESC", () => {
    const now = Date.now();
    buffer.saveSession({
      id: "old",
      name: "Old",
      cwd: "/",
      model: "d",
      status: "paused",
      createdAt: now - 10000,
      lastActivity: now - 10000,
    });
    buffer.saveSession({
      id: "new",
      name: "New",
      cwd: "/",
      model: "d",
      status: "active",
      createdAt: now,
      lastActivity: now,
    });

    const sessions = buffer.getAllSessions();
    expect(sessions[0].id).toBe("new");
    expect(sessions[1].id).toBe("old");
  });
});
