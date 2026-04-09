#!/usr/bin/env node
/**
 * One-shot local development setup for server.
 * Generates RS256 key pair and writes .dev.vars so `wrangler dev` works immediately.
 */
import { generateKeyPair, exportPKCS8, exportSPKI } from "jose";
import { writeFileSync, existsSync } from "fs";

async function main() {
  if (existsSync(".dev.vars")) {
    console.log("[setup] .dev.vars already exists — skipping (delete it to regenerate).");
    return;
  }

  console.log("[setup] Generating RS256 key pair...");
  const { publicKey, privateKey } = await generateKeyPair("RS256", {
    extractable: true,
  });
  const privatePem = await exportPKCS8(privateKey);
  const publicPem = await exportSPKI(publicKey);

  const devVars = [
    `JWT_PRIVATE_KEY_PEM=${JSON.stringify(privatePem)}`,
    `JWT_PUBLIC_KEY_PEM=${JSON.stringify(publicPem)}`,
    `REVENUECAT_WEBHOOK_SECRET="dev-webhook-secret"`,
  ].join("\n");

  writeFileSync(".dev.vars", devVars + "\n");
  console.log("[setup] .dev.vars written with fresh key pair.");
  console.log("[setup] You can now run: npx wrangler dev");
  console.log("");
  console.log("=== PUBLIC KEY (for bridge .env) ===");
  console.log(publicPem);
}

main().catch(console.error);
