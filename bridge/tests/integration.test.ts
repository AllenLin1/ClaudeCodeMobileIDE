import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { E2ECrypto } from "../src/crypto/e2e";
import WebSocket from "ws";

/**
 * Integration test: simulates the full App ↔ Relay ↔ Bridge message flow.
 * 
 * Requires the server to be running on localhost:8787.
 * Skip if server is not available.
 */

const SERVER_URL = "http://localhost:8787";
const WS_URL = "ws://localhost:8787";

async function isServerRunning(): Promise<boolean> {
  try {
    const resp = await fetch(`${SERVER_URL}/health`);
    return resp.ok;
  } catch {
    return false;
  }
}

function connectWs(url: string): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url);
    ws.on("open", () => resolve(ws));
    ws.on("error", reject);
    setTimeout(() => reject(new Error("WebSocket connect timeout")), 5000);
  });
}

function waitForMessage(ws: WebSocket, timeoutMs = 5000): Promise<any> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("Message timeout")), timeoutMs);
    ws.on("message", (data) => {
      const raw = data.toString();
      if (raw === "ping") {
        ws.send("pong");
        return;
      }
      clearTimeout(timer);
      try {
        resolve(JSON.parse(raw));
      } catch {
        resolve(raw);
      }
    });
  });
}

describe.skipIf(!await isServerRunning())("End-to-End Integration", () => {
  let bridgeWs: WebSocket;
  let appWs: WebSocket;
  let roomId: string;
  const bridgeCrypto = new E2ECrypto();
  const appCrypto = new E2ECrypto();
  
  beforeAll(async () => {
    // Register a pairing code
    roomId = `test-room-${Date.now()}`;
    const code = "TEST99";
    
    const resp = await fetch(`${SERVER_URL}/pair/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        code,
        roomId,
        bridgePublicKey: bridgeCrypto.getPublicKey(),
        serverUrl: SERVER_URL,
      }),
    });
    expect(resp.ok).toBe(true);
    
    // Verify lookup works
    const lookupResp = await fetch(`${SERVER_URL}/pair/${code}`);
    expect(lookupResp.ok).toBe(true);
    const lookupData = await lookupResp.json() as any;
    expect(lookupData.roomId).toBe(roomId);
    
    // Connect bridge
    bridgeWs = await connectWs(`${WS_URL}/relay/${roomId}?role=bridge`);
    
    // Connect app
    appWs = await connectWs(`${WS_URL}/relay/${roomId}?role=app`);
  });
  
  afterAll(() => {
    bridgeWs?.close();
    appWs?.close();
  });
  
  it("should forward plain messages from app to bridge", async () => {
    const testMsg = { type: "prompt", text: "Hello", sessionId: "s1" };
    const envelope = { seq: 1, ack: 0, ts: Date.now(), plain: JSON.stringify(testMsg) };
    
    const bridgePromise = waitForMessage(bridgeWs);
    appWs.send(JSON.stringify(envelope));
    
    const received = await bridgePromise;
    expect(received.plain).toBeDefined();
    const parsed = JSON.parse(received.plain);
    expect(parsed.type).toBe("prompt");
    expect(parsed.text).toBe("Hello");
  });
  
  it("should forward plain messages from bridge to app", async () => {
    const testMsg = { type: "sdk:result", sessionId: "s1", content: "Done" };
    const envelope = { seq: 1, ack: 0, ts: Date.now(), plain: JSON.stringify(testMsg) };
    
    const appPromise = waitForMessage(appWs);
    bridgeWs.send(JSON.stringify(envelope));
    
    const received = await appPromise;
    expect(received.plain).toBeDefined();
    const parsed = JSON.parse(received.plain);
    expect(parsed.type).toBe("sdk:result");
    expect(parsed.content).toBe("Done");
  });
  
  it("should forward encrypted messages after key exchange", async () => {
    // Exchange keys
    appCrypto.deriveSharedKey(bridgeCrypto.getPublicKey());
    bridgeCrypto.deriveSharedKey(appCrypto.getPublicKey());
    
    // App sends encrypted message
    const testMsg = { type: "prompt", text: "Secret message", sessionId: "s2" };
    const encrypted = appCrypto.encrypt(JSON.stringify(testMsg));
    const envelope = { seq: 2, ack: 0, ts: Date.now(), encrypted };
    
    const bridgePromise = waitForMessage(bridgeWs);
    appWs.send(JSON.stringify(envelope));
    
    const received = await bridgePromise;
    expect(received.encrypted).toBeDefined();
    
    // Bridge decrypts
    const decrypted = bridgeCrypto.decrypt(received.encrypted);
    const parsed = JSON.parse(decrypted);
    expect(parsed.type).toBe("prompt");
    expect(parsed.text).toBe("Secret message");
  });
  
  it("should buffer messages when peer is offline", async () => {
    // Disconnect bridge
    bridgeWs.close();
    await new Promise(r => setTimeout(r, 500));
    
    // App sends while bridge is disconnected
    const testMsg = { type: "prompt", text: "Buffered msg", sessionId: "s3" };
    const envelope = { seq: 3, ack: 0, ts: Date.now(), plain: JSON.stringify(testMsg) };
    appWs.send(JSON.stringify(envelope));
    
    await new Promise(r => setTimeout(r, 500));
    
    // Bridge reconnects
    bridgeWs = await connectWs(`${WS_URL}/relay/${roomId}?role=bridge`);
    
    // Should receive buffered message
    const received = await waitForMessage(bridgeWs);
    expect(received.plain).toBeDefined();
    const parsed = JSON.parse(received.plain);
    expect(parsed.text).toBe("Buffered msg");
  });
  
  it("should handle pairing code lifecycle", async () => {
    // Register
    const code = "LIFE01";
    const resp = await fetch(`${SERVER_URL}/pair/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code, roomId: "room-lifecycle", bridgePublicKey: "pk", serverUrl: SERVER_URL }),
    });
    expect(resp.ok).toBe(true);
    
    // Lookup succeeds
    const lookup1 = await fetch(`${SERVER_URL}/pair/${code}`);
    expect(lookup1.ok).toBe(true);
    
    // Unknown code returns 404
    const lookup2 = await fetch(`${SERVER_URL}/pair/UNKNOWN`);
    expect(lookup2.status).toBe(404);
  });
});
