#!/bin/sh
# OpenClaw Zeabur startup script
# Refactored for POSIX Shell Compatibility (sh/ash)

set -e

# Define cleanup function for graceful shutdown
cleanup() {
    echo "Received shutdown signal. Cleaning up..."
    if [ -n "$NODE_PID" ]; then
        echo "Stopping Node Host (PID $NODE_PID)..."
        kill -TERM "$NODE_PID" 2>/dev/null || true
    fi
    if [ -n "$GATEWAY_PID" ]; then
        echo "Stopping Gateway (PID $GATEWAY_PID)..."
        kill -TERM "$GATEWAY_PID" 2>/dev/null || true
    fi
    exit 0
}

# Trap signals immediately
trap cleanup INT TERM

# 1. Enforce Production Mode (Critical for performance)
export NODE_ENV=production

echo "=== OpenClaw Zeabur Startup (Production Mode) ==="
echo "State dir: $OPENCLAW_STATE_DIR"
echo "Config path: $OPENCLAW_CONFIG_PATH"

# 2. Initialize Zeabur persistent configuration
echo "Initializing Zeabur Config..."
node scripts/ensure-zeabur-config.js

# 2.1 Disable Telegram Integration (User Request)
# The user wants to configure Telegram manually later. 
# We unset this env var so OpenClaw doesn't try to auto-connect and crash on 401.
echo "Disabling Telegram integration (unset TELEGRAM_BOT_TOKEN)..."
unset TELEGRAM_BOT_TOKEN

# 3. Start Gateway in background (Logs to stdout)
echo "Starting OpenClaw Gateway..."
node dist/index.js gateway --allow-unconfigured --bind lan --port 8080 &
GATEWAY_PID=$!
echo "Gateway PID: $GATEWAY_PID"

# 4. Robust Health Check (Wait for /health endpoint)
echo "Waiting for Gateway to be healthy at http://127.0.0.1:8080/health..."
timeout=120
# Use a simple counter loop instead of calculating time to avoid 'date' command differences
elapsed=0
while [ $elapsed -lt $timeout ]; do
  # Check health using inline Node.js script
  if node -e "
    const http = require('http');
    const req = http.get('http://127.0.0.1:8080/health', (res) => {
      process.exit(res.statusCode === 200 ? 0 : 1);
    });
    req.on('error', () => process.exit(1));
    req.end();
  "; then
    echo "Gateway is HEALTHY and READY!"
    break
  fi

  sleep 2
  elapsed=$((elapsed + 2))
  echo "Waiting for Gateway... ($elapsed/${timeout}s)"
done

if [ $elapsed -ge $timeout ]; then
  echo "ERROR: Gateway failed to become healthy within $timeout seconds."
  # Show process list for debugging
  ps aux
  # Kill gateway before exiting
  kill $GATEWAY_PID 2>/dev/null || true
  exit 1
fi

# 5. Start Node Host in foreground
echo "Starting OpenClaw Node Host (ID: OpenClaw-Master)..."
node dist/index.js node run --host 127.0.0.1 --port 8080 --node-id OpenClaw-Master &
NODE_PID=$!
echo "Node Host PID: $NODE_PID"

# 6. Wait for processes
# POSIX sh 'wait' might not support -n, so we wait for specific PIDs
wait $GATEWAY_PID $NODE_PID
EXIT_CODE=$?
echo "Main process exited with code $EXIT_CODE"
exit $EXIT_CODE
