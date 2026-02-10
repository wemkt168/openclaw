#!/bin/sh
# [中文说明] OpenClaw Zeabur 启动脚本
# OpenClaw Zeabur startup script
# Refactored for POSIX Shell Compatibility (sh/ash)

set -e

# [中文说明] 定义清理函数，确保收到停止信号时优雅退出
# Define cleanup function for graceful shutdown
cleanup() {
    echo "Received shutdown signal. Cleaning up... (收到停止信号，正在清理...)"
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

# [中文说明] 立即捕获系统信号
# Trap signals immediately
trap cleanup INT TERM

# 1. [中文说明] 强制生产模式 (这对性能至关重要)
# 1. Enforce Production Mode (Critical for performance)
export NODE_ENV=production

echo "=== OpenClaw Zeabur Startup (Production Mode) ==="
echo "State dir: $OPENCLAW_STATE_DIR"
echo "Config path: $OPENCLAW_CONFIG_PATH"

# 2. [中文说明] 初始化 Zeabur 持久化配置
# 2. Initialize Zeabur persistent configuration
echo "Initializing Zeabur Config..."

# [中文说明] ⚠️ 关键修复: 强制重置配置以确保 Git 更新生效
# [中文说明] 这解决了"旧的/损坏的配置文件残留在硬盘里导致无限崩溃"的问题
# CRITICAL FIX: Force reset config to ensure Git updates apply
# This resolves the issue where old/invalid configs in the persistent volume cause crash loops.
if [ -f "$OPENCLAW_CONFIG_PATH" ]; then
    echo "Forcing configuration reset: Removing stale $OPENCLAW_CONFIG_PATH..."
    echo "[中文提示] 正在强制重置配置: 删除旧的 $OPENCLAW_CONFIG_PATH..."
    rm "$OPENCLAW_CONFIG_PATH"
fi

node scripts/ensure-zeabur-config.js

# 2.1 [中文说明] 禁用 Telegram 集成 (用户要求)
# [中文说明] 我们移除了此环境变量，防止 OpenClaw 尝试自动连接并因 Token 错误而崩溃。
# 2.1 Disable Telegram Integration (User Request)
# The user wants to configure Telegram manually later. 
# We unset this env var so OpenClaw doesn't try to auto-connect and crash on 401.
echo "Disabling Telegram integration (unset TELEGRAM_BOT_TOKEN)..."
unset TELEGRAM_BOT_TOKEN

# 3. [中文说明] 在后台启动 Gateway (日志输出到控制台)
# 3. Start Gateway in background (Logs to stdout)
echo "Starting OpenClaw Gateway..."
node dist/index.js gateway --allow-unconfigured --bind lan --port 8080 &
GATEWAY_PID=$!
echo "Gateway PID: $GATEWAY_PID"

# 4. [中文说明] 健壮的健康检查 (等待 /health 接口响应)
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
    echo "Gateway is HEALTHY and READY! (Gateway 已就绪!)"
    break
  fi

  sleep 2
  elapsed=$((elapsed + 2))
  echo "Waiting for Gateway... ($elapsed/${timeout}s)"
done

if [ $elapsed -ge $timeout ]; then
  echo "ERROR: Gateway failed to become healthy within $timeout seconds."
  echo "[中文错误] Gateway 启动超时 ($timeout 秒内未响应)"
  # Show process list for debugging
  ps aux
  # Kill gateway before exiting
  kill $GATEWAY_PID 2>/dev/null || true
  exit 1
fi

# 5. [中文说明] 前台启动 Node Host
# 5. Start Node Host in foreground
echo "Starting OpenClaw Node Host (ID: OpenClaw-Master)..."
node dist/index.js node run --host 127.0.0.1 --port 8080 --node-id OpenClaw-Master &
NODE_PID=$!
echo "Node Host PID: $NODE_PID"

# 6. [中文说明] 等待进程结束
# 6. Wait for processes
# POSIX sh 'wait' might not support -n, so we wait for specific PIDs
wait $GATEWAY_PID $NODE_PID
EXIT_CODE=$?
echo "Main process exited with code $EXIT_CODE"
exit $EXIT_CODE
