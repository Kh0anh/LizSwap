# ============================================================
# LizSwap BSC Indexer – Dockerfile
# ============================================================
# Multi-stage build: TypeScript → JavaScript
# Daemon process – không expose port
# ============================================================

# --- Stage 1: Dependencies ---
FROM node:20-alpine AS deps
WORKDIR /app

COPY package.json package-lock.json* yarn.lock* pnpm-lock.yaml* ./
RUN \
    if [ -f package-lock.json ]; then npm ci --ignore-scripts; \
    elif [ -f yarn.lock ]; then yarn install --frozen-lockfile; \
    elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm install --frozen-lockfile; \
    else npm install; \
    fi

# --- Stage 2: Build ---
FROM node:20-alpine AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npm run build

# --- Stage 3: Production ---
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production

# Tạo user non-root
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 indexer

# Copy build output
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./package.json

# Install production dependencies only
COPY --from=deps /app/node_modules ./node_modules

USER indexer

# Indexer là daemon, không expose port
# Không có health check endpoint – Docker sẽ monitor process exit

CMD ["node", "dist/index.js"]
