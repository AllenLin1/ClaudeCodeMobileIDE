import qrcode from "qrcode-terminal";
import crypto from "crypto";

export interface PairingInfo {
  pairingCode: string;
  roomId: string;
  bridgePublicKey: string;
  serverUrl: string;
}

export function generatePairingCode(): string {
  return crypto.randomBytes(3).toString("hex").toUpperCase();
}

export function generateRoomId(): string {
  return crypto.randomUUID();
}

export function buildPairingUrl(info: PairingInfo): string {
  const params = new URLSearchParams({
    code: info.pairingCode,
    room: info.roomId,
    pk: info.bridgePublicKey,
    server: info.serverUrl,
  });
  return `codepilot://pair?${params.toString()}`;
}

export function displayQR(info: PairingInfo): void {
  const url = buildPairingUrl(info);

  console.log("\n╔══════════════════════════════════════╗");
  console.log("║       CodePilot Bridge Ready          ║");
  console.log("╠══════════════════════════════════════╣");
  console.log(`║  Pairing Code:  ${info.pairingCode}              ║`);
  console.log("║                                        ║");
  console.log("║  Scan the QR code with CodePilot App  ║");
  console.log("║  or enter the pairing code manually.   ║");
  console.log("╚══════════════════════════════════════╝\n");

  qrcode.generate(url, { small: true }, (code: string) => {
    console.log(code);
  });

  console.log(`\nPairing URL: ${url}\n`);
}
