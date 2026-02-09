#!/bin/sh
# OpenClaw Zeabur startup script
# Based on official documentation: https://docs.openclaw.ai

set -e

echo "=== OpenClaw Zeabur Startup ==="
echo "State dir: $OPENCLAW_STATE_DIR"
echo "Config path: $OPENCLAW_CONFIG_PATH"

# Verify config file exists
if [ -f "$OPENCLAW_CONFIG_PATH" ]; then
    echo "Config file found"
else
    echo "WARNING: Config file not found at $OPENCLAW_CONFIG_PATH"
fi

# Verify required environment variables
echo ""
echo "Environment check:"
echo "  OPENROUTER_API_KEY: ${OPENROUTER_API_KEY:+[SET]}"
echo "  OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN:+[SET]}"
echo "  TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN:+[SET]}"
echo ""

# Initialize Zeabur persistent configuration (CRITICAL)
echo "Initializing Zeabur Config..."
node scripts/ensure-zeabur-config.js

# Start Gateway in background
echo "Starting OpenClaw Gateway..."
node dist/index.js gateway --allow-unconfigured --bind lan --port 8080 &
GATEWAY_PID=$!

# Wait for Gateway to initialize (simple sleep, could be robustified with netcat/curl loop)
sleep 2

# Start Node Host in foreground, connecting to local Gateway
echo "Starting OpenClaw Node Host (ID: OpenClaw-Master)..."
exec node dist/index.js node run --host 127.0.0.1 --port 8080 --node-id OpenClaw-Master
