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

ENV NODE_ENV=production
ENV PORT=18789

# Copy Zeabur-specific config file with correct OpenRouter model IDs
# Based on official docs: https://docs.openclaw.ai/providers/openrouter
RUN mkdir -p /root/.openclaw
COPY openclaw.zeabur.json /root/.openclaw/openclaw.json

# Set state directory for OpenClaw
ENV OPENCLAW_STATE_DIR=/root/.openclaw

EXPOSE 18789

# Start gateway with error capture
# If startup fails, wait 30 seconds so error logs can be viewed
CMD ["sh", "-c", "echo 'Starting OpenClaw Gateway...' && node dist/index.js gateway --allow-unconfigured --bind lan --port 18789 2>&1 || (echo 'ERROR: Application startup failed!' && sleep 30)"]
