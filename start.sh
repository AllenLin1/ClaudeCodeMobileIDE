#!/bin/bash
set -e

echo "============================================"
echo "  CodePilot Local Development Setup"
echo "============================================"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js not found. Install from https://nodejs.org/"
    exit 1
fi
NODE_V=$(node -v)
echo "Node.js: $NODE_V"

# Check npm
if ! command -v npm &> /dev/null; then
    echo "ERROR: npm not found."
    exit 1
fi
echo "npm: $(npm -v)"
echo ""

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "Project root: $SCRIPT_DIR"
echo ""

# ---- Step 1: Server ----
echo "============================================"
echo "  Step 1: Setting up Server"
echo "============================================"
cd "$SCRIPT_DIR/server"

echo "Installing dependencies..."
npm install --silent

if [ ! -f .dev.vars ]; then
    echo "Generating RS256 keys..."
    npm run setup
else
    echo ".dev.vars already exists, skipping key generation."
fi

echo ""
echo "Starting server in background..."
npx wrangler dev &
SERVER_PID=$!
echo "Server PID: $SERVER_PID"

# Wait for server to be ready
echo "Waiting for server to start..."
for i in $(seq 1 20); do
    if curl -s http://localhost:8787/health > /dev/null 2>&1; then
        echo "Server is ready at http://localhost:8787"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "ERROR: Server failed to start after 20 seconds."
        kill $SERVER_PID 2>/dev/null
        exit 1
    fi
    sleep 1
done

echo ""

# ---- Step 2: Bridge ----
echo "============================================"
echo "  Step 2: Setting up Bridge"
echo "============================================"
cd "$SCRIPT_DIR/bridge"

echo "Installing dependencies..."
npm install --silent

echo "Compiling TypeScript..."
npm run build

echo ""
echo "Verifying build output..."
if grep -q "Registering pairing code" dist/index.js 2>/dev/null; then
    echo "Build verified: dist/index.js contains pairing registration code."
else
    echo "WARNING: dist/index.js does NOT contain pairing code. Build may have failed."
    echo "Try: cd bridge && rm -rf dist && npm run build"
fi

echo ""
echo "============================================"
echo "  Starting Bridge"
echo "============================================"
echo ""
echo "Look for these lines in the output:"
echo '  [bridge] Registering pairing code XXXXXX with server...'
echo '  [bridge] Pairing code registered OK'
echo ""
echo "Then enter the pairing code in the iOS app."
echo "Press Ctrl+C to stop."
echo ""

node bin/cli.js start --server http://localhost:8787

# Cleanup on exit
kill $SERVER_PID 2>/dev/null
