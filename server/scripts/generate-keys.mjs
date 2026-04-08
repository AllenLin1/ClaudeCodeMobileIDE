#!/usr/bin/env node
// Generates RS256 key pair for JWT signing.
// Run: node scripts/generate-keys.mjs
// Then set the keys as Cloudflare secrets:
//   wrangler secret put JWT_PRIVATE_KEY_PEM
//   wrangler secret put JWT_PUBLIC_KEY_PEM

import { generateKeyPair, exportPKCS8, exportSPKI } from "jose";

async function main() {
  const { publicKey, privateKey } = await generateKeyPair("RS256");
  const privatePem = await exportPKCS8(privateKey);
  const publicPem = await exportSPKI(publicKey);

  console.log("=== PRIVATE KEY (JWT_PRIVATE_KEY_PEM) ===");
  console.log(privatePem);
  console.log("=== PUBLIC KEY (JWT_PUBLIC_KEY_PEM) ===");
  console.log(publicPem);
  console.log("\nSet these as Cloudflare Worker secrets:");
  console.log('  echo "..." | wrangler secret put JWT_PRIVATE_KEY_PEM');
  console.log('  echo "..." | wrangler secret put JWT_PUBLIC_KEY_PEM');
}

main().catch(console.error);
