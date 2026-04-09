# CodePilot

Remote control Claude Code from your iPhone. Native iOS app with E2E encryption, Relay architecture, and subscription management.

## Architecture

```
iOS App (SwiftUI) <--WSS--> Relay (CF Durable Objects) <--WSS--> Desktop Bridge (Agent SDK)
                               |
                     Licensing (CF Workers + KV)
                               |
                       RevenueCat (Subscriptions)
```

- **iOS App**: Native SwiftUI, URLSessionWebSocketTask, SwiftData, CryptoKit E2E
- **Relay**: Cloudflare Durable Objects — forwards encrypted blobs, buffers offline messages
- **Bridge**: Node.js CLI via `npx codepilot-bridge` — Claude Agent SDK, tweetnacl E2E, SQLite
- **Licensing**: Cloudflare Workers + KV — RS256 JWT, usage counting, RevenueCat webhooks

## Project Structure

```
├── server/          Cloudflare Workers + Durable Objects
│   └── src/
│       ├── index.ts       Router (auth, renew, usage, webhook, relay)
│       ├── licensing.ts   JWT auth, tier enforcement, usage counting
│       ├── relay.ts       RelayRoom Durable Object (WS relay + offline buffer)
│       ├── webhook.ts     RevenueCat webhook handler
│       └── jwt.ts         RS256 sign/verify (Web Crypto API)
│
├── bridge/          Desktop Bridge (npm package)
│   ├── bin/cli.js         CLI entry point
│   └── src/
│       ├── index.ts         Main Bridge class
│       ├── relay-client.ts  WebSocket relay connection
│       ├── agent/           Agent SDK runner + approval bridge
│       ├── auth/            JWT validator + tier enforcer
│       ├── session/         Multi-session manager + SQLite buffer
│       ├── file/            File browser + Git integration
│       ├── crypto/          E2E encryption (tweetnacl)
│       ├── push/            APNs notifications
│       ├── pairing/         QR code generation
│       └── autostart/       OS-level autostart (macOS/Linux/Windows)
│
└── ios/             iOS App (Xcode project)
    └── CodePilot/
        ├── App.swift          SwiftUI entry point
        ├── Design/            Theme, animations, reusable components
        ├── Features/          6 feature modules (Onboarding, Sessions, Chat, Files, Settings, Paywall)
        ├── Services/          Relay, Licensing, RevenueCat, Crypto, Push
        ├── Models/            SwiftData models + AppState
        └── Utilities/         Message mapper, syntax highlighter
```

## Quick Start

### 1. Deploy Server

```bash
cd server
npm install
# Generate RS256 keys
npx jose generate-key-pair RS256
# Set secrets
wrangler secret put JWT_PRIVATE_KEY_PEM
wrangler secret put JWT_PUBLIC_KEY_PEM
wrangler secret put REVENUECAT_WEBHOOK_SECRET
# Deploy
wrangler deploy
```

### 2. Run Bridge

```bash
npx codepilot-bridge start --server https://your-worker.workers.dev
```

### 3. Build iOS App

Open `ios/` in Xcode, add RevenueCat SPM package, build & run.

## Tech Decisions (Validated by Competitors)

| Decision | Our Choice | Validation |
|----------|-----------|------------|
| Agent interaction | Claude Agent SDK | Omnara v1 CLI wrapper was abandoned; v2 uses SDK |
| Relay architecture | Durable Objects | Happy + Omnara both use relay servers |
| Subscriptions | RevenueCat | Happy + Omnara both use RevenueCat |
| E2E encryption | NaCl (tweetnacl / CryptoKit) | Happy uses identical crypto primitives |
| iOS framework | SwiftUI native | Differentiator vs all RN competitors |

## Pricing

- **Free**: 10 lifetime conversations, 1 session, 1 project
- **Pro**: $4.99/month or $29.99/year — unlimited everything
