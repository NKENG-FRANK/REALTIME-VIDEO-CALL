# ─── Stage 1: Builder ───────────────────────────────────────────────────────
FROM node:22-alpine AS builder

WORKDIR /app

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

RUN npm ci --ignore-scripts

COPY packages/ ./packages/
COPY services/background-processes/ ./services/background-processes/

RUN npm run build -w @callwave/config
RUN npm run build -w @callwave/shared
RUN npm run build -w @callwave/redis
RUN npm run build -w @callwave/rabbitmq
RUN npm run build -w background-processes

# ─── Stage 2: Production Runtime ────────────────────────────────────────────
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

COPY --from=builder /app/node_modules                           ./node_modules
COPY --from=builder /app/packages/config/dist                   ./packages/config/dist
COPY --from=builder /app/packages/config/package.json           ./packages/config/
COPY --from=builder /app/packages/shared/dist                   ./packages/shared/dist
COPY --from=builder /app/packages/shared/package.json           ./packages/shared/
COPY --from=builder /app/packages/redis/dist                    ./packages/redis/dist
COPY --from=builder /app/packages/redis/package.json            ./packages/redis/
COPY --from=builder /app/packages/rabbitmq/dist                 ./packages/rabbitmq/dist
COPY --from=builder /app/packages/rabbitmq/package.json         ./packages/rabbitmq/
COPY --from=builder /app/services/background-processes/dist        ./services/background-processes/dist
COPY --from=builder /app/services/background-processes/package.json ./services/background-processes/
COPY --from=builder /app/package.json ./

WORKDIR /app/services/background-processes

CMD ["node", "dist/server.js"]
