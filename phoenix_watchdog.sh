#!/bin/bash
# ============================================================
# Phoenix Watchdog —— GitHub ↔ Zeabur Volume 桥接看门狗
# 解决 GitHub 代码与 Zeabur 持久化 Volume 数据割裂问题
# ============================================================

set -euo pipefail

REPO_DIR="$PWD"  # GitHub 代码在 Zeabur 中的路径 (通常是 /app)
OC_DIR="/home/node/.openclaw"
WORK_DIR="$OC_DIR/workspace"
PORT="${PORT:-3000}"
HEARTBEAT_URL="http://127.0.0.1:$PORT/health"
NODE_PID=""

# -----------------------------------------------------------
# 1. 初始化桥接：首次开机时将 GitHub 里的初始技能拷入 Volume
# -----------------------------------------------------------
bootstrap_skills() {
  if [ ! -d "$WORK_DIR/skills/web_search" ]; then
    mkdir -p "$WORK_DIR/skills"
    cp -r "$REPO_DIR/init_skills/"* "$WORK_DIR/skills/" 2>/dev/null || true
    echo "✅ Initial skills bootstrapped to volume."
  else
    echo "ℹ️  Skills already present in volume, skipping bootstrap."
  fi
}

# -----------------------------------------------------------
# 2. 启动 OpenClaw Gateway (headless 模式)
# -----------------------------------------------------------
start_node() {
  fuser -k "$PORT/tcp" 2>/dev/null || true
  # 必须使用 headless 参数启动，否则在 Zeabur 无 TTY 环境必崩
  npx openclaw gateway start --port "$PORT" --bind auto --allow-unconfigured &
  NODE_PID=$!
  echo "🚀 OpenClaw Gateway started (PID: $NODE_PID) on port $PORT"
}

# -----------------------------------------------------------
# 3. 健康检查：最多等 60 秒
# -----------------------------------------------------------
wait_healthy() {
  for i in $(seq 1 12); do
    sleep 5
    if curl -s "$HEARTBEAT_URL" > /dev/null 2>&1; then
      echo "💚 Gateway is healthy!"
      return 0
    fi
    echo "⏳ Health check attempt $i/12..."
  done
  return 1
}

# -----------------------------------------------------------
# 信号处理：优雅关闭
# -----------------------------------------------------------
cleanup() {
  echo "🛑 Received shutdown signal, cleaning up..."
  if [ -n "$NODE_PID" ]; then
    kill -TERM "$NODE_PID" 2>/dev/null || true
  fi
  exit 0
}
trap cleanup INT TERM

# ============================================================
# 主入口
# ============================================================
case "${1:-}" in
  start)
    echo "=== 🐦‍🔥 Phoenix Watchdog: START MODE ==="
    bootstrap_skills
    start_node

    # 保持容器活跃（Zeabur 要求前台进程不退出）
    while true; do sleep 3600; done
    ;;

  update)
    echo "=== 🔄 Phoenix Watchdog: UPDATE MODE ==="
    echo "Teddy triggered evolution, backing up skills..."

    # 备份现有技能
    cp -r "$WORK_DIR/skills" "$WORK_DIR/.backup_skills"

    # 重启 Gateway
    if [ -n "$NODE_PID" ]; then
      kill "$NODE_PID" 2>/dev/null || true
    fi
    start_node

    # 健康检查
    if wait_healthy; then
      echo "✅ Update successful, removing backup."
      rm -rf "$WORK_DIR/.backup_skills"
      exit 0
    fi

    # 健康检查失败 → 回滚
    echo "🔴 Teddy Brain Death! Rolling back..."
    rm -rf "$WORK_DIR/skills"
    mv "$WORK_DIR/.backup_skills" "$WORK_DIR/skills"
    kill "$NODE_PID" 2>/dev/null || true
    start_node
    echo "Rollback triggered at $(date)" > "$WORK_DIR/rollback.log"
    echo "⚠️  Rollback complete. Check $WORK_DIR/rollback.log"
    ;;

  *)
    echo "Usage: phoenix_watchdog.sh {start|update}"
    exit 1
    ;;
esac
