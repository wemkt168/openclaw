FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
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
# Runtime configuration (based on official docker-compose.yml)
# ============================================

ENV NODE_ENV=production
ENV PORT=18789

# CRITICAL: Set HOME to /home/node per official docker-compose.yml
# This is required for OpenClaw to find config at ~/.openclaw/
ENV HOME=/home/node

# Create config directory and copy Zeabur-specific config
# Path: /home/node/.openclaw/openclaw.json (matches official $HOME/.openclaw)
RUN mkdir -p /home/node/.openclaw
COPY openclaw.zeabur.json /home/node/.openclaw/openclaw.json
RUN chown -R node:node /home/node

# Security: Run as non-root user (per official Dockerfile pattern)
USER node

EXPOSE 18789

# Start gateway with detailed error capture for debugging
CMD ["sh", "-c", "\
  echo '=== OpenClaw Startup Debug ===' && \
  echo 'Current user:' $(whoami) && \
  echo 'HOME:' $HOME && \
  echo 'PWD:' $(pwd) && \
  echo '--- Checking files ---' && \
  ls -la /app/dist/index.js 2>&1 || echo 'ERROR: dist/index.js not found!' && \
  ls -la /home/node/.openclaw/ 2>&1 || echo 'ERROR: config dir not found!' && \
  echo '--- Starting gateway ---' && \
  set -x && \
  node dist/index.js gateway --allow-unconfigured --bind lan --port 18789 2>&1 || \
  (echo 'ERROR: Application startup failed! Exit code:' $?; sleep 60) \
  "]
