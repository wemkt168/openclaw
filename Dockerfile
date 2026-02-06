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
ENV HOME=/home/node
ENV TERM=xterm-256color

# Create config directory and copy Zeabur-specific config
RUN mkdir -p /home/node/.openclaw && \
  chown -R node:node /home/node
COPY --chown=node:node openclaw.zeabur.json /home/node/.openclaw/openclaw.json

# Verify config file exists during build
RUN ls -la /home/node/.openclaw/ && cat /home/node/.openclaw/openclaw.json | head -5

# Security: Run as non-root user (per official Dockerfile pattern)
USER node

EXPOSE 18789

# Simple startup command matching official docker-compose.yml format
# Note: --allow-unconfigured allows starting without full onboarding
CMD ["node", "dist/index.js", "gateway", "--allow-unconfigured", "--bind", "lan", "--port", "18789"]
