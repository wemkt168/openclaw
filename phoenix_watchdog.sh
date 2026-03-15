#!/bin/bash
# ============================================================
# Phoenix Watchdog —— GitHub ↔ Zeabur Volume 桥接看门狗
# 架构师 Hard Spec v2 + Anti SRE 防弹优化
# ============================================================

# 开启严格模式 (Anti's SRE Standard)
# 注意：不开 -e，看门狗需要自行控制错误处理，避免被误杀
set -uo pipefail

REPO_DIR="$PWD"
OC_DIR="/home/node/.openclaw"
WORK_DIR="$OC_DIR/workspace"
PORT="${PORT:-3000}"
PID_FILE="$WORK_DIR/openclaw.pid"

# -----------------------------------------------------------
# 优雅关闭 (Graceful Shutdown Trap)
# -----------------------------------------------------------
cleanup() {
    echo "[Watchdog] 收到系统终止信号，执行优雅清理..."
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    exit 0
}

# -----------------------------------------------------------
# 启动 OpenClaw Gateway (Headless)
# -----------------------------------------------------------
start_node() {
    # 释放端口，忽略错误
    fuser -k "$PORT/tcp" 2>/dev/null || true

    # 强制 Headless 启动
    npx openclaw gateway start --port "$PORT" --bind auto --allow-unconfigured &

    # 将 PID 写入实体文件，解决跨进程失忆问题
    echo $! > "$PID_FILE"
    echo "[Watchdog] Node 已启动，PID: $(cat "$PID_FILE")"
}

# -----------------------------------------------------------
# 终结旧 Node 进程
# -----------------------------------------------------------
kill_node() {
    if [ -f "$PID_FILE" ]; then
        echo "[Watchdog] 正在终结旧的 Node 进程..."
        kill "$(cat "$PID_FILE")" 2>/dev/null || true
        rm -f "$PID_FILE"
        sleep 2
    fi
}

# ============================================================
# 主入口
# ============================================================
if [ "${1:-}" == "start" ]; then
    # 挂载信号拦截器
    trap cleanup SIGINT SIGTERM

    # 首次开机：空盘桥接，把 GitHub 里的初始技能拷入 Volume
    if [ ! -d "$WORK_DIR/skills" ] && [ -d "$REPO_DIR/init_skills" ]; then
        mkdir -p "$WORK_DIR/skills"
        cp -r "$REPO_DIR/init_skills/"* "$WORK_DIR/skills/" 2>/dev/null || true
        echo "[Watchdog] 初始技能已桥接至 Volume。"
    fi

    start_node

    # 维持 PID 1 存活，并允许 trap 响应
    while true; do sleep 3600 & wait $!; done
fi

if [ "${1:-}" == "update" ]; then
    echo "[Watchdog] Teddy 触发自我进化，开始备份技能..."
    cp -r "$WORK_DIR/skills" "$WORK_DIR/.backup_skills"

    kill_node
    start_node

    # 60秒心跳验证 (验证端口连通性)
    for i in $(seq 1 12); do
        sleep 5
        if curl -s "http://127.0.0.1:$PORT" > /dev/null; then
            echo "[Watchdog] 进化成功，心跳正常。"
            exit 0
        fi
    done

    echo "[Watchdog] 🚨 致命错误：心跳丢失，Teddy 脑死！执行 Rollback..."
    rm -rf "$WORK_DIR/skills"
    mv "$WORK_DIR/.backup_skills" "$WORK_DIR/skills"
    kill_node
    start_node
    echo "Rollback triggered at $(date)" > "$WORK_DIR/rollback.log"
fi
