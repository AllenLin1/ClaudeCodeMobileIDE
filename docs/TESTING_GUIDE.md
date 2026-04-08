# CodePilot Testing Guide

## 1. Automated Unit Tests

### Server Tests (JWT)

```bash
cd server
npm install
npm test
```

Tests: RS256 JWT sign/verify roundtrip, tamper rejection, expiration, malformed input, free/pro tier payloads.

### Bridge Tests (Crypto, Auth, Sessions, Approvals)

```bash
cd bridge
npm install
npm test
```

Test suites:
- **e2e-crypto**: Key pair generation, encrypt/decrypt roundtrip, large payloads, Unicode, wrong key rejection, tamper detection, key serialization
- **tier-enforcer**: Pro/Free/Expired tier feature gating, session/project limits, prompt limits
- **approval-bridge**: Tool request forwarding, approval/denial resolution, concurrent requests, cancel-all, timeout
- **session-buffer**: SQLite session CRUD, message persistence, ordering, limit, update
- **jwt-validator**: Token validation via jose, expired/tampered/garbage rejection, key caching

Run with watch mode for development:
```bash
npm run test:watch
```

---

## 2. Server Local Testing (Wrangler Dev)

### Prerequisites
- Cloudflare account (free tier is sufficient)
- `wrangler` CLI (installed as devDependency)

### Steps

```bash
cd server

# 1. Generate RS256 key pair
npx jose generate-key-pair RS256 --extractable

# 2. Create .dev.vars file with the keys
cat > .dev.vars << 'EOF'
JWT_PRIVATE_KEY_PEM="-----BEGIN PRIVATE KEY-----\nMIIEvg..."
JWT_PUBLIC_KEY_PEM="-----BEGIN PUBLIC KEY-----\nMIIBIj..."
REVENUECAT_WEBHOOK_SECRET="test-secret"
EOF

# 3. Start local dev server
npx wrangler dev

# Server starts at http://localhost:8787
```

### Manual API Testing

```bash
# Health check
curl http://localhost:8787/health

# Authenticate
curl -X POST http://localhost:8787/auth \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test_user_123"}'

# Returns: {"token": "eyJ...", "payload": {...}}

# Renew token
curl -X POST http://localhost:8787/renew \
  -H "Authorization: Bearer eyJ..."

# Record usage (free tier)
curl -X POST http://localhost:8787/usage \
  -H "Authorization: Bearer eyJ..."

# Get public key
curl http://localhost:8787/public-key

# Simulate RevenueCat webhook
curl -X POST http://localhost:8787/webhook/revenuecat \
  -H "Authorization: Bearer test-secret" \
  -H "Content-Type: application/json" \
  -d '{"api_version":"1.0","event":{"type":"INITIAL_PURCHASE","app_user_id":"test_user_123","expiration_at_ms":1735689600000}}'
```

### WebSocket Relay Testing

```bash
# Use websocat or wscat to test relay
npm install -g wscat

# Terminal 1 — Bridge side
wscat -c "ws://localhost:8787/relay/test-room?role=bridge"

# Terminal 2 — App side
wscat -c "ws://localhost:8787/relay/test-room?role=app"

# Type in one terminal, should appear in the other
# Messages are forwarded between bridge <-> app
```

---

## 3. Bridge Local Testing

### Prerequisites
- Node.js >= 18

### Steps

```bash
cd bridge
npm install
npm run build

# Run with a local server
node dist/index.js  # or via CLI:
node bin/cli.js start --server http://localhost:8787
```

The bridge will:
1. Generate E2E encryption keys (saved to `~/.codepilot/config.json`)
2. Generate a room ID
3. Display a QR code and pairing code in the terminal
4. Connect to the relay WebSocket
5. Wait for the iOS app to connect

### Testing Without iOS App

Use `wscat` to simulate the app side:

```bash
# Connect as "app" role to the same room
wscat -c "ws://localhost:8787/relay/ROOM_ID?role=app"

# Send a session:list request (no encryption for testing)
{"type": "session:list"}

# Send auth (dev mode accepts any token)
{"type": "auth", "token": "any"}

# Create a session
{"type": "session:create", "name": "Test", "cwd": "/tmp", "model": "default"}
```

### Testing Agent SDK Integration

To test with the actual Claude Agent SDK:

```bash
# Install Claude Code SDK
npm install @anthropic-ai/claude-code

# Set your Anthropic API key
export ANTHROPIC_API_KEY=sk-ant-...

# Run the bridge
node bin/cli.js start --server http://localhost:8787

# Then from the app side, send a prompt:
{"type": "prompt", "sessionId": "SESSION_ID", "text": "List files in current directory"}
```

---

## 4. iOS App Testing

### Prerequisites
- macOS with Xcode 15+
- iOS 17+ device or simulator
- Apple Developer account (for TestFlight)

### Setting Up the Xcode Project

1. Open the `ios/` directory in Xcode
2. Create a new iOS App project, import all files from `CodePilot/`
3. Add RevenueCat SPM package: `https://github.com/RevenueCat/purchases-ios-spm.git`
4. Set bundle identifier (e.g., `com.yourname.codepilot`)
5. Set iOS deployment target to 17.0

### Running on Simulator

1. Select an iPhone 15 Pro simulator
2. Build and Run (Cmd+R)
3. The app starts in Onboarding mode
4. Since there's no bridge running, you can still navigate through:
   - Onboarding flow (UI only)
   - Session list (empty state)
   - Settings (subscription management)
   - Paywall (purchase flow with mock)

### End-to-End Testing

1. **Start Server**: `cd server && npx wrangler dev`
2. **Start Bridge**: `cd bridge && node bin/cli.js start --server http://localhost:8787`
3. **Run iOS App** on simulator or device
4. Complete onboarding (scan QR or enter code)
5. Create a session
6. Send a prompt
7. Verify message flow: App → Relay → Bridge → Agent SDK → Bridge → Relay → App

### Testing Subscription Flow

The `RevenueCatService` has mock implementations for development:

```swift
// To simulate Pro in development:
UserDefaults.standard.set(true, forKey: "debug_isPro")
// Restart app — it will show Pro features

// To reset:
UserDefaults.standard.set(false, forKey: "debug_isPro")
```

### Testing Push Notifications

Push notifications require a physical device and Apple Developer account:

1. Register for remote notifications in Xcode capabilities
2. The PushService will log device tokens
3. Bridge will send APNs when tasks complete or approvals are needed

---

## 5. Test Matrix

| Test Area | Method | Coverage |
|-----------|--------|----------|
| JWT sign/verify | Automated (vitest) | Server RS256 roundtrip |
| E2E encryption | Automated (vitest) | tweetnacl encrypt/decrypt |
| Tier enforcement | Automated (vitest) | Pro/Free/Expired permissions |
| Approval flow | Automated (vitest) | Request/resolve/timeout/cancel |
| Session persistence | Automated (vitest) | SQLite CRUD + ordering |
| JWT validation | Automated (vitest) | jose verify + edge cases |
| Server API | Manual (curl) | Auth/renew/usage/webhook |
| WebSocket relay | Manual (wscat) | Message forwarding + buffering |
| Bridge CLI | Manual | QR display, relay connection |
| iOS UI | Manual (Xcode) | All 6 pages + navigation |
| iOS ↔ Bridge | Manual (E2E) | Full message flow |
| Subscription | Manual (mock) | Free/Pro tier switching |

---

## 6. CI Integration

Add to GitHub Actions:

```yaml
name: Tests
on: [push, pull_request]
jobs:
  server-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: cd server && npm ci && npm test

  bridge-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22 }
      - run: cd bridge && npm ci && npm test
```
