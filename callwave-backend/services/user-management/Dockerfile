# ─── Stage 1: Builder ───────────────────────────────────────────────────────
FROM node:22-alpine AS builder

WORKDIR /app

# Copy workspace root manifests
COPY package.json package-lock.json tsconfig.json ./

# Copy all package manifests (needed for workspace resolution)
COPY packages/config/package.json         ./packages/config/
COPY packages/database/package.json       ./packages/database/
COPY packages/redis/package.json          ./packages/redis/
COPY packages/rabbitmq/package.json       ./packages/rabbitmq/
COPY packages/shared/package.json         ./packages/shared/

# Copy service manifests
COPY services/user-management/package.json  ./services/user-management/
COPY services/audio-calls/package.json      ./services/audio-calls/
COPY services/video-calls/package.json      ./services/video-calls/
COPY services/background-processes/package.json ./services/background-processes/

# Install ALL workspace dependencies from root
# --ignore-scripts prevents mediasoup from compiling its native binary here
# (user-management doesn't use mediasoup at runtime)
RUN npm ci --ignore-scripts

# Copy source files
COPY packages/ ./packages/
COPY services/user-management/ ./services/user-management/

# Build shared packages first, then service
RUN npm run build -w @callwave/config
RUN npm run build -w @callwave/shared
RUN npm run build -w @callwave/database
RUN npm run build -w user-management

# ─── Stage 2: Production Runtime ────────────────────────────────────────────
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# Install postgresql-client for DB initialization check
RUN apk add --no-cache postgresql-client

# Copy built artefacts from builder
COPY --from=builder /app/node_modules               ./node_modules
COPY --from=builder /app/packages/config/dist       ./packages/config/dist
COPY --from=builder /app/packages/config/package.json ./packages/config/
COPY --from=builder /app/packages/shared/dist       ./packages/shared/dist
COPY --from=builder /app/packages/shared/package.json ./packages/shared/
COPY --from=builder /app/packages/database/dist     ./packages/database/dist
COPY --from=builder /app/packages/database/package.json ./packages/database/
COPY --from=builder /app/services/user-management/dist    ./services/user-management/dist
COPY --from=builder /app/services/user-management/package.json ./services/user-management/
COPY --from=builder /app/package.json ./

# Copy schema and entrypoint script
COPY --from=builder /app/services/user-management/src/schema.sql /app/services/user-management/schema.sql
COPY --from=builder /app/services/user-management/docker-entrypoint.sh /app/services/user-management/docker-entrypoint.sh
RUN chmod +x /app/services/user-management/docker-entrypoint.sh

WORKDIR /app/services/user-management

EXPOSE 3000

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["node", "dist/server.js"]
