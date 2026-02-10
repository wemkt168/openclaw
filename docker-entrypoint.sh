#!/bin/sh
# OpenClaw Zeabur startup script
# Refactored based on Perplexity & Ecosystem Best Practices (2025-2026)

set -e

# 1. Enforce Production Mode (Critical for performance)
export NODE_ENV=production

echo "=== OpenClaw Zeabur Startup (Production Mode) ==="
echo "State dir: $OPENCLAW_STATE_DIR"
echo "Config path: $OPENCLAW_CONFIG_PATH"

# 2. Trap signals for graceful shutdown of both processes
trap 'kill $(jobs -p)' SIGINT SIGTERM

# 3. Initialize Zeabur persistent configuration
echo "Initializing Zeabur Config..."
node scripts/ensure-zeabur-config.js

# 4. Start Gateway in background (Logs to stdout)
# Note: output is NOT redirected, allowing Zeabur to capture logs
echo "Starting OpenClaw Gateway..."
node dist/index.js gateway --allow-unconfigured --bind lan --port 8080 &
GATEWAY_PID=$!

# 5. Robust Health Check (Wait for /health endpoint)
# We use a Node.js script to check the /health HTTP endpoint, which is more reliable than a simple port check.
# This ensures the Gateway application logic is actually ready.
echo "Waiting for Gateway to be healthy at http://127.0.0.1:8080/health..."
timeout=120
while ! node -e "
  const http = require('http');
  const req = http.get('http://127.0.0.1:8080/health', (res) => {
    if (res.statusCode === 200) { process.exit(0); }
    else { process.exit(1); }
  });
  req.on('error', () => process.exit(1));
  req.end();
"; do
  sleep 2
  timeout=$((timeout - 2))
  if [ "$timeout" -le 0 ]; then
    echo "ERROR: Gateway failed to become healthy within 120 seconds."
    # List processes to see what's happening
    ps aux
    exit 1
  fi
  echo "Waiting for Gateway... ($timeout seconds remaining)"
done
echo "Gateway is HEALTHY and READY!"

# 6. Start Node Host in foreground
# The Node Host connects to the local Gateway we just verified is ready.
echo "Starting OpenClaw Node Host (ID: OpenClaw-Master)..."
node dist/index.js node run --host 127.0.0.1 --port 8080 --node-id OpenClaw-Master &
NODE_PID=$!

# 7. Wait for any process to exit
wait -n $GATEWAY_PID $NODE_PID
EXIT_CODE=$?
echo "One of the processes exited with check code $EXIT_CODE"
exit $EXIT_CODE
