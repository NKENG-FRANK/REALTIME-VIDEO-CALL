# ─── Stage 1: Builder ───────────────────────────────────────────────────────
# Mediasoup requires build tools (g++, python3, make) to compile native binaries
FROM node:22-bookworm AS builder

WORKDIR /app

# Install build tools for Mediasoup native compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    make \
    g++ \
  && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json tsconfig.json ./

COPY packages/config/package.json         ./packages/config/
COPY packages/database/package.json       ./packages/database/
COPY packages/redis/package.json          ./packages/redis/
COPY packages/rabbitmq/package.json       ./packages/rabbitmq/
COPY packages/shared/package.json         ./packages/shared/

COPY services/user-management/package.json      ./services/user-management/
COPY services/audio-calls/package.json          ./services/audio-calls/
COPY services/video-calls/package.json          ./services/video-calls/
COPY services/background-processes/package.json ./services/background-processes/

# Allow mediasoup install scripts
RUN npm ci --ignore-scripts=false

COPY packages/ ./packages/
COPY services/video-calls/ ./services/video-calls/

RUN npm run build -w @callwave/config
RUN npm run build -w @callwave/shared
RUN npm run build -w @callwave/redis
RUN npm run build -w @callwave/rabbitmq
RUN npm run build -w video-calls

# ─── Stage 2: Production Runtime ────────────────────────────────────────────
# Keep Debian slim (not Alpine) so mediasoup worker binary still runs
FROM node:22-slim AS runner

WORKDIR /app

ENV NODE_ENV=production

# Mediasoup worker needs libstdc++
RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/node_modules                     ./node_modules
COPY --from=builder /app/packages/config/dist             ./packages/config/dist
COPY --from=builder /app/packages/config/package.json     ./packages/config/
COPY --from=builder /app/packages/shared/dist             ./packages/shared/dist
COPY --from=builder /app/packages/shared/package.json     ./packages/shared/
COPY --from=builder /app/packages/redis/dist              ./packages/redis/dist
COPY --from=builder /app/packages/redis/package.json      ./packages/redis/
COPY --from=builder /app/packages/rabbitmq/dist           ./packages/rabbitmq/dist
COPY --from=builder /app/packages/rabbitmq/package.json   ./packages/rabbitmq/
COPY --from=builder /app/services/video-calls/dist        ./services/video-calls/dist
COPY --from=builder /app/services/video-calls/package.json ./services/video-calls/
COPY --from=builder /app/package.json ./

WORKDIR /app/services/video-calls

# RTC UDP port range for Mediasoup workers
EXPOSE 3002
EXPOSE 40000-49999/udp

CMD ["node", "dist/server.js"]
