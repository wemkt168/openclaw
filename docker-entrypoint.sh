#!/bin/sh
# OpenClaw Zeabur startup script
# This script verifies config and starts the gateway

set -e

echo "=== OpenClaw Startup Script ==="
echo "Checking config file..."

# Check if config file exists
CONFIG_FILE="${OPENCLAW_CONFIG_PATH:-/root/.openclaw/openclaw.json}"
echo "Config path: $CONFIG_FILE"

if [ -f "$CONFIG_FILE" ]; then
    echo "Config file exists!"
    echo "First 20 lines of config:"
    head -20 "$CONFIG_FILE"
else
    echo "WARNING: Config file not found at $CONFIG_FILE"
    ls -la /root/.openclaw/ 2>/dev/null || echo "Directory /root/.openclaw/ does not exist"
fi

echo ""
echo "Environment variables:"
echo "  OPENROUTER_API_KEY: ${OPENROUTER_API_KEY:+[SET]}"
echo "  OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN:+[SET]}"
echo "  TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN:+[SET]}"
echo ""

# Set the model using openclaw CLI before starting gateway
echo "Setting default model to openrouter/anthropic/claude-sonnet-4..."
node dist/index.js models set openrouter/anthropic/claude-sonnet-4 || echo "Model set failed (may be first run)"

echo ""
echo "Starting OpenClaw Gateway..."
exec node dist/index.js gateway --allow-unconfigured --bind lan --port 18789
