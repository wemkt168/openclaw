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
