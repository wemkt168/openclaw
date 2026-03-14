# Golden State Configuration (2026-02-10)

此文档包含了 OpenClaw 成功部署（2026-02-10）所需的所有核心配置文件。
这些文件经过了汉化注释，并包含了关键的 **"Force Config Reset"** 修复。

---

## 1. Dockerfile

```dockerfile
FROM node:22-bookworm

# [中文说明] 安装 Bun (构建脚本需要此工具)
# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

# [中文说明] 定义需要安装的系统工具 (Python3, Git)
ARG OPENCLAW_DOCKER_APT_PACKAGES="python3 python3-pip git"
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
  fi

# [中文说明] 复制项目依赖文件
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

# [中文说明] 安装 Node.js 依赖
RUN pnpm install --frozen-lockfile

# [中文说明] 复制所有源代码
COPY . .

# [中文说明] 构建项目 (跳过缺失的 UI 组件校验)
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
# [中文说明] 强制使用 pnpm 构建前端 UI (避免 Bun 在某些架构下的兼容性问题)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# ============================================
# [中文说明] 浏览器工具支持 (Browser Tool Support)
# ============================================
# 1. [中文说明] 仅安装系统依赖 (需要 root 权限)
#    这保持了镜像体积较小。浏览器二进制文件将手动下载。
# 1. Install system dependencies ONLY (Lightweight, requires root)
#    This keeps the image small. The browser binary will be downloaded manually.
#    Use global install to ensure CLI binary is found in PATH
RUN npm install -g playwright@1.58.1 && \
  playwright install-deps chromium && \
  npm uninstall -g playwright

# 2. [中文说明] 将浏览器文件持久化到 State 目录
#    这确保手动安装的浏览器在重启后不会丢失。
# 2. Persist browser binaries to the state volume
#    This ensures manual installation survives restarts.
ENV PLAYWRIGHT_BROWSERS_PATH=/home/node/.openclaw/playwright

# ============================================
# [中文说明] 运行时配置 (Runtime configuration)
# 基于官方 docker-compose.yml + Fly.io 部署指南
# ============================================

ENV NODE_ENV=production
# [中文说明] 使用 8080 端口 - Zeabur 默认期望的端口
# Use port 8080 - Zeabur's default expected port
ENV PORT=8080

# [中文说明] 关键设置: 将 HOME 设为 /home/node (遵循官方标准)
# CRITICAL: Set HOME to /home/node per official docker-compose.yml
ENV HOME=/home/node
ENV TERM=xterm-256color

# [中文说明] 显式定义配置路径，避免启动时的路径查找错误 (解决 Zeabur 崩溃问题)
# Explicitly define config paths to ensure consistent resolution (fixes Zeabur startup crash)
ENV OPENCLAW_STATE_DIR=/home/node/.openclaw
ENV OPENCLAW_CONFIG_PATH=/home/node/.openclaw/openclaw.json

# [中文说明] 限制内存使用，防止在小型实例上 OOM (内存溢出)
# Reduce memory usage for smaller instances
ENV NODE_OPTIONS="--max-old-space-size=1536"

# [中文说明] 将我们准备好的安全配置文件复制为"默认配置"
# Copy config to a safe location for volume initialization
COPY openclaw.zeabur.json /app/openclaw.defaults.json

# [中文说明] 暴露 8080 端口供 Zeabur 反向代理使用
# Expose port 8080 for Zeabur reverse proxy
EXPOSE 8080

# [中文说明] 启动命令: 使用自定义入口脚本
# Startup command via custom entrypoint (runs Gateway + Node Host)
# 1. [中文说明] 复制脚本 (作为 root 用户，确保权限没问题)
# 1. Copy script (as root, so permissions work)
COPY --chmod=755 docker-entrypoint.sh ./docker-entrypoint.sh

# [中文说明] 安全设置: 此后切换为非 root 用户 (node) 运行
# Security: Run as non-root user (switch AFTER setup is done)
USER node

# 2. [中文说明] 显式使用 sh 执行脚本
# 2. Explicitly run with sh
CMD ["sh", "./docker-entrypoint.sh"]
```

---

## 2. docker-entrypoint.sh (核心启动脚本)

```bash
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
```

---

## 3. openclaw.zeabur.json (配置文件)

```json
{
    "env": {
        "OPENROUTER_API_KEY": "${OPENROUTER_API_KEY}",
        "TELEGRAM_BOT_TOKEN": "${TELEGRAM_BOT_TOKEN}"
    },
    "agents": {
        "defaults": {
            "models": {
                "openrouter/anthropic/claude-sonnet-4": {
                    "alias": "sonnet"
                },
                "openrouter/google/gemini-2.0-flash-001": {
                    "alias": "flash"
                },
                "openrouter/anthropic/claude-3-opus": {
                    "alias": "opus"
                },
                "openrouter/openai/gpt-4o": {
                    "alias": "gpt4o"
                }
            },
            "model": {
                "primary": "openrouter/google/gemini-2.0-flash-001",
                "fallbacks": [
                    "openrouter/anthropic/claude-sonnet-4",
                    "openrouter/openai/gpt-4o"
                ]
            },
            "workspace": "/root/.openclaw/workspace",
            "sandbox": {
                "mode": "off"
            },
            "thinkingDefault": "low",
            "elevatedDefault": "on",
            "timeoutSeconds": 1800,
            "subagents": {
                "model": "openrouter/google/gemini-2.0-flash-001",
                "maxConcurrent": 2
            }
        },
        "list": [
            {
                "id": "master",
                "default": true,
                "identity": {
                    "name": "OpenClaw",
                    "theme": "进化体",
                    "emoji": "🧬"
                }
            }
        ]
    },
    "gateway": {
        "bind": "lan",
        "port": 8080,
        "trustedProxies": [
            "10.0.0.0/8",
            "172.16.0.0/12",
            "192.168.0.0/16"
        ],
        "controlUi": {
            "allowInsecureAuth": true
        },
        "auth": {
            "mode": "token",
            "token": "${OPENCLAW_GATEWAY_TOKEN}"
        }
    },
    "channels": {
        "telegram": {
            "enabled": false
        }
    },
    "tools": {
        "profile": "full",
        "elevated": {
            "enabled": true,
            "allowFrom": {
                "telegram": [
                    "*"
                ],
                "web": [
                    "*"
                ]
            }
        },
        "web": {
            "search": {
                "enabled": true,
                "apiKey": "${BRAVE_API_KEY}"
            },
            "fetch": {
                "enabled": true
            }
        }
    },
    "commands": {
        "native": "auto",
        "text": true,
        "bash": true,
        "config": true
    },
    "logging": {
        "level": "info"
    }
}
```
