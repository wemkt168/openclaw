FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES="python3 python3-pip git"
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
  fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .

RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

# ============================================
# Browser Tool Support (Playwright)
# ============================================
# 1. Install system dependencies ONLY (Lightweight, requires root)
#    This keeps the image small. The browser binary will be downloaded manually.
#    Using npx -y playwright@1.58.1 to match package.json core version
RUN npx -y playwright@1.58.1 install-deps chromium

# 2. Persist browser binaries to the state volume
#    This ensures manual installation survives restarts.
ENV PLAYWRIGHT_BROWSERS_PATH=/home/node/.openclaw/playwright

# ============================================
# Runtime configuration
# Based on official docker-compose.yml + Fly.io deployment guide
# ============================================

ENV NODE_ENV=production
# Use port 8080 - Zeabur's default expected port
ENV PORT=8080

# CRITICAL: Set HOME to /home/node per official docker-compose.yml
ENV HOME=/home/node
ENV TERM=xterm-256color

# Explicitly define config paths to ensure consistent resolution (fixes Zeabur startup crash)
ENV OPENCLAW_STATE_DIR=/home/node/.openclaw
ENV OPENCLAW_CONFIG_PATH=/home/node/.openclaw/openclaw.json

# Reduce memory usage for smaller instances
ENV NODE_OPTIONS="--max-old-space-size=1536"

# Copy config to a safe location for volume initialization
COPY openclaw.zeabur.json /app/openclaw.defaults.json

# Expose port 8080 for Zeabur reverse proxy
EXPOSE 8080

# Startup command via custom entrypoint (runs Gateway + Node Host)
# 1. Copy script (as root, so permissions work)
COPY --chmod=755 docker-entrypoint.sh ./docker-entrypoint.sh

# Security: Run as non-root user (switch AFTER setup is done)
USER node

# 2. Explicitly run with sh
CMD ["sh", "./docker-entrypoint.sh"]
